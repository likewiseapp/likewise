# Likewise — Supabase Schema Analysis

> 15 SQL files | PostgreSQL / Supabase | Analyzed 2026-02-28

---

## File Map

| File | Table(s) | Purpose |
|------|----------|---------|
| 01_profile.sql | `profiles` | Core user entity |
| 02_hobbies.sql | `hobbies` | Hobby reference data (16 rows seeded) |
| 03_user_hobbies.sql | `user_hobbies` | User ↔ hobby junction |
| 04_follows.sql | `follows` | Follow relationships |
| 05_messages.sql | `conversations`, `messages` | Direct messaging |
| 06_notifications.sql | `notifications` | Activity feed |
| 07_user_presence.sql | `user_presence` | Online/offline status |
| 08_blocks.sql | `blocks` | User blocking |
| 09_reports.sql | `reports` | Content/user reports |
| 10_delete_account_requests.sql | `delete_account_requests` | GDPR/account deletion |
| 11_app_config.sql | `app_config` | Key-value app settings (JSONB) |
| 12_user_devices.sql | `user_devices` | FCM push notification tokens |
| 13_notification_preferences.sql | `notification_preferences` | Per-user notification toggles |
| 14_views.sql | 3 views | Aggregated profile stats, top creators, online users |
| 15_functions.sql | 3 functions | Twin match, nearby users, user search |

---

## Table-by-Table Breakdown

### 01 — `profiles`
- Linked to `auth.users(id)` via FK + ON DELETE CASCADE
- Columns: `id`, `username` (unique), `email` (unique), `full_name`, `phone`, `gender`, `bio`, `avatar_url`, `location`, `date_of_birth`, `is_verified`, `theme_preference`, `profile_visibility`, `message_permission`, `created_at`, `updated_at`
- CHECK constraints: `profile_visibility` IN ('public','followers_only','private'), `message_permission` IN ('everyone','followers_only','none')
- Indexes: `username`, `email` (via unique), `location`, `is_verified`

### 02 — `hobbies`
- Lookup/reference table — 16 seeded hobbies across 5 categories
- Categories: Sports, Music, Creative, Literature, Outdoor, Gaming, Food, Fitness
- Columns: `id` (smallint identity), `name` (unique), `icon` (emoji), `color` (hex), `category`
- Index: `category`

### 03 — `user_hobbies`
- Junction table: `(user_id, hobby_id)` composite PK
- `is_primary` boolean with **partial unique index** — enforces exactly one primary hobby per user
- Index: `hobby_id` for reverse lookups

### 04 — `follows`
- `(follower_id, following_id)` composite PK
- CHECK `no_self_follow`: `follower_id <> following_id`
- Indexes: `following_id`, `created_at`

### 05 — `conversations` + `messages`
- **Conversations**: `status` IN ('request','active','declined'), unique `(user1_id, user2_id)`, CHECK `no_self_conversation`
- **Messages**: `is_read` boolean with partial index `WHERE is_read = false`, compound index `(conversation_id, created_at)` for sorted retrieval

### 06 — `notifications`
- Types: 'follow','like','comment','mention','twin'
- Polymorphic entity ref: `entity_id` (uuid) + `entity_type` IN ('reel','comment','profile') — **no FK constraint** (see issues)
- Partial index on `(recipient_id, is_read) WHERE is_read = false`

### 07 — `user_presence`
- Single row per user: `user_id` PK, `is_online`, `last_seen_at`
- Partial index `WHERE is_online = true` — only indexes online users

### 08 — `blocks`
- `(blocker_id, blocked_id)` composite PK
- `reason` IN ('spam','harassment','inappropriate_content','fake_account','hate_speech','other')
- CHECK `no_self_block`
- Index: `blocked_id` for reverse lookups

### 09 — `reports`
- `reported_entity_type` IN ('profile','reel','comment','message')
- `category` IN ('spam','harassment','inappropriate_content','fake_account','hate_speech','violence','other')
- `status` IN ('pending','reviewed','resolved','dismissed'), default: 'pending'
- Partial index `WHERE status = 'pending'` for admin queues

### 10 — `delete_account_requests`
- `reason` IN ('not_useful','privacy_concerns','too_many_notifications','found_another_app','temporary_break','other')
- `status` IN ('pending','processed')
- Partial index `WHERE status = 'pending'`

### 11 — `app_config`
- Key-value store: `key` (text PK), `value` (JSONB), `updated_at`
- Pre-seeded: `about_us`, `contact_us`, `privacy_policy`, `terms`, `social_links`, `app_version`

### 12 — `user_devices`
- FCM push token storage: `fcm_token` (unique index)
- `device_type` IN ('android','ios')
- One user can have multiple devices

### 13 — `notification_preferences`
- One row per user (`user_id` PK)
- Columns: `follows`, `likes`, `comments`, `mentions`, `messages`, `twin_match`, `push_enabled` (all boolean, default: true)

---

## Views (14_views.sql)

### `v_profile_stats`
- Aggregates profile data with `follower_count` and `following_count` via two LEFT JOINs on the `follows` table
- Calculates `age` from `date_of_birth`
- Groups by `profile.id`

### `v_top_creators`
- Wraps `v_profile_stats`, ordered by `follower_count DESC`
- Used for ranking/discovery

### `v_online_users`
- Joins `profiles` + `user_presence` WHERE `is_online = true`
- Returns: `id`, `username`, `full_name`, `avatar_url`, `last_seen_at`

---

## Functions (15_functions.sql)

### `fn_twin_match(current_user_id uuid)`
- **Language**: SQL, STABLE
- **Purpose**: Find the single best hobby-match for a user (their "twin")
- **Logic**: Joins both users' hobbies, excludes blocked users, counts matching hobbies, returns TOP 1 by match_count
- **Returns**: `id`, `username`, `full_name`, `avatar_url`, `bio`, `location`, `is_verified`, `match_count`

### `fn_nearby_users(current_user_id uuid)`
- **Language**: SQL, STABLE
- **Purpose**: Return all hobby-matched users EXCEPT the top twin (for the explore feed)
- **Logic**: CTE with `RANK()` window function, filters out rank=1 (the twin), returns rest ordered by match_count
- **Returns**: Same columns as fn_twin_match

### `fn_search_users(current_user_id uuid, query_text text default '', hobby_category text default null)`
- **Language**: SQL, STABLE
- **Purpose**: Search users by name/username/bio, optionally filtered by hobby category
- **Logic**: ILIKE search on `full_name`, `username`, `bio`; optional category filter; excludes blocked users; orders by `follower_count DESC`
- **Returns**: `id`, `username`, `full_name`, `avatar_url`, `bio`, `location`, `is_verified`, `follower_count`

---

## Triggers

**None defined.** Zero triggers exist across all 15 files.

---

## RLS Policies

**None defined.** Zero Row-Level Security policies exist across all 15 files.

---

## Overall Quality Rating: 7 / 10

### What's Good
- Clean, logical schema with clear table responsibilities
- All foreign keys have CASCADE deletes — no orphan data
- Smart partial indexes (unread messages, pending reports, online users)
- Self-reference guards on every bidirectional table (no_self_follow, no_self_block, no_self_conversation)
- Thoughtful check constraints on all enum-like text fields
- Good use of compound indexes for common query patterns
- Three well-written core functions covering the main discovery features
- Partial unique index for "one primary hobby per user" — elegant design

---

## Issues & Gaps

### CRITICAL

| # | Issue | Table | Detail |
|---|-------|-------|--------|
| 1 | **No RLS policies** | ALL | Any authenticated user can read any row. Messages, blocks, notifications — all exposed. Must implement before going live. |

### Important

| # | Issue | Table | Detail |
|---|-------|-------|--------|
| 2 | **Polymorphic FK (no integrity)** | `notifications`, `reports` | `entity_id` references 'reel', 'comment', or 'profile' depending on `entity_type` — but no FK enforces this. The reel and comment tables don't even exist yet. |
| 3 | **Bidirectional conversation flaw** | `conversations` | Unique constraint is on `(user1_id, user2_id)` — but user A→B and user B→A are treated as different conversations. Should enforce `min(id, id)` ordering or use a different approach. |
| 4 | **Missing tables referenced in schema** | — | `notifications` and `reports` reference entity types `reel` and `comment`, but no `reels` or `comments` table exists. Similarly no `likes` table despite 'like' being a notification type. |

### Minor

| # | Issue | Detail |
|---|-------|--------|
| 5 | **No triggers for updated_at** | `profiles`, `user_devices` have `updated_at` but nothing auto-updates them — must be done in app code |
| 6 | **No block side-effects** | Blocking a user doesn't affect existing follows or conversations — no trigger or cascade handles this |
| 7 | **Text enums instead of ENUM types** | All enum-like fields use `text + CHECK`. PostgreSQL native ENUM types are more efficient and type-safe |
| 8 | **No email validation** | `profiles.email` has no format CHECK constraint |
| 9 | **DISTINCT + GROUP BY redundancy** | `fn_search_users` uses both — one is redundant |
| 10 | **Block subquery performance** | All three functions check blocks via EXISTS subqueries per row — better to use LEFT JOIN / CTE |
| 11 | **No soft deletes** | Reports and blocks are hard-deleted — no audit trail for compliance or moderation review |

---

## RLS Policies Needed (reference guide, not yet implemented)

```
profiles        → SELECT: public profiles visible to all; private/followers_only require auth
messages        → SELECT: only sender or conversation participant
conversations   → SELECT: only user1_id or user2_id
notifications   → SELECT/UPDATE: only recipient_id
blocks          → SELECT: only blocker_id
reports         → SELECT: only reporter_id
user_presence   → SELECT: all authenticated users (for online status)
notification_preferences → SELECT/UPDATE: only user_id
user_devices    → SELECT/UPDATE/DELETE: only user_id
delete_account_requests → INSERT: authenticated; SELECT: only user_id
app_config      → SELECT: all (public read-only config)
```

---

## Missing Tables (for full feature coverage)

| Table | Needed For |
|-------|-----------|
| `reels` | notifications, reports entity_type='reel' |
| `comments` | notifications, reports entity_type='comment' |
| `likes` | notifications type='like' |
| `reel_views` | analytics/metrics |
