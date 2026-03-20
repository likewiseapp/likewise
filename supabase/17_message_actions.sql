-- ============================================================================
-- 17_message_actions.sql
-- Reply-to, soft-delete (delete for me), and emoji reactions on messages
-- ============================================================================

-- 1) Add reply_to_id column to messages
ALTER TABLE messages
  ADD COLUMN reply_to_id UUID REFERENCES messages(id) ON DELETE SET NULL;

-- 2) Soft-delete table — "delete for me" hides a message for one user
CREATE TABLE IF NOT EXISTS message_deletions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (message_id, user_id)
);

-- 3) Emoji reactions on messages
CREATE TABLE IF NOT EXISTS message_reactions (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (message_id, user_id, emoji)
);
