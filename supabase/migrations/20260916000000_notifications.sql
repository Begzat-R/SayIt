-- ─────────────────────────────────────────
-- NOTIFICATIONS
--
-- `type` is free text, not an enum, so new notification kinds ('like',
-- 'comment', ...) can ship later without a schema migration — the app
-- just needs to add a case to its display-text switch. `entity_id` is
-- similarly untyped (no FK) since what it points to depends on `type`
-- (a follows row, a thread, later a post) and those targets don't share
-- one table.
--
-- Rows are created exclusively by SECURITY DEFINER trigger functions /
-- RPCs (see below), never by the client directly — there is deliberately
-- no INSERT policy for authenticated/anon, and it's reinforced with an
-- explicit REVOKE so this can't be quietly reopened by a future default-
-- privilege change.
-- ─────────────────────────────────────────

create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  actor_id     uuid references public.profiles(id) on delete cascade,
  type         text not null check (char_length(type) > 0),
  entity_id    uuid,
  read_at      timestamptz,
  created_at   timestamptz not null default now(),
  constraint notifications_actor_not_recipient check (actor_id is distinct from recipient_id)
);

create index idx_notifications_recipient_created on public.notifications(recipient_id, created_at desc);
create index idx_notifications_recipient_unread on public.notifications(recipient_id) where read_at is null;

alter table public.notifications replica identity full;

-- ─────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────

alter table public.notifications enable row level security;

create policy "Users can view their own notifications"
  on public.notifications for select
  to authenticated
  using (auth.uid() = recipient_id);

create policy "Users can mark their own notifications read"
  on public.notifications for update
  to authenticated
  using (auth.uid() = recipient_id)
  with check (auth.uid() = recipient_id);

-- No INSERT or DELETE policy at all — combined with the explicit REVOKEs
-- below, direct client writes of either kind are impossible regardless of
-- future default-privilege grants. Only the SECURITY DEFINER functions
-- further down (owned by a role that bypasses RLS) can create rows.
revoke insert, delete on public.notifications from authenticated, anon;

-- Mirrors the messages.read_at pattern: RLS scopes which *rows* are
-- reachable, this column-level grant additionally restricts *which
-- column* — a recipient can flip read_at but can't rewrite type/actor_id/
-- entity_id on their own notifications.
revoke update on public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;

-- ─────────────────────────────────────────
-- Trigger: new follow -> notify the person being followed
-- ─────────────────────────────────────────

create or replace function public.notify_on_follow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_blocked(new.follower_id, new.following_id) then
    insert into public.notifications (recipient_id, actor_id, type, entity_id)
    values (new.following_id, new.follower_id, 'follow', new.id);
  end if;
  return new;
end;
$$;

create trigger on_follow_created
  after insert on public.follows
  for each row execute function public.notify_on_follow();

-- ─────────────────────────────────────────
-- accept_message_request: notify the original sender that their request
-- was accepted. Folded into the existing function (redefined here) rather
-- than a separate trigger on message_requests, since it's already
-- SECURITY DEFINER with exactly the right row (v_req) in scope, and a
-- status-change trigger would have to re-derive the same information.
-- ─────────────────────────────────────────

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

  -- v_req.sender_id and v_req.receiver_id can't be blocked at this point
  -- (checked above), but the guard is kept for the same reason it's kept
  -- everywhere else in this file: defense in depth if this function is
  -- ever called from a path that skips that earlier check.
  if not public.is_blocked(v_req.sender_id, v_req.receiver_id) then
    insert into public.notifications (recipient_id, actor_id, type, entity_id)
    values (v_req.sender_id, v_req.receiver_id, 'message_request_accepted', v_thread_id);
  end if;

  return v_thread_id;
end;
$$;

-- ─────────────────────────────────────────
-- Realtime
-- ─────────────────────────────────────────
alter publication supabase_realtime add table public.notifications;
