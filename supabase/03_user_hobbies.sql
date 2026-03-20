create table public.user_hobbies (
  user_id    uuid not null references auth.users(id) on delete cascade,
  hobby_id   smallint not null references public.hobbies(id) on delete cascade,
  is_primary boolean not null default false,
  primary key (user_id, hobby_id)
);

-- ensures only one primary hobby per user
create unique index one_primary_per_user on public.user_hobbies(user_id) where is_primary = true;

-- user_id already covered by PK, need reverse lookup by hobby
create index idx_user_hobbies_hobby_id on public.user_hobbies(hobby_id);
