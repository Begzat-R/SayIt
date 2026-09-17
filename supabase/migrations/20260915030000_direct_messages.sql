-- ─────────────────────────────────────────
-- DIRECT MESSAGING (request-based)
--
-- Flow:
--   1. A sends B a message with no accepted thread between them yet ->
--      a `message_requests` row is created (status 'pending'), holding the
--      first message's text in `body`. No `messages` row exists yet.
--   2. B sees it in their Requests list and either:
--        accept -> public.accept_message_request() creates a `threads` row,
--                  moves `body` into a real `messages` row, marks the
--                  request 'accepted' and stamps `thread_id`.
--        decline -> public.decline_message_request() deletes the request.
--   3. Once a thread exists, subsequent sends from either side go straight
--      into `messages` (see public.send_direct_message()).
--
-- All three mutating flows are exposed as RPCs (below the tables) rather
-- than raw table writes, because "accept" requires inserting a message on
-- behalf of the *original sender* (not the caller) — something a plain
-- RLS insert policy keyed on auth.uid() = sender_id cannot express. The
-- RPCs are SECURITY DEFINER for exactly that step; every other access path
-- (select, the initial send) is still governed by the RLS policies below.
-- ─────────────────────────────────────────

create type public.message_request_status as enum ('pending', 'accepted', 'declined');

create table public.message_requests (
  id           uuid primary key default gen_random_uuid(),
  sender_id    uuid not null references public.profiles(id) on delete cascade,
  receiver_id  uuid not null references public.profiles(id) on delete cascade,
  body         text not null check (char_length(body) <= 2000),
  status       public.message_request_status not null default 'pending',
  thread_id    uuid,
  created_at   timestamptz not null default now(),
  responded_at timestamptz,
  constraint message_requests_no_self check (sender_id <> receiver_id)
);

-- Only one pending request per direction between two users at a time.
create unique index idx_message_requests_unique_pending
  on public.message_requests(sender_id, receiver_id)
  where status = 'pending';

create index idx_message_requests_receiver on public.message_requests(receiver_id, status);
create index idx_message_requests_sender on public.message_requests(sender_id, status);

create table public.threads (
  id         uuid primary key default gen_random_uuid(),
  user_a     uuid not null references public.profiles(id) on delete cascade,
  user_b     uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint threads_no_self check (user_a <> user_b),
  -- user_a/user_b are always stored as (least(x,y), greatest(x,y)) so a pair
  -- can never end up with two threads regardless of who initiated.
  constraint threads_ordered_pair check (user_a < user_b)
);

create unique index idx_threads_pair on public.threads(user_a, user_b);

create table public.messages (
  id         uuid primary key default gen_random_uuid(),
  thread_id  uuid not null references public.threads(id) on delete cascade,
  sender_id  uuid not null references public.profiles(id) on delete cascade,
  content    text not null check (char_length(content) <= 2000),
  created_at timestamptz not null default now(),
  read_at    timestamptz
);

create index idx_messages_thread_created on public.messages(thread_id, created_at);

-- Needed so postgres_changes payloads carry full row data (e.g. read_at
-- updates) rather than just the primary key on UPDATE.
alter table public.messages replica identity full;

-- ─────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────

alter table public.message_requests enable row level security;
alter table public.threads enable row level security;
alter table public.messages enable row level security;

-- message_requests: only sender or receiver can see a request, and it can
-- only be created by the sender towards a non-blocked receiver. Status
-- transitions (accept/decline) are performed exclusively via the RPCs
-- below — there is deliberately no client-facing UPDATE/DELETE policy, so
-- a request can't be tampered with or hidden by direct table access.
create policy "Participants can view their message requests"
  on public.message_requests for select
  to authenticated
  using (auth.uid() = sender_id or auth.uid() = receiver_id);

create policy "Sender can create a request if not blocked"
  on public.message_requests for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and not public.is_blocked(sender_id, receiver_id)
  );

-- threads: only the two participants can see a thread, and only while
-- neither has blocked the other. No client-facing INSERT/UPDATE/DELETE —
-- threads are only ever created by accept_message_request().
create policy "Participants can view their threads"
  on public.threads for select
  to authenticated
  using (
    (auth.uid() = user_a or auth.uid() = user_b)
    and not public.is_blocked(user_a, user_b)
  );

-- messages: visible only to the two participants of the parent thread, and
-- only while there is no block between them. Insertable only by the
-- authenticated sender, into a thread they belong to, with no block.
create policy "Participants can view messages in their threads"
  on public.messages for select
  to authenticated
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and (auth.uid() = t.user_a or auth.uid() = t.user_b)
        and not public.is_blocked(t.user_a, t.user_b)
    )
  );

create policy "Sender can send a message into their own thread"
  on public.messages for insert
  to authenticated
  with check (
    auth.uid() = sender_id
    and exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and (auth.uid() = t.user_a or auth.uid() = t.user_b)
        and not public.is_blocked(t.user_a, t.user_b)
    )
  );

-- A participant can mark messages as read. RLS scopes which *rows* are
-- reachable; the column-level grant below additionally restricts *which
-- column* — without it, this policy alone would let either participant
-- rewrite the other's message content, not just flip read_at.
create policy "Participants can mark messages read"
  on public.messages for update
  to authenticated
  using (
    exists (
      select 1 from public.threads t
      where t.id = messages.thread_id
        and (auth.uid() = t.user_a or auth.uid() = t.user_b)
    )
  );

revoke update on public.messages from authenticated;
grant update (read_at) on public.messages to authenticated;

-- ─────────────────────────────────────────
-- RPCs
-- ─────────────────────────────────────────

create or replace function public.send_direct_message(p_receiver_id uuid, p_content text)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_sender uuid := auth.uid();
  v_content text := trim(p_content);
  v_pair_a uuid;
  v_pair_b uuid;
  v_thread_id uuid;
  v_request_id uuid;
  v_message_id uuid;
begin
  if v_sender is null then
    raise exception 'Not authenticated';
  end if;
  if v_sender = p_receiver_id then
    raise exception 'Cannot message yourself';
  end if;
  if v_content = '' then
    raise exception 'Message cannot be empty';
  end if;
  if public.is_blocked(v_sender, p_receiver_id) then
    raise exception 'Cannot message this user';
  end if;
  if not exists (select 1 from public.profiles where id = p_receiver_id) then
    raise exception 'Recipient not found';
  end if;

  v_pair_a := least(v_sender, p_receiver_id);
  v_pair_b := greatest(v_sender, p_receiver_id);

  select id into v_thread_id
  from public.threads
  where user_a = v_pair_a and user_b = v_pair_b;

  if v_thread_id is not null then
    insert into public.messages (thread_id, sender_id, content)
    values (v_thread_id, v_sender, v_content)
    returning id into v_message_id;

    return jsonb_build_object(
      'kind', 'message',
      'thread_id', v_thread_id,
      'message_id', v_message_id
    );
  end if;

  if exists (
    select 1 from public.message_requests
    where sender_id = v_sender
      and receiver_id = p_receiver_id
      and status = 'pending'
  ) then
    raise exception 'You already have a pending request with this user';
  end if;

  insert into public.message_requests (sender_id, receiver_id, body)
  values (v_sender, p_receiver_id, v_content)
  returning id into v_request_id;

  return jsonb_build_object('kind', 'request', 'request_id', v_request_id);
end;
$$;

revoke all on function public.send_direct_message(uuid, text) from public;
grant execute on function public.send_direct_message(uuid, text) to authenticated;

create or replace function public.accept_message_request(p_request_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_req record;
  v_pair_a uuid;
  v_pair_b uuid;
  v_thread_id uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select * into v_req
  from public.message_requests
  where id = p_request_id
  for update;

  if v_req is null then
    raise exception 'Request not found';
  end if;
  if v_req.receiver_id <> v_uid then
    raise exception 'Not authorized to accept this request';
  end if;
  if v_req.status <> 'pending' then
    raise exception 'Request is no longer pending';
  end if;
  if public.is_blocked(v_req.sender_id, v_req.receiver_id) then
    raise exception 'Cannot accept — blocked relationship';
  end if;

  v_pair_a := least(v_req.sender_id, v_req.receiver_id);
  v_pair_b := greatest(v_req.sender_id, v_req.receiver_id);

  insert into public.threads (user_a, user_b)
  values (v_pair_a, v_pair_b)
  on conflict (user_a, user_b) do nothing;

  select id into v_thread_id
  from public.threads
  where user_a = v_pair_a and user_b = v_pair_b;

  insert into public.messages (thread_id, sender_id, content, created_at)
  values (v_thread_id, v_req.sender_id, v_req.body, v_req.created_at);

  update public.message_requests
  set status = 'accepted', thread_id = v_thread_id, responded_at = now()
  where id = p_request_id;

  return v_thread_id;
end;
$$;

revoke all on function public.accept_message_request(uuid) from public;
grant execute on function public.accept_message_request(uuid) to authenticated;

create or replace function public.decline_message_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_receiver uuid;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select receiver_id into v_receiver
  from public.message_requests
  where id = p_request_id and status = 'pending';

  if v_receiver is null then
    raise exception 'Request not found or already resolved';
  end if;
  if v_receiver <> v_uid then
    raise exception 'Not authorized to decline this request';
  end if;

  delete from public.message_requests where id = p_request_id;
end;
$$;

revoke all on function public.decline_message_request(uuid) from public;
grant execute on function public.decline_message_request(uuid) to authenticated;

-- ─────────────────────────────────────────
-- Realtime — messages only (thread lists / requests are refetched on
-- demand; open conversations subscribe live, filtered by thread_id).
-- ─────────────────────────────────────────
alter publication supabase_realtime add table public.messages;
