-- ─────────────────────────────────────────────────────────────────────────────
-- 16_location.sql  —  Geographic coordinates + proximity query
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Add lat/lng columns to profiles (already applied — safe to re-run)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS latitude  NUMERIC(10, 8),
  ADD COLUMN IF NOT EXISTS longitude NUMERIC(11, 8);

-- 2. Partial index for fast proximity scans
CREATE INDEX IF NOT EXISTS profiles_lat_lng_idx
  ON public.profiles (latitude, longitude)
  WHERE latitude IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- fn_nearby_by_location
--
-- Returns users sorted by physical proximity to the calling user.
-- Fallback: if the caller has no coordinates, all users are returned sorted
-- by hobby-match count (same behaviour as the legacy fn_nearby_users).
-- Users without coordinates are always included but sorted last.
--
-- Returns: id, username, full_name, avatar_url, bio, location,
--          is_verified, match_count, distance_km
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_nearby_by_location(
  current_user_id UUID,
  radius_km       FLOAT DEFAULT 50
)
RETURNS TABLE (
  id           UUID,
  username     TEXT,
  full_name    TEXT,
  avatar_url   TEXT,
  bio          TEXT,
  location     TEXT,
  is_verified  BOOLEAN,
  match_count  BIGINT,
  distance_km  FLOAT
)
LANGUAGE sql
STABLE
AS $$
  WITH
    -- Current user's coordinates (may be NULL rows if profile missing)
    me AS (
      SELECT latitude, longitude
      FROM   public.profiles
      WHERE  id = current_user_id
    ),

    -- Hobby matches between the caller and every other user
    matches AS (
      SELECT uh.user_id, COUNT(*) AS cnt
      FROM   public.user_hobbies uh
      WHERE  uh.hobby_id IN (
               SELECT hobby_id FROM public.user_hobbies WHERE user_id = current_user_id
             )
        AND  uh.user_id <> current_user_id
      GROUP  BY uh.user_id
    ),

    -- Candidate profiles with precomputed distance
    candidates AS (
      SELECT
        p.id,
        p.username,
        p.full_name,
        p.avatar_url,
        p.bio,
        p.location,
        p.is_verified,
        COALESCE(m.cnt, 0)::BIGINT AS match_count,
        CASE
          WHEN (SELECT latitude FROM me) IS NULL OR p.latitude IS NULL THEN NULL::FLOAT
          ELSE (
            -- Haversine formula — LEAST clamps to 1.0 to prevent ASIN domain errors
            -- caused by floating-point values marginally above 1.0
            2.0 * 6371.0 * ASIN(LEAST(1.0, SQRT(
              POWER(SIN(RADIANS((p.latitude  - (SELECT latitude  FROM me)) / 2.0)), 2) +
              COS(RADIANS((SELECT latitude  FROM me))) *
              COS(RADIANS(p.latitude)) *
              POWER(SIN(RADIANS((p.longitude - (SELECT longitude FROM me)) / 2.0)), 2)
            )))
          )
        END::FLOAT AS distance_km
      FROM   public.profiles p
      LEFT   JOIN matches m ON m.user_id = p.id
      WHERE  p.id <> current_user_id
        -- Use NOT EXISTS instead of NOT IN to handle NULL-safe block exclusion
        AND  NOT EXISTS (
          SELECT 1 FROM public.blocks
          WHERE  blocker_id = current_user_id AND blocked_id = p.id
        )
        AND  NOT EXISTS (
          SELECT 1 FROM public.blocks
          WHERE  blocker_id = p.id AND blocked_id = current_user_id
        )
    )

  SELECT id, username, full_name, avatar_url, bio, location, is_verified, match_count, distance_km
  FROM   candidates
  WHERE
    (SELECT latitude FROM me) IS NULL  -- caller has no coords → show everyone
    OR distance_km IS NULL             -- candidate has no coords → always include
    OR distance_km <= radius_km        -- candidate is within radius
  ORDER BY
    distance_km ASC NULLS LAST,
    match_count  DESC;
$$;
