-- ─────────────────────────────────────────
-- SUGGESTED PEOPLE
--
-- Powers the "Suggested for you" row on the Community screen's Trending
-- feed — addresses a new user's cold start: with zero follows, the
-- Following tab has nothing to show and nobody to discover. Surfaces
-- recently active accounts (posted, liked, or commented in the last 7
-- days), most-recent-activity first, excluding the caller, anyone they
-- already follow, and any blocked relationship (either direction).
--
-- One RPC instead of 3 client-side queries (posts/likes/replies) merged
-- and de-duplicated in Dart: keeps the exclusion logic (self/following/
-- blocked) in one place instead of duplicated client-side filtering, and
-- lets Postgres do the distinct-by-user + order + limit server-side
-- instead of shipping more rows over the wire than are ever shown.
--
-- Not security definer: community_posts, post_likes, community_replies,
-- follows and profiles all already have public-read (or public-except-
-- blocked, for profiles) SELECT policies, so running as the caller lets
-- RLS double as a second layer of defense behind the explicit follows/
-- is_blocked filters below, rather than bypassing it for no functional
-- reason.
-- ─────────────────────────────────────────

-- Recency filtering on post_likes/community_replies had no supporting
-- index (only post_id/user_id) — without one, the 7-day cutoff below
-- forces a full scan of both tables. community_posts already has one
-- (20240101000000_initial_schema.sql).
create index if not exists idx_post_likes_created_at
  on public.post_likes(created_at desc);
create index if not exists idx_community_replies_created_at
  on public.community_replies(created_at desc);

create or replace function public.suggested_people(p_limit integer default 8)
returns table (id uuid, display_name text)
language sql
stable
set search_path = public
as $$
  with recent_activity as (
    select user_id, created_at from public.community_posts
    union all
    select user_id, created_at from public.post_likes
    union all
    select user_id, created_at from public.community_replies
  ),
  latest as (
    select user_id, max(created_at) as last_active_at
    from recent_activity
    where created_at > now() - interval '7 days'
      and user_id <> auth.uid()
    group by user_id
  )
  select p.id, p.display_name
  from latest l
  join public.profiles p on p.id = l.user_id
  where not exists (
      select 1 from public.follows f
      where f.follower_id = auth.uid() and f.following_id = l.user_id
    )
    and not public.is_blocked(auth.uid(), l.user_id)
  order by l.last_active_at desc
  limit greatest(p_limit, 0);
$$;

revoke all on function public.suggested_people(integer) from public;
grant execute on function public.suggested_people(integer) to authenticated;
