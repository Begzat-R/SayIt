-- ─────────────────────────────────────────
-- BLOCKS
-- one row per (blocker, blocked) pair. Directional: blocker_id blocked
-- blocked_id. Enforcement of the *relationship* (checked from either side)
-- happens via the public.is_blocked() helper below, which is used across
-- follows/profiles/message_requests/messages RLS policies.
-- ─────────────────────────────────────────
create table public.blocks (
  id          uuid primary key default gen_random_uuid(),
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  constraint blocks_no_self_block check (blocker_id <> blocked_id),
  constraint blocks_unique_pair unique (blocker_id, blocked_id)
);

create index idx_blocks_blocker_id on public.blocks(blocker_id);
create index idx_blocks_blocked_id on public.blocks(blocked_id);

alter table public.blocks enable row level security;

-- A user may only see the blocks *they* created (not who has blocked them —
-- that would leak the block to the blocked party through the API).
create policy "Users can view blocks they created"
  on public.blocks for select
  to authenticated
  using (auth.uid() = blocker_id);

create policy "Users can block as themselves"
  on public.blocks for insert
  to authenticated
  with check (auth.uid() = blocker_id);

create policy "Users can unblock as themselves"
  on public.blocks for delete
  to authenticated
  using (auth.uid() = blocker_id);

-- ─────────────────────────────────────────
-- is_blocked(a, b): true if a blocked b OR b blocked a.
--
-- SECURITY DEFINER so it can see both sides of the relationship even though
-- the `blocks` SELECT policy above only lets a user read blocks *they*
-- created — otherwise a query running as the blocked party could never
-- observe the block placed against them, and the other-direction check
-- (e.g. "did this profile block me?") would silently fail open. The
-- function only ever returns a boolean, so it never leaks which side
-- initiated the block or any other row data.
-- ─────────────────────────────────────────
create or replace function public.is_blocked(user_a uuid, user_b uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.blocks
    where (blocker_id = user_a and blocked_id = user_b)
       or (blocker_id = user_b and blocked_id = user_a)
  );
$$;

revoke all on function public.is_blocked(uuid, uuid) from public;
grant execute on function public.is_blocked(uuid, uuid) to authenticated, anon;
