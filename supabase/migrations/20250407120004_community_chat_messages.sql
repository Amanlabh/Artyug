-- Guild "main" channel messages (e.g. Artyug-main). One thread per community.
create table if not exists public.community_chat_messages (
  id uuid primary key default gen_random_uuid(),
  community_id uuid not null references public.communities (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

create index if not exists idx_community_chat_messages_community_created
  on public.community_chat_messages (community_id, created_at);

alter table public.community_chat_messages enable row level security;

drop policy if exists "community_chat_select_members" on public.community_chat_messages;
drop policy if exists "community_chat_insert_members" on public.community_chat_messages;

-- Members of the community can read messages.
create policy "community_chat_select_members"
  on public.community_chat_messages
  for select
  using (
    exists (
      select 1
      from public.community_members m
      where m.community_id = community_chat_messages.community_id
        and m.user_id = (select auth.uid())
    )
  );

-- Members can post as themselves.
create policy "community_chat_insert_members"
  on public.community_chat_messages
  for insert
  with check (
    sender_id = (select auth.uid())
    and exists (
      select 1
      from public.community_members m
      where m.community_id = community_chat_messages.community_id
        and m.user_id = (select auth.uid())
    )
  );
