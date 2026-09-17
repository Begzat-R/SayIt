-- Daily "What did you try today?" posts are regular community_posts rows
-- tagged with the Situation they relate to, so they show up in
-- Trending/Following/New like any other post instead of living in a
-- separate table/feed.
--
-- situation_id is a free-text id matching Scenario.id from
-- lib/features/situations/data/scenarios.dart (e.g. 'order_food',
-- 'phone_call'). Not a foreign key since scenarios are defined client-side,
-- not in a database table.
alter table public.community_posts
  add column situation_tag text;
