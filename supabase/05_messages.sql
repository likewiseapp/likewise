create table public.conversations (
  id         uuid primary key default gen_random_uuid(),
  user1_id   uuid not null references auth.users(id) on delete cascade,
  user2_id   uuid not null references auth.users(id) on delete cascade,
  status     text not null default 'request' check (status in ('request', 'active', 'declined')),
  created_at timestamptz not null default now(),
  constraint no_self_conversation check (user1_id <> user2_id),
  constraint unique_conversation unique (user1_id, user2_id)
);

create table public.messages (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id       uuid not null references auth.users(id) on delete cascade,
  content         text not null,
  is_read         boolean not null default false,
  created_at      timestamptz not null default now()
);

-- conversations
create index idx_conversations_user1_id on public.conversations(user1_id);
create index idx_conversations_user2_id on public.conversations(user2_id);
create index idx_conversations_status   on public.conversations(status);

-- messages
create index idx_messages_conversation_id            on public.messages(conversation_id);
create index idx_messages_conversation_id_created_at on public.messages(conversation_id, created_at);
create index idx_messages_sender_id                  on public.messages(sender_id);
create index idx_messages_is_read                    on public.messages(is_read) where is_read = false;
