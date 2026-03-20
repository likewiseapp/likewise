# Likewise – Implementation Audit

> Audit of Flutter code coverage against the Supabase schema.
> ~65% of schema implemented. Last reviewed: 2026-03-20.

---

## ✅ Fully Implemented

| Table | Details |
|---|---|
| `profiles` | All fields — avatar upload (BunnyCDN), location (geolocator), theme preference, profile/message visibility, verified badge display |
| `follows` | Follow/unfollow, follower/following counts, follow notifications created/deleted |
| `hobbies` / `user_hobbies` | Multi-select picker (up to 5), primary hobby flag, sticker wall display on profile |
| `conversations` | `request` → `active` flow, real-time streaming, unread count, message permission enforcement |
| `messages` | Send, read receipts, reply (`reply_to_id`), real-time via Supabase Realtime |
| `message_reactions` | Emoji add/remove, batch fetch, rendered in chat UI |
| `blocks` | Full bidirectional block/unblock, blocked users filtered from explore/messages/chat |
| `reports` | All schema categories supported, duplicate submission check |
| `user_presence` | Online status upsert, `last_seen_at`, toggle in settings |

---

## ⚠️ Partially Implemented

### `conversations.status = 'declined'`
- Schema supports `request`, `active`, `declined`
- Only `request` → `active` (accept) is implemented
- **Missing:** decline/reject action in message requests UI

### `messages.is_delivered`
- Column exists in DB, never written in `sendMessage()`
- Always `null` — no delivery receipt distinction in chat UI
- **Missing:** set `is_delivered = true` after send, show delivery checkmark

### `notifications` — type coverage
- Only `follow` type is implemented end-to-end
- Schema defines: `follow`, `like`, `comment`, `mention`, `twin`
- `entity_id` / `entity_type` are stored but nothing navigates to the entity on tap
- **Missing:** like, comment, mention, twin notification creation and deep-link navigation

### `message_deletions`
- Table exists in schema but entirely unused
- Code migrated to hard deletes; `fetchMyDeletions()` is a stub returning `[]`
- **Missing:** either remove the table or implement soft-delete ("delete for me" vs "delete for everyone")

---

## ❌ Not Implemented At All

### `notification_preferences`
- Entire table ignored — no service methods, no providers, no UI
- Settings screen has no notification toggles
- **Missing:** fetch/update preferences for `follows`, `likes`, `comments`, `mentions`, `messages`, `twin_match`, `push_enabled`

### `user_devices`
- No FCM token registration anywhere
- No `device_type` (android/ios) tracking
- **Missing:** full push notification infrastructure — register token on login, unregister on logout

### `delete_account_requests`
- No account deletion flow exists
- No reason picker, no description input, no status tracking
- **Missing:** delete account screen with reason enum from schema, submission to this table
- ⚠️ Likely required for App Store / Play Store compliance

### `app_config`
- Table completely unused
- **Missing:** config fetch on app start, feature flags, remote config values

### Reels / Likes / Comments
- Schema `notifications` references `entity_type IN ('reel', 'comment', 'profile')` — but no `reels`, `comments`, or `likes` tables exist
- Profile and user_profile screens show "No reels yet" placeholder only
- **Missing:** entire reels feature (upload, feed, likes, comments)

---

## 🔧 Broken / Stub Code

| Location | Issue |
|---|---|
| `settings_screen.dart` | "Change Password" and "Change Email" tiles have empty `onTap: () {}` — no implementation |
| `chat_screen.dart` | `_unblockUser()` method body is incomplete |
| `search_screen.dart` | Radius hardcoded to 500 km — never saved, never user-configurable |
| `notifications_screen.dart` | Auto-marks all notifications as read on screen entry — no per-notification read control |
| `profiles.is_verified` | Displayed in UI (badge) but never set — no verification flow exists |
| `messages.is_delivered` | Column in DB, never written — causes ambiguity between unsent/sent/delivered/read states |

---

## Priority Recommendations

| Priority | Item | Reason |
|---|---|---|
| 🔴 High | `delete_account_requests` | App Store / Play Store requirement |
| 🔴 High | `user_devices` + push notifications | Core engagement feature |
| 🟠 Medium | `notification_preferences` | Table fully modelled, just needs UI + service wiring |
| 🟠 Medium | Conversation decline flow | Bad UX — users can't reject message requests |
| 🟡 Low | `messages.is_delivered` | Already in DB, just needs one line in `sendMessage()` |
| 🟡 Low | Settings stubs (password/email) | Auth flows are straightforward with Supabase |
| 🟡 Low | `app_config` | Low effort, enables remote config without app updates |
| ⚫ Future | Reels / Likes / Comments | Large feature — needs schema additions too |
