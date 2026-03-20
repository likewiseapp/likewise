create table public.hobbies (
  id       smallint primary key generated always as identity,
  name     text unique not null,
  icon     text not null,
  color    text not null,
  category text not null
);

-- name already indexed via unique constraint
create index idx_hobbies_category on public.hobbies(category);

insert into public.hobbies (name, icon, color, category) values
  ('Football',    '⚽', '#FF6B6B', 'Sports'),
  ('Cricket',     '🏏', '#4ECDC4', 'Sports'),
  ('Guitar',      '🎸', '#FFD93D', 'Music'),
  ('Singing',     '🎤', '#6C63FF', 'Music'),
  ('Music',       '🎵', '#E74C3C', 'Music'),
  ('Writing',     '✍️', '#95A5A6', 'Creative'),
  ('Art',         '🎨', '#9B59B6', 'Creative'),
  ('Photography', '📸', '#E056FD', 'Creative'),
  ('Reading',     '📚', '#A8D8EA', 'Literature'),
  ('Hiking',      '🥾', '#2ECC71', 'Outdoor'),
  ('Travel',      '✈️', '#34495E', 'Outdoor'),
  ('Gaming',      '🎮', '#3498DB', 'Gaming'),
  ('Coding',      '💻', '#2C3E50', 'Gaming'),
  ('Cooking',     '🍳', '#E67E22', 'Food'),
  ('Dancing',     '💃', '#F1C40F', 'Fitness'),
  ('Yoga',        '🧘', '#1ABC9C', 'Fitness');
