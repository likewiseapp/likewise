-- Add deleted_at column for "delete for everyone" support.
-- When set, the message shows "This message was deleted" to all users.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS deleted_at timestamptz;
