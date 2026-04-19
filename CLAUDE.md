# Likewise — Claude Context

Flutter social app. Users share short videos ("waves") and match by hobbies/location. Supabase backend, BunnyCDN for media, Riverpod state, go_router nav.

## Stack
- Flutter 3.10+, Dart, Riverpod (`flutter_riverpod: ^3.2.1`), go_router, Supabase
- Media: BunnyCDN (storage + stream), `cached_network_image`, `image_picker`, `image_cropper` (UCrop/iOS native), `flutter_image_compress`
- Location: `geolocator`, `geocoding`
- Google sign-in, Firebase Messaging (not yet wired into `user_devices`)

## Directory map
```
lib/
  core/
    bunny_config.dart          — BunnyPaths + CustomAvatars constants
    models/                    — Profile, ProfileStats, UserHobby, AppNotification, …
    services/                  — AuthService, ProfileService, AccountService, NotificationService, …
    providers/                 — auth_providers, profile_providers, navigation_providers, …
    utils/avatar_cropper.dart  — shared crop helper
  ui/
    screens/
      auth/                    — auth_screen, complete_profile_screen (5-step), forgot_password
      settings/                — settings_screen, delete_account, notifications_settings,
                                 change_password_sheet, report_problem_sheet
      profile/                 — profile_screen, user_profile_screen, edit_profile_screen
      messages/ explore/ waves/ notifications/ social/
    widgets/                   — app_drawer, profile_completion_banner, custom_avatar_picker,
                                 avatar_popup, app_cached_image, …
  router.dart                  — GoRouter + redirect logic
likewise/supabase/*.sql        — schema source of truth (per-table files)
database/schema.sql            — flattened reference (context only, not runnable)
```

## Key patterns & gotchas

### Two profile providers — invalidate BOTH on profile/avatar change
- `fullProfileProvider` → `profiles` table direct → used by forms & completion banner
- `currentProfileProvider` → `v_profile_stats` view → used by app drawer, explore header, own profile screen header
- **Any avatar/profile update must invalidate both** or the drawer/explore stay stale until app restart.

### Avatars
- Column: `profiles.avatar_url` (single source of truth for both uploaded and custom)
- **Uploaded:** `https://likewise.b-cdn.net/likewise/avatars/<userId>_<timestamp>.jpg` — timestamped filename bypasses CDN cache on re-upload. Cropped via `image_cropper` (square, rotate). Compressed via `flutter_image_compress` before upload.
- **Custom:** 20 DiceBear "thumbs" PNGs at `https://likewise.b-cdn.net/likewise/avatars/thumbs/01.png` → `20.png`. Helper: `CustomAvatars.urlForIndex(i)` / `.isCustom(url)` in `bunny_config.dart`.
- Edit flow UX: tap avatar → bottom sheet with Gallery / Camera / Pick Custom / Remove
- Fullscreen popup viewer: `showAvatarPopup(context, url)` from `widgets/avatar_popup.dart` — pinch-to-zoom, tap to dismiss

### App drawer
- Owned by `MainScreen`'s Scaffold (not any tab screen) via `mainScaffoldKeyProvider`. Inner screens open it with `ref.read(mainScaffoldKeyProvider).currentState?.openDrawer()`. This places the drawer above the banner + bottom nav bar.
- Items: 4 tabs + Settings + Report a Problem + Logout. Kept intentionally lean.

### Profile completion banner
- `widgets/profile_completion_banner.dart` — 2 widgets: `ProfileCompletionCard` (inline on profile) + `ProfileCompletionBanner` (dismissible overlay on home tab)
- Tracks **5 fields** (20% each): bio, gender, date_of_birth, location, hobbies. Avatar excluded — everyone has either an uploaded or picked avatar.
- **Must wait for BOTH** `fullProfileProvider` AND `userHobbiesProvider` to have values before rendering — otherwise flashes briefly while hobbies load.

### Complete Profile flow (`/complete-profile`)
- 5 steps: (0) name + username, (1) avatar + bio, (2) gender + DOB, (3) location, (4) hobbies + primary
- Used for both first-time registration AND re-entry in edit mode — pre-fills all steps from existing profile. `_editMode` flag flips behavior: empty optional fields are explicitly nulled on submit (vs. first-time which only writes what's filled).
- Router no longer bounces authenticated users away from this route — they can re-enter anytime.
- Avatar step has two paths: "Tap to choose a photo" (gallery + crop) OR "Or pick a custom avatar" (thumbs picker).

### Settings
Fully implemented: Theme, Online Status toggle, Who Can Message Me, Profile Visibility, Blocked Users, Change Password (re-auth + `supabase.auth.updateUser`), Notifications (→ `/notifications-settings`, 7 toggles on `notification_preferences`), Report a Problem (sheet → `reports` table), Delete Account (→ `/delete-account`, insert into `delete_account_requests`), About, Log Out, Delete Account.

Email change is intentionally omitted per product decision.

### Reports table workaround
"Report a Problem" sheet uses `reported_entity_type='profile'` with `reported_entity_id=<reporter's userId>` + a `[Type]` prefix in description. The CHECK constraint doesn't yet include `'app'`. To upgrade later:
```sql
ALTER TABLE public.reports
  DROP CONSTRAINT reports_reported_entity_type_check,
  ADD CONSTRAINT reports_reported_entity_type_check
  CHECK (reported_entity_type IN ('profile','reel','comment','message','app'));
```

### Edit Profile gender
Uses chip picker with 5 options (Male, Female, Non-binary, Other, Prefer not to say). Stored as `null` when unselected. The old dropdown was missing `Non-binary` and would crash if a user had picked that in the multi-step flow.

## Implemented features (~70%)
`profiles`, `follows`, `hobbies`/`user_hobbies`, `conversations` (request→active only), `messages` (send/read/reply/reactions/realtime), `blocks`, `reports`, `user_presence`, `notification_preferences`, `delete_account_requests`, `waves` (upload + admin approval pipeline — admin panel is `../admin_likewise`).

## Not yet implemented
- `user_devices` + FCM push token registration (Firebase Messaging dep is installed, not wired)
- `conversations.status = 'declined'` (decline action in message requests)
- `messages.is_delivered` never written
- Notifications beyond `follow` type (`like`/`comment`/`mention`/`twin` missing)
- `message_deletions` table unused (hard-delete only)
- `app_config` table unused
- Reels / likes / comments — no tables exist; profile screens show placeholder
- `profiles.is_verified` display only, no verification flow

## Conventions when working in this repo
- Don't create new `.md` files unless asked.
- Don't add new comments unless the *why* is non-obvious. Avoid narrating what code does.
- When editing avatar logic: invalidate both `fullProfileProvider` AND `currentProfileProvider`.
- Flutter analyze should be clean on touched files. Known pre-existing warnings in `complete_profile_screen.dart` (lines ~1024, 1255) and `edit_profile_screen.dart` (~line 182) and `router.dart` (~line 46) are fine to leave.
- Prefer `Edit` over `Write` for existing files. Prefer bottom sheets over full screens for small flows (matches existing pattern).
- Schema lives in `likewise/supabase/*.sql` — if a change is truly needed, add a new numbered file and ask before applying.
