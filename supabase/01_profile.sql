create table public.profiles (
  id                  uuid primary key references auth.users(id) on delete cascade,
  username            text unique not null,
  full_name           text not null,
  email               text unique not null,
  phone               text,
  gender              text,
  bio                 text,
  avatar_url          text,
  location            text,
  date_of_birth       date,
  is_verified         boolean not null default false,
  theme_preference    text not null default 'Purple Dream',
  profile_visibility  text not null default 'public' check (profile_visibility in ('public', 'followers_only', 'private')),
  message_permission  text not null default 'everyone' check (message_permission in ('everyone', 'followers_only', 'none')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- username & email already indexed via unique constraint
create index idx_profiles_location  on public.profiles(location);
create index idx_profiles_is_verified on public.profiles(is_verified);
