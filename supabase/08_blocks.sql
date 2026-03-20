create table public.blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  reason     text not null check (reason in ('spam', 'harassment', 'inappropriate_content', 'fake_account', 'hate_speech', 'other')),
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint no_self_block check (blocker_id <> blocked_id)
);

-- PK covers blocker_id lookups, need reverse index for blocked_id
create index idx_blocks_blocked_id on public.blocks(blocked_id);
