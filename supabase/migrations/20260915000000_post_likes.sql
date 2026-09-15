-- post_likes: one row per (user, post) pair.
-- Unique constraint prevents double-liking.

create table public.post_likes (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid not null references public.community_posts(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);

alter table public.post_likes enable row level security;

create policy "Anyone can read post_likes"
  on public.post_likes for select using (true);

create policy "Authenticated users can add their own likes"
  on public.post_likes for insert to authenticated
  with check (auth.uid() = user_id);

create policy "Authenticated users can remove their own likes"
  on public.post_likes for delete to authenticated
  using (auth.uid() = user_id);

create index idx_post_likes_post_id on public.post_likes(post_id);
create index idx_post_likes_user_id on public.post_likes(user_id);
