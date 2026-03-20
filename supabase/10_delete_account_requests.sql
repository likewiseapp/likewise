create table public.delete_account_requests (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  reason      text not null check (reason in ('not_useful', 'privacy_concerns', 'too_many_notifications', 'found_another_app', 'temporary_break', 'other')),
  description text,
  status      text not null default 'pending' check (status in ('pending', 'processed')),
  created_at  timestamptz not null default now()
);

create index idx_delete_requests_user_id on public.delete_account_requests(user_id);
create index idx_delete_requests_status  on public.delete_account_requests(status) where status = 'pending';
