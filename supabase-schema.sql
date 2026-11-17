create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username = lower(username) and username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null default '',
  bio text not null default '' check (char_length(bio) <= 280),
  avatar_url text not null default '',
  unit text not null default 'lb' check (unit in ('lb', 'kg')),
  created_at timestamptz not null default now()
);

create table if not exists public.user_data (
  user_id uuid primary key references auth.users(id) on delete cascade,
  data jsonb not null default '{"workouts":[],"weights":[],"custom":[],"draft":null,"sched":{}}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.follows (
  follower_id uuid not null references public.profiles(id) on delete cascade,
  followed_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (follower_id, followed_id),
  check (follower_id <> followed_id)
);

create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  caption text not null default '',
  workout jsonb not null,
  media jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);

create table if not exists public.post_likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);

create table if not exists public.post_comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  text text not null check (char_length(text) between 1 and 2000),
  created_at timestamptz not null default now()
);

create index if not exists posts_author_created_idx on public.posts (author_id, created_at desc);
create index if not exists comments_post_created_idx on public.post_comments (post_id, created_at);

grant select, update on public.profiles to authenticated;
grant select, insert, update on public.user_data to authenticated;
grant select, insert, delete on public.follows to authenticated;
grant select, insert, update, delete on public.posts to authenticated;
grant select, insert, delete on public.post_likes to authenticated;
grant select, insert, update, delete on public.post_comments to authenticated;

create or replace function public.create_fitlog_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_username text := lower(coalesce(new.raw_user_meta_data->>'username', ''));
  requested_unit text := coalesce(new.raw_user_meta_data->>'unit', 'lb');
begin
  if requested_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'Username must be 3-24 characters using lowercase letters, numbers, or underscores.';
  end if;
  if requested_unit not in ('lb', 'kg') then requested_unit := 'lb'; end if;
  insert into public.profiles (id, username, display_name, unit)
  values (new.id, requested_username, requested_username, requested_unit);
  insert into public.user_data (user_id) values (new.id);
  return new;
end;
$$;

drop trigger if exists fitlog_auth_user_created on auth.users;
create trigger fitlog_auth_user_created
  after insert on auth.users
  for each row execute function public.create_fitlog_profile();

alter table public.profiles enable row level security;
alter table public.user_data enable row level security;
alter table public.follows enable row level security;
alter table public.posts enable row level security;
alter table public.post_likes enable row level security;
alter table public.post_comments enable row level security;

drop policy if exists "Profiles visible to signed-in users" on public.profiles;
create policy "Profiles visible to signed-in users" on public.profiles
  for select to authenticated using (true);
drop policy if exists "Users update their own profile" on public.profiles;
create policy "Users update their own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Users read their own data" on public.user_data;
create policy "Users read their own data" on public.user_data
  for select to authenticated using (user_id = auth.uid());
drop policy if exists "Users create their own data" on public.user_data;
create policy "Users create their own data" on public.user_data
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users update their own data" on public.user_data;
create policy "Users update their own data" on public.user_data
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "Signed-in users read follows" on public.follows;
create policy "Signed-in users read follows" on public.follows
  for select to authenticated using (true);
drop policy if exists "Users follow from their own account" on public.follows;
create policy "Users follow from their own account" on public.follows
  for insert to authenticated with check (follower_id = auth.uid());
drop policy if exists "Users unfollow from their own account" on public.follows;
create policy "Users unfollow from their own account" on public.follows
  for delete to authenticated using (follower_id = auth.uid());

drop policy if exists "Signed-in users read posts" on public.posts;
create policy "Signed-in users read posts" on public.posts
  for select to authenticated using (true);
drop policy if exists "Users publish their own posts" on public.posts;
create policy "Users publish their own posts" on public.posts
  for insert to authenticated with check (author_id = auth.uid());
drop policy if exists "Users edit their own posts" on public.posts;
create policy "Users edit their own posts" on public.posts
  for update to authenticated using (author_id = auth.uid()) with check (author_id = auth.uid());
drop policy if exists "Users delete their own posts" on public.posts;
create policy "Users delete their own posts" on public.posts
  for delete to authenticated using (author_id = auth.uid());

drop policy if exists "Signed-in users read likes" on public.post_likes;
create policy "Signed-in users read likes" on public.post_likes
  for select to authenticated using (true);
drop policy if exists "Users like as themselves" on public.post_likes;
create policy "Users like as themselves" on public.post_likes
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users remove their own likes" on public.post_likes;
create policy "Users remove their own likes" on public.post_likes
  for delete to authenticated using (user_id = auth.uid());

drop policy if exists "Signed-in users read comments" on public.post_comments;
create policy "Signed-in users read comments" on public.post_comments
  for select to authenticated using (true);
drop policy if exists "Users comment as themselves" on public.post_comments;
create policy "Users comment as themselves" on public.post_comments
  for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "Users edit their own comments" on public.post_comments;
create policy "Users edit their own comments" on public.post_comments
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "Users delete their own comments" on public.post_comments;
create policy "Users delete their own comments" on public.post_comments
  for delete to authenticated using (user_id = auth.uid());

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fitlog-media', 'fitlog-media', true, 10485760, array['image/jpeg','image/png','image/webp','image/gif','video/mp4','video/webm','video/quicktime'])
on conflict (id) do update set public = true, file_size_limit = 10485760;

drop policy if exists "FitLog media is publicly readable" on storage.objects;
create policy "FitLog media is publicly readable" on storage.objects
  for select to public using (bucket_id = 'fitlog-media');
drop policy if exists "Users upload media to their own folder" on storage.objects;
create policy "Users upload media to their own folder" on storage.objects
  for insert to authenticated with check (bucket_id = 'fitlog-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users update media in their own folder" on storage.objects;
create policy "Users update media in their own folder" on storage.objects
  for update to authenticated using (bucket_id = 'fitlog-media' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'fitlog-media' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "Users delete media in their own folder" on storage.objects;
create policy "Users delete media in their own folder" on storage.objects
  for delete to authenticated using (bucket_id = 'fitlog-media' and (storage.foldername(name))[1] = auth.uid()::text);

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin alter publication supabase_realtime add table public.profiles; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.follows; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.posts; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.post_likes; exception when duplicate_object then null; end;
    begin alter publication supabase_realtime add table public.post_comments; exception when duplicate_object then null; end;
  end if;
end;
$$;