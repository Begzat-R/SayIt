-- ─────────────────────────────────────────
-- thread_previews: one row per thread the caller participates in, with
-- that thread's latest message and the caller's own unread count in it —
-- replacing the previous client-side N+1 (one messages query per thread)
-- with a single indexed query using LATERAL joins.
--
-- security_invoker = true is load-bearing here, not decoration: without
-- it this view would run with the view owner's privileges (the migration
-- role, which bypasses RLS), and every authenticated caller would see
-- every thread in the database. With it, the view enforces threads/
-- messages/profiles RLS exactly as if the caller ran the equivalent query
-- directly. The explicit `t.user_a = auth.uid() or t.user_b = auth.uid()`
-- filter is kept anyway as a second, independent scoping mechanism —
-- auth.uid() reflects the real caller regardless of view security mode.
-- ─────────────────────────────────────────

create view public.thread_previews
with (security_invoker = true)
as
select
  t.id as thread_id,
  case when t.user_a = auth.uid() then t.user_b else t.user_a end as other_user_id,
  p.display_name as other_display_name,
  lm.content as last_message,
  lm.created_at as last_message_at,
  lm.sender_id as last_message_sender_id,
  coalesce(uc.unread_count, 0) as unread_count
from public.threads t
join public.profiles p
  on p.id = case when t.user_a = auth.uid() then t.user_b else t.user_a end
left join lateral (
  select m.content, m.created_at, m.sender_id
  from public.messages m
  where m.thread_id = t.id
  order by m.created_at desc
  limit 1
) lm on true
left join lateral (
  select count(*) as unread_count
  from public.messages m2
  where m2.thread_id = t.id
    and m2.sender_id <> auth.uid()
    and m2.read_at is null
) uc on true
where auth.uid() is not null
  and (t.user_a = auth.uid() or t.user_b = auth.uid());

grant select on public.thread_previews to authenticated;
