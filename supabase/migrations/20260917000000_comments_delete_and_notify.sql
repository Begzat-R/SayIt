-- ─────────────────────────────────────────
-- COMMENTS (on community_replies)
--
-- community_replies already exists (20240101000000_initial_schema.sql)
-- with public SELECT, self-scoped INSERT, and self-scoped DELETE. This
-- migration brings it in line with the same conventions established for
-- post_likes (20260916010000_post_likes_blocks_and_notify.sql) and
-- notifications (20260916000000_notifications.sql):
--   1. tightens INSERT to also require the commenter and the post's
--      author aren't blocked (in either direction),
--   2. adds a second DELETE policy so the post's author can remove any
--      comment on their own post, not just the comment's own author,
--   3. wires a notification to the post's author on a new comment.
--
-- No UPDATE policy is added — comments stay post-once, matching v1 scope.
-- ─────────────────────────────────────────

drop policy if exists "Authenticated users can create replies" on public.community_replies;

create policy "Authenticated users can create replies"
  on public.community_replies for insert
  to authenticated
  with check (
    auth.uid() = user_id
    and not public.is_blocked(
      user_id,
      (select cp.user_id from public.community_posts cp where cp.id = community_replies.post_id)
    )
  );

-- ─────────────────────────────────────────
-- Second DELETE policy: the post's author can remove any comment on their
-- own post (the existing "Users can delete their own replies" policy,
-- scoped to auth.uid() = user_id, still covers a commenter removing their
-- own comment — RLS policies for the same command are OR'd together, so
-- both apply).
-- ─────────────────────────────────────────

create policy "Post authors can delete comments on their posts"
  on public.community_replies for delete
  to authenticated
  using (
    auth.uid() = (
      select cp.user_id from public.community_posts cp where cp.id = community_replies.post_id
    )
  );

-- ─────────────────────────────────────────
-- Trigger: new comment -> notify the post's author. Skips self-comments
-- (no point notifying yourself) and blocked relationships (belt-and-
-- suspenders alongside the INSERT policy above — same reasoning as
-- notify_on_like: the policy is the real gate, this check just means the
-- trigger still behaves correctly if ever invoked from a path that
-- bypasses that policy).
-- ─────────────────────────────────────────

create or replace function public.notify_on_comment()
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
    values (v_post_author, new.user_id, 'comment', new.post_id);
  end if;

  return new;
end;
$$;

create trigger on_comment_created
  after insert on public.community_replies
  for each row execute function public.notify_on_comment();
