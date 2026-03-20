create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references auth.users(id) on delete cascade,
  actor_id     uuid not null references auth.users(id) on delete cascade,
  type         text not null check (type in ('follow', 'like', 'comment', 'mention', 'twin')),
  entity_id    uuid,
  entity_type  text check (entity_type in ('reel', 'comment', 'profile')),
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index idx_notifications_recipient_id            on public.notifications(recipient_id);
create index idx_notifications_recipient_id_created_at on public.notifications(recipient_id, created_at);
create index idx_notifications_is_read                 on public.notifications(recipient_id, is_read) where is_read = false;
create index idx_notifications_type                    on public.notifications(type);
