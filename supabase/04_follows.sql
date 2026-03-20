create table public.follows (
  follower_id  uuid not null references auth.users(id) on delete cascade,
  following_id uuid not null references auth.users(id) on delete cascade,
  created_at   timestamptz not null default now(),
  primary key (follower_id, following_id),
  constraint no_self_follow check (follower_id <> following_id)
);

-- PK covers follower_id lookups, need separate index for following_id (follower count queries)
create index idx_follows_following_id on public.follows(following_id);
create index idx_follows_created_at   on public.follows(created_at);
