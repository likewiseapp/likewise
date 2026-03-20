create table public.reports (
  id                   uuid primary key default gen_random_uuid(),
  reporter_id          uuid not null references auth.users(id) on delete cascade,
  reported_entity_id   uuid not null,
  reported_entity_type text not null check (reported_entity_type in ('profile', 'reel', 'comment', 'message')),
  category             text not null check (category in ('spam', 'harassment', 'inappropriate_content', 'fake_account', 'hate_speech', 'violence', 'other')),
  description          text,
  status               text not null default 'pending' check (status in ('pending', 'reviewed', 'resolved', 'dismissed')),
  created_at           timestamptz not null default now()
);

create index idx_reports_reporter_id        on public.reports(reporter_id);
create index idx_reports_reported_entity_id on public.reports(reported_entity_id);
create index idx_reports_status             on public.reports(status) where status = 'pending';
