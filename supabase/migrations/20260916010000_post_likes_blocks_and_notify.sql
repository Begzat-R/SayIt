-- ─────────────────────────────────────────
-- post_likes already exists (20260915000000_post_likes.sql) with public
-- SELECT and self-scoped INSERT/DELETE. This migration only:
--   1. tightens the INSERT policy to also require the liker and the
--      post's author aren't blocked (in either direction), and
--   2. wires a notification to the post's author on a new like.
-- ─────────────────────────────────────────

drop policy if exists "Authenticated users can add their own likes" on public.post_likes;

create policy "Authenticated users can add their own likes"
  on public.post_likes for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not public.is_blocked(
      user_id,
      (select cp.user_id from public.community_posts cp where cp.id = post_likes.post_id)
    )
  );

-- ─────────────────────────────────────────
-- Trigger: new like -> notify the post's author. Skips self-likes (no
-- point notifying yourself) and blocked relationships (belt-and-suspenders
-- alongside the INSERT policy above, same reasoning as everywhere else in
-- this file: the policy is the real gate, the trigger check just means
-- this still behaves correctly if ever invoked from a path that bypasses
-- that policy).
-- ─────────────────────────────────────────

create or replace function public.notify_on_like()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_post_author uuid;
begin
  select user_id into v_post_author
  from public.community_posts
  where id = new.post_id;

  if v_post_author is not null
     and v_post_author <> new.user_id
     and not public.is_blocked(new.user_id, v_post_author) then
    insert into public.notifications (recipient_id, actor_id, type, entity_id)
    values (v_post_author, new.user_id, 'like', new.post_id);
  end if;

  return new;
end;
$$;

create trigger on_like_created
  after insert on public.post_likes
  for each row execute function public.notify_on_like();
