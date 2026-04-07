-- Allow community creators to update their own row (for Edit community screen).
drop policy if exists "communities_update_creator" on public.communities;
create policy "communities_update_creator"
  on public.communities
  for update
  using (creator_id = (select auth.uid()))
  with check (creator_id = (select auth.uid()));
