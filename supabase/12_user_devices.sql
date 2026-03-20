create table public.user_devices (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  fcm_token   text not null,
  device_type text not null check (device_type in ('android', 'ios')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index idx_user_devices_user_id   on public.user_devices(user_id);
create unique index idx_user_devices_fcm_token on public.user_devices(fcm_token);
