-- profile with follower / following counts
create or replace view public.v_profile_stats as
select
  p.id,
  p.username,
  p.full_name,
  p.avatar_url,
  p.bio,
  p.location,
  p.is_verified,
  p.theme_preference,
  date_part('year', age(p.date_of_birth))::int as age,
  count(distinct f_in.follower_id)  as follower_count,
  count(distinct f_out.following_id) as following_count
from public.profiles p
left join public.follows f_in  on f_in.following_id  = p.id
left join public.follows f_out on f_out.follower_id   = p.id
group by p.id;


-- top creators ranked by follower count
create or replace view public.v_top_creators as
select *
from public.v_profile_stats
order by follower_count desc;


-- currently online users
create or replace view public.v_online_users as
select
  p.id,
  p.username,
  p.full_name,
  p.avatar_url,
  up.last_seen_at
from public.profiles p
join public.user_presence up on up.user_id = p.id
where up.is_online = true;
