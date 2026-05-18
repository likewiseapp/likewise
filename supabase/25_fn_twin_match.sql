-- fn_twin_match: find the best "twin" for a user.
-- A twin must share ALL of the current user's hobbies (not just some).
-- Returns at most 1 row — the user with the highest follower count among
-- perfect matches, excluding: self, blocked users, already-followed users,
-- and private profiles.

DROP FUNCTION IF EXISTS fn_twin_match(uuid);

CREATE FUNCTION fn_twin_match(current_user_id uuid)
RETURNS TABLE (
  id            uuid,
  username      text,
  full_name     text,
  avatar_url    text,
  bio           text,
  location      text,
  is_verified   boolean,
  match_count   int,
  follower_count bigint
)
LANGUAGE sql STABLE
AS $$
  WITH my_hobbies AS (
    SELECT hobby_id
    FROM user_hobbies
    WHERE user_id = current_user_id
  ),
  my_hobby_count AS (
    SELECT count(*)::int AS cnt FROM my_hobbies
  ),
  candidates AS (
    SELECT
      uh.user_id,
      count(*)::int AS shared_count
    FROM user_hobbies uh
    INNER JOIN my_hobbies mh ON mh.hobby_id = uh.hobby_id
    WHERE uh.user_id <> current_user_id
    GROUP BY uh.user_id
  ),
  perfect_matches AS (
    SELECT c.user_id, c.shared_count
    FROM candidates c, my_hobby_count mhc
    WHERE c.shared_count = mhc.cnt   -- must match ALL of my hobbies
      AND mhc.cnt > 0                -- skip users with no hobbies
  )
  SELECT
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.bio,
    p.location,
    p.is_verified,
    pm.shared_count AS match_count,
    (SELECT count(*) FROM follows f WHERE f.following_id = p.id) AS follower_count
  FROM perfect_matches pm
  INNER JOIN profiles p ON p.id = pm.user_id
  WHERE
    -- not blocked in either direction
    NOT EXISTS (
      SELECT 1 FROM blocks b
      WHERE (b.blocker_id = current_user_id AND b.blocked_id = p.id)
         OR (b.blocker_id = p.id AND b.blocked_id = current_user_id)
    )
    -- not already following
    AND NOT EXISTS (
      SELECT 1 FROM follows f
      WHERE f.follower_id = current_user_id AND f.following_id = p.id
    )
    -- not a private profile
    AND COALESCE(p.profile_visibility, 'public') <> 'private'
  ORDER BY follower_count DESC
  LIMIT 1;
$$;
