-- ── twin match ───────────────────────────────────────────────────────────────
-- returns the single best hobby match for the current user
create or replace function public.fn_twin_match(current_user_id uuid)
returns table (
  id           uuid,
  username     text,
  full_name    text,
  avatar_url   text,
  bio          text,
  location     text,
  is_verified  boolean,
  match_count  bigint
)
language sql stable as $$
  select
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.bio,
    p.location,
    p.is_verified,
    count(uh2.hobby_id) as match_count
  from public.profiles p
  join public.user_hobbies uh1 on uh1.user_id = current_user_id
  join public.user_hobbies uh2 on uh2.user_id = p.id and uh2.hobby_id = uh1.hobby_id
  where p.id <> current_user_id
    and not exists (select 1 from public.blocks where blocker_id = current_user_id and blocked_id = p.id)
    and not exists (select 1 from public.blocks where blocker_id = p.id         and blocked_id = current_user_id)
  group by p.id, p.username, p.full_name, p.avatar_url, p.bio, p.location, p.is_verified
  order by match_count desc
  limit 1;
$$;


-- ── nearby users ─────────────────────────────────────────────────────────────
-- returns users sharing at least 1 hobby, ranked by match count
-- twin (rank 1) is excluded so the explore screen can show them separately
create or replace function public.fn_nearby_users(current_user_id uuid)
returns table (
  id           uuid,
  username     text,
  full_name    text,
  avatar_url   text,
  bio          text,
  location     text,
  is_verified  boolean,
  match_count  bigint
)
language sql stable as $$
  with ranked as (
    select
      p.id,
      p.username,
      p.full_name,
      p.avatar_url,
      p.bio,
      p.location,
      p.is_verified,
      count(uh2.hobby_id) as match_count,
      rank() over (order by count(uh2.hobby_id) desc) as rnk
    from public.profiles p
    join public.user_hobbies uh1 on uh1.user_id = current_user_id
    join public.user_hobbies uh2 on uh2.user_id = p.id and uh2.hobby_id = uh1.hobby_id
    where p.id <> current_user_id
      and not exists (select 1 from public.blocks where blocker_id = current_user_id and blocked_id = p.id)
      and not exists (select 1 from public.blocks where blocker_id = p.id         and blocked_id = current_user_id)
    group by p.id, p.username, p.full_name, p.avatar_url, p.bio, p.location, p.is_verified
  )
  select id, username, full_name, avatar_url, bio, location, is_verified, match_count
  from ranked
  where rnk > 1
  order by match_count desc;
$$;


-- ── user search ──────────────────────────────────────────────────────────────
-- search by name / username / bio, optionally filter by hobby category
create or replace function public.fn_search_users(
  current_user_id uuid,
  query_text      text    default '',
  hobby_category  text    default null
)
returns table (
  id           uuid,
  username     text,
  full_name    text,
  avatar_url   text,
  bio          text,
  location     text,
  is_verified  boolean,
  follower_count bigint
)
language sql stable as $$
  select distinct
    p.id,
    p.username,
    p.full_name,
    p.avatar_url,
    p.bio,
    p.location,
    p.is_verified,
    count(distinct f.follower_id) as follower_count
  from public.profiles p
  left join public.follows f       on f.following_id = p.id
  left join public.user_hobbies uh on uh.user_id     = p.id
  left join public.hobbies h       on h.id           = uh.hobby_id
  where p.id <> current_user_id
    and not exists (select 1 from public.blocks where blocker_id = current_user_id and blocked_id = p.id)
    and not exists (select 1 from public.blocks where blocker_id = p.id         and blocked_id = current_user_id)
    and (
      query_text = ''
      or p.full_name ilike '%' || query_text || '%'
      or p.username  ilike '%' || query_text || '%'
      or p.bio       ilike '%' || query_text || '%'
    )
    and (hobby_category is null or h.category = hobby_category)
  group by p.id, p.username, p.full_name, p.avatar_url, p.bio, p.location, p.is_verified
  order by follower_count desc;
$$;
