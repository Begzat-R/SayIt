-- Allow reporting a user's profile/account directly (not just a post or
-- reply), for the Block/Report actions on a profile and within a DM thread.
-- Reuses the existing `reports` table/RLS from the initial schema —
-- `target_id` is the reported user's profile id when target_type = 'user'.
alter type public.report_target_type add value 'user';
