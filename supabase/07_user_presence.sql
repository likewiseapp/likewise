create table public.user_presence (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  is_online    boolean not null default false,
  last_seen_at timestamptz not null default now()
);

create index idx_user_presence_is_online on public.user_presence(is_online) where is_online = true;
