create table public.waves (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users(id) on delete cascade,
  video_id      text        not null,
  video_url     text        not null,
  thumbnail_url text        not null,
  caption       text        default '',
  status        text        not null default 'pending'
                            check (status in ('pending', 'approved', 'rejected')),
  created_at    timestamptz not null default now()
);

create index idx_waves_user_id      on public.waves(user_id);
create index idx_waves_status       on public.waves(status) where status = 'approved';
create index idx_waves_created_at   on public.waves(created_at desc);

-- RLS
alter table public.waves enable row level security;

-- Anyone authenticated can view approved waves
create policy "approved waves are publicly visible"
  on public.waves for select
  using (status = 'approved');

-- Users can insert their own waves (status defaults to 'pending')
create policy "users can upload waves"
  on public.waves for insert
  to authenticated
  with check (auth.uid() = user_id);

-- Users can delete their own waves
create policy "users can delete own waves"
  on public.waves for delete
  to authenticated
  using (auth.uid() = user_id);

-- Only service role (admin) can update status
create policy "service role can update wave status"
  on public.waves for update
  to service_role
  using (true)
  with check (true);
