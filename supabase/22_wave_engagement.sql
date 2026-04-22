-- Wave engagement: views, likes, comments.
-- Cached counts live on `waves` for fast feed reads; the source-of-truth rows
-- live in `wave_likes` and `wave_comments`. Triggers keep counts in sync.
-- Views are treated as a simple counter (no per-user row) bumped via RPC.

-- ── 1. Cached count columns on waves ─────────────────────────────────────
ALTER TABLE public.waves
  ADD COLUMN IF NOT EXISTS view_count    int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS like_count    int NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS comment_count int NOT NULL DEFAULT 0;

-- ── 2. wave_likes (one row per user per wave) ────────────────────────────
CREATE TABLE IF NOT EXISTS public.wave_likes (
  wave_id    uuid        NOT NULL REFERENCES public.waves(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (wave_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_wave_likes_user_id ON public.wave_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_wave_likes_created_at
  ON public.wave_likes(created_at DESC);

-- ── 3. wave_comments (flat — no replies) ─────────────────────────────────
CREATE TABLE IF NOT EXISTS public.wave_comments (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  wave_id    uuid        NOT NULL REFERENCES public.waves(id) ON DELETE CASCADE,
  user_id    uuid        NOT NULL REFERENCES auth.users(id)  ON DELETE CASCADE,
  content    text        NOT NULL CHECK (length(content) BETWEEN 1 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_wave_comments_wave_id_created_at
  ON public.wave_comments(wave_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_wave_comments_user_id ON public.wave_comments(user_id);

-- ── 4. Triggers: keep like_count / comment_count on waves in sync ────────
CREATE OR REPLACE FUNCTION public.fn_bump_wave_like_count()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.waves SET like_count = like_count + 1 WHERE id = NEW.wave_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.waves SET like_count = GREATEST(like_count - 1, 0)
      WHERE id = OLD.wave_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_wave_likes_count ON public.wave_likes;
CREATE TRIGGER trg_wave_likes_count
  AFTER INSERT OR DELETE ON public.wave_likes
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bump_wave_like_count();

CREATE OR REPLACE FUNCTION public.fn_bump_wave_comment_count()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE public.waves SET comment_count = comment_count + 1
      WHERE id = NEW.wave_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.waves SET comment_count = GREATEST(comment_count - 1, 0)
      WHERE id = OLD.wave_id;
  END IF;
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_wave_comments_count ON public.wave_comments;
CREATE TRIGGER trg_wave_comments_count
  AFTER INSERT OR DELETE ON public.wave_comments
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_bump_wave_comment_count();

-- ── 5. View count RPC ────────────────────────────────────────────────────
-- Called by the app once per view (debounce on the client side to avoid
-- inflating on scroll/re-render). SECURITY DEFINER so any authenticated
-- user can bump the count without needing UPDATE on waves.
CREATE OR REPLACE FUNCTION public.increment_wave_view(target_wave_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.waves
  SET view_count = view_count + 1
  WHERE id = target_wave_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.increment_wave_view(uuid) TO authenticated, anon;

-- ── 6. Realtime publication (so the feed updates counts live) ────────────
ALTER PUBLICATION supabase_realtime ADD TABLE public.wave_likes;
ALTER PUBLICATION supabase_realtime ADD TABLE public.wave_comments;
ALTER TABLE public.wave_likes    REPLICA IDENTITY FULL;
ALTER TABLE public.wave_comments REPLICA IDENTITY FULL;
