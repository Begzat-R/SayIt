-- ─────────────────────────────────────────
-- FOLLOWS
-- one row per (follower, following) pair
-- ─────────────────────────────────────────
create table public.follows (
  id           uuid primary key default gen_random_uuid(),
  follower_id  uuid not null references public.profiles(id) on delete cascade,
  following_id uuid not null references public.profiles(id) on delete cascade,
  created_at   timestamptz not null default now(),
  constraint follows_no_self_follow check (follower_id <> following_id),
  constraint follows_unique_pair unique (follower_id, following_id)
);

create index idx_follows_follower_id on public.follows(follower_id);
create index idx_follows_following_id on public.follows(following_id);

alter table public.follows enable row level security;

-- Follows are public — anyone can see who follows whom (for follower/following
-- counts and "Following" tab queries by other users' clients, etc).
create policy "Anyone can view follows"
  on public.follows for select
  using (true);

-- Only the follower themselves can create the edge, and only while they
-- haven't blocked (or been blocked by) the target.
create policy "Users can follow as themselves"
  on public.follows for insert
  to authenticated
  with check (
    auth.uid() = follower_id
    and not public.is_blocked(follower_id, following_id)
  );

-- Only the follower themselves can remove the edge (unfollow).
create policy "Users can unfollow as themselves"
  on public.follows for delete
  to authenticated
  using (auth.uid() = follower_id);
