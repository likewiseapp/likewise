create table public.app_config (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

insert into public.app_config (key, value) values
  ('about_us',       '{"title": "About Us", "content": ""}'),
  ('contact_us',     '{"email": "", "phone": "", "address": ""}'),
  ('privacy_policy', '{"title": "Privacy Policy", "content": ""}'),
  ('terms',          '{"title": "Terms & Conditions", "content": ""}'),
  ('social_links',   '{"instagram": "", "twitter": "", "facebook": "", "website": ""}'),
  ('app_version',    '{"latest": "1.0.0", "min_supported": "1.0.0", "force_update": false}');
