-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────
-- PROFILES
-- ─────────────────────────────────────────
create table public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data->>'display_name');
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ─────────────────────────────────────────
-- PRACTICE SESSIONS
-- ─────────────────────────────────────────
create table public.practice_sessions (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references public.profiles(id) on delete cascade,
  scenario_id  text not null,
  felt_good    boolean not null default false,
  duration_ms  integer,
  recording_url text,
  created_at   timestamptz not null default now()
);

alter table public.practice_sessions enable row level security;

create policy "Users can view their own sessions"
  on public.practice_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert their own sessions"
  on public.practice_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own sessions"
  on public.practice_sessions for delete
  using (auth.uid() = user_id);

create index idx_practice_sessions_user_id on public.practice_sessions(user_id);
create index idx_practice_sessions_created_at on public.practice_sessions(created_at desc);

-- ─────────────────────────────────────────
-- COMMUNITY POSTS
-- ─────────────────────────────────────────
create table public.community_posts (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  scenario_id text,
  body        text not null check (char_length(body) <= 1000),
  is_anonymous boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.community_posts enable row level security;

create policy "Anyone can view community posts"
  on public.community_posts for select
  using (true);

create policy "Authenticated users can create posts"
  on public.community_posts for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own posts"
  on public.community_posts for update
  using (auth.uid() = user_id);

create policy "Users can delete their own posts"
  on public.community_posts for delete
  using (auth.uid() = user_id);

create index idx_community_posts_created_at on public.community_posts(created_at desc);
create index idx_community_posts_user_id on public.community_posts(user_id);

-- ─────────────────────────────────────────
-- COMMUNITY REPLIES
-- ─────────────────────────────────────────
create table public.community_replies (
  id          uuid primary key default uuid_generate_v4(),
  post_id     uuid not null references public.community_posts(id) on delete cascade,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  body        text not null check (char_length(body) <= 500),
  is_anonymous boolean not null default false,
  created_at  timestamptz not null default now()
);

alter table public.community_replies enable row level security;

create policy "Anyone can view replies"
  on public.community_replies for select
  using (true);

create policy "Authenticated users can create replies"
  on public.community_replies for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own replies"
  on public.community_replies for delete
  using (auth.uid() = user_id);

create index idx_community_replies_post_id on public.community_replies(post_id);

-- ─────────────────────────────────────────
-- REPORTS
-- ─────────────────────────────────────────
create type public.report_target_type as enum ('post', 'reply');

create table public.reports (
  id           uuid primary key default uuid_generate_v4(),
  reporter_id  uuid not null references public.profiles(id) on delete cascade,
  target_type  public.report_target_type not null,
  target_id    uuid not null,
  reason       text not null check (char_length(reason) <= 300),
  resolved     boolean not null default false,
  created_at   timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "Users can submit reports"
  on public.reports for insert
  with check (auth.uid() = reporter_id);

create policy "Users can view their own reports"
  on public.reports for select
  using (auth.uid() = reporter_id);

-- Prevent duplicate reports from the same user on the same target
create unique index idx_reports_unique_per_reporter
  on public.reports(reporter_id, target_type, target_id);
