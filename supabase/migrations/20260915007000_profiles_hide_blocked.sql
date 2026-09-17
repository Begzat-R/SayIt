-- Exclude blocked relationships from profile visibility (search, profile
-- pages, etc). Mutual: if either side has blocked the other, neither can
-- fetch the other's profile row via the API.
--
-- The previous "Public can read profiles" policy (using (true)) is dropped
-- and replaced — Postgres ORs permissive SELECT policies together, so
-- leaving the old unconditional one in place would make this a no-op.
drop policy if exists "Public can read profiles" on public.profiles;

create policy "Public can read profiles except blocked relationships"
  on public.profiles for select
  using (
    auth.uid() is null
    or auth.uid() = id
    or not public.is_blocked(auth.uid(), id)
  );
