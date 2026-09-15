-- Allow anyone (including anon) to read the profiles table so that
-- display_names appear correctly in the community feed without auth.
-- The previous "Users can view their own profile" policy is superseded
-- by this more permissive one; both are kept (Supabase ORs SELECT policies).

create policy "Public can read profiles"
  on public.profiles for select
  using (true);
