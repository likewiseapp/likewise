create table public.notification_preferences (
  user_id          uuid primary key references auth.users(id) on delete cascade,
  follows          boolean not null default true,
  likes            boolean not null default true,
  comments         boolean not null default true,
  mentions         boolean not null default true,
  messages         boolean not null default true,
  twin_match       boolean not null default true,
  push_enabled     boolean not null default true,
  updated_at       timestamptz not null default now()
);
