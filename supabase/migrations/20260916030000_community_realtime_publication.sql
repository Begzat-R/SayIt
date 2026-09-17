-- community_posts, community_replies, and post_likes were never added to
-- the supabase_realtime publication in the original schema — their
-- postgres_changes subscriptions (communityPostsProvider,
-- postRepliesProvider) have been silently inert since the app's creation:
-- no errors, no failed calls, they just never fire. A new post or like
-- only ever showed up after a manual navigation-triggered refetch.
--
-- Found while live-testing the likes feature on a real device: a freshly
-- created post did not appear in the feed (even sorted by "New") without
-- leaving and re-entering the screen, and a like from another account
-- would not have updated a viewer's count either, since community_posts
-- realtime alone doesn't fire on a post_likes-only change.
alter table public.community_posts replica identity full;
alter table public.community_replies replica identity full;
alter table public.post_likes replica identity full;

alter publication supabase_realtime add table public.community_posts;
alter publication supabase_realtime add table public.community_replies;
alter publication supabase_realtime add table public.post_likes;
