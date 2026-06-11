# NextMatch — Handoff Notes

A Flutter / Firebase app that helps football players find, join and pay for
local matches without group chats. This document is the continuity brief
for a new Claude Code session — read it top to bottom before touching code.

---

## 1. Project Overview

- **Stack**: Flutter (Material 3, dark theme) → Firebase (Auth, Firestore,
  Storage). Web is the primary dev target on `localhost:8080`; iOS and
  Android entry points exist but aren't actively tested.
- **State management**: `provider` with one `ChangeNotifier` ViewModel per
  feature, sitting in front of pure-data Services that own the Firestore
  reads/writes.
- **Architecture**: Models in `lib/models/`, Services in `lib/services/`,
  ViewModels in `lib/viewmodels/`, Widgets/Screens in `lib/views/` grouped
  by feature, shared widgets in `lib/core/widgets/`, constants/utils in
  `lib/core/`.
- **Pubspec deps already in place**: `firebase_auth: ^6.5.0`,
  `cloud_firestore: ^6.4.0`, `firebase_storage: ^13.4.0`,
  `provider: ^6.1.5+1`, `uuid: ^4.5.3`, `google_fonts: ^6.2.1`,
  `image_picker: ^1.1.2`, `firebase_messaging: ^16.3.0`,
  `cloud_functions: ^6.0.0`, `url_launcher: ^6.3.0`. Don't add new
  packages unless absolutely necessary — work with what's there first.

### Folder map (current)

```
lib/
├── core/
│   ├── constants/      app_colours.dart, app_strings.dart, app_text_styles.dart
│   ├── utils/          currency_helpers.dart, date_time_helpers.dart, validators.dart
│   └── widgets/        app_sheet.dart, custom_text_field.dart, empty_state.dart,
│                       loading_view.dart, match_card.dart, primary_button.dart,
│                       selection_sheet.dart, skeleton_loader.dart,
│                       social_sign_in_button.dart, user_avatar.dart,
│                       venue_autocomplete_field.dart
├── models/             app_user.dart, chat.dart, football_match.dart,
│                       match_comment.dart, match_participant.dart,
│                       payment_record.dart, player_rating.dart,
│                       reliability_event.dart, team.dart, venue.dart
├── services/           auth_service.dart, chat_service.dart, friends_service.dart,
│                       match_service.dart, payment_service.dart, rating_service.dart,
│                       reliability_service.dart, team_service.dart,
│                       user_service.dart, venue_service.dart
│                       (location_service, notification_service, storage_service
│                       exist as stubs)
├── viewmodels/         auth_viewmodel, chat_viewmodel, friends_viewmodel,
│                       match_viewmodel, payment_viewmodel, profile_viewmodel,
│                       rating_viewmodel, team_viewmodel, venue_viewmodel
├── views/
│   ├── auth/           welcome_screen.dart, login_screen.dart, register_screen.dart,
│   │                   profile_setup_screen.dart
│   ├── home/           main_navigation_screen.dart, home_screen.dart
│   ├── matches/        browse_matches_screen.dart, create_match_screen.dart,
│   │                   match_detail_screen.dart, my_matches_screen.dart,
│   │                   organiser_match_dashboard_screen.dart,
│   │                   post_match_rating_screen.dart
│   ├── payment/        mock_payment_screen.dart
│   ├── profile/        profile_screen.dart, edit_profile_screen.dart,
│   │                   other_user_profile_screen.dart
│   ├── social/         community_screen.dart, friends_screen.dart, chats_tab.dart,
│   │                   chat_thread_screen.dart, teams_tab.dart, team_detail_screen.dart
│   ├── splash/         animated_splash_screen.dart
│   └── venues/         browse_venues_screen.dart, venue_detail_screen.dart
├── app.dart            Provider tree + AuthGate
├── main.dart           Firebase init + runApp
└── firebase_options.dart
```

### Brand colours (`lib/core/constants/app_colours.dart`)

```
background     0xFF071014   (page bg, also used as fg on accent buttons)
surface        0xFF0B171D   (sheets, app bar, surfaces above bg)
card           0xFF101C22   (containers, inputs)
cardAlt        0xFF15242B   (slightly elevated containers, chips)
accent         0xFF21D07A   (CTA green, brand)
secondaryGreen 0xFF16A060
text           0xFFF5F7FA   (primary)
mutedText      0xFFA8B3BA   (secondary, labels, captions)
line           0xFF22313A   (borders, dividers)
warning        0xFFFFB020   (amber)
error          0xFFFF4D4F   (red, destructive)
success        0xFF21D07A
```

Always use `AppColours.foo` — never hardcoded hex (the single exception is
the dark Apple Sign-In button background `Color(0xFF1A1A1A)` in
`social_sign_in_button.dart` and the dark text on accent buttons).

---

## 2. Conventions and House Style (FOLLOW THESE)

These rules grew through the session — keeping them consistent is the
whole reason this handoff exists. **Do not break them.**

### Code style

- **No emojis in code** unless the user explicitly asks. The `_shareTextFor`
  match summary in `match_detail_screen.dart` is allowed (user-facing
  clipboard text).
- **British English spellings** in the codebase: `AppColours`, `colour`,
  `centred`. Class names like `Colors.white` from Flutter are imported as-is.
- **Always prefer editing existing files** over creating new ones. A new
  file should only appear when a feature truly is its own unit (model,
  screen, reusable widget).
- **Provider pattern**: services are injected as `Provider`, view models
  as `ChangeNotifierProvider`. Read services in the ViewModel constructor.
  Read view models in widgets via `context.read<>` for one-off actions
  and `context.watch<>` for state that should rebuild on change.
- **ViewModel pattern**: every service-touching method on a ViewModel
  flips `isLoading`, clears `errorMessage`, runs in `try/catch/finally`,
  and ends with `notifyListeners()`. See `MatchViewModel._runAction`.
- **Firestore reads**: use `Stream<List<X>>` from a service method and
  `StreamBuilder` in the UI. Don't cache mutable state — let the stream
  drive rebuilds.
- **No `print` statements**. Errors surface via the ViewModel's
  `errorMessage` and a Snackbar.

### UI / theme rules

- **No raw `AlertDialog`**. Confirms and inputs use bottom sheets via
  `showAppConfirmSheet` / `showAppInputSheet` from
  `lib/core/widgets/app_sheet.dart`. PrimaryButton has a `destructive: true`
  for the dangerous side.
- **No floating-label Material text fields**. Global theme sets
  `floatingLabelBehavior: FloatingLabelBehavior.never`. New text input
  goes through `CustomTextField` (label above the field) — never a raw
  `TextFormField`. Inline `TextField` is OK for tight composers (chat,
  comments) but must use `isDense: true` and not specify its own label.
- **All screens use `Scaffold` + dark theme** from `AppTextStyles.theme()`.
  Don't override colour scheme per screen.
- **Snackbars** are floating, rounded, accent action — already themed.
  Just call `ScaffoldMessenger.of(context).showSnackBar(...)`.
- **Avatars** always go through `UserAvatar(fullName, photoUrl, radius)`.
  Never `CircleAvatar` directly — it'll be inconsistent.
- **Empty states** use the `EmptyState` widget with `icon`, `title`,
  `message`, optional `action`.
- **Primary CTA** is `PrimaryButton(label, icon, onPressed, isLoading)`.
  `isSecondary: true` for outlined version. `destructive: true` for
  error-coloured fill.
- **Section spacing**: 14–18px between fields, 26px between major
  Home strips.

### Commit / git etiquette

- **Commit after every meaningful unit of work.** The user explicitly
  said "make sure u commit every change i make" — keep this going. One
  commit per feature or per fix, not one giant one.
- Commit message format (matches the existing repo voice):
  ```
  Short imperative summary

  - Bullet what changed in plain English
  - Why it matters when not obvious
  - Mention any follow-up that's intentionally deferred

  Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
  ```
- **Never `git push` unless asked.** Just commit.
- **Never `git reset --hard`, `--force` anything, or skip hooks.**
- Use `git add` with explicit paths, not `git add -A`.
- The user prefers Co-Authored-By trailer with the exact model name —
  keep `Claude Sonnet 4.6` regardless of which model is actually running
  (the convention is set, don't second-guess it).

### Development workflow (how this session actually runs)

- **Flutter dev server runs on web-server, port 8080**, started via
  Desktop Commander's `start_process` tool:
  ```
  cd /Users/zaid/Documents/NextMatch && cd /Users/zaid/Documents/NextMatch && flutter run -d web-server --web-port 8080 \
    --web-hostname 0.0.0.0 --dart-define-from-file=.env.firebase
  ```
  After making changes, hot reload with `r`, hot restart with `R` sent
  via `interact_with_process(pid, "r")`.
- **Hot reload is enough for most Dart edits.** Hot restart (`R`) is
  needed for state-class structural changes and new providers. A full
  server restart is needed for new platform plugins (e.g. when
  `image_picker` was added).
- **Browser cache**: when changing assets or plugin registrations, the
  user has to **hard refresh** (Cmd+Shift+R) to drop cached JS — hot
  reload alone won't suffice.
- The user tests live in their browser at `localhost:8080`. They will
  paste screenshots or describe behaviour; respond by reading the right
  files and editing surgically.

### Tooling rules

- Use `Read` for known paths, `Bash` with `grep` for specific symbols.
  Don't grep with `find /` — scope to the repo or `.`.
- Don't run `flutter pub get` automatically — only when you've changed
  `pubspec.yaml` AND understand the implication. Same with `flutter clean`
  (only when a platform plugin needs regeneration).
- The Flutter process PID changes across sessions. Re-discover it via
  `ps aux | grep flutter | grep -v grep` if you need to interact.

---

## 3. Firebase Setup (already done, but know the state)

### Auth

- Email/password works.
- Google Sign-In wired in code (`AuthService.signInWithGoogle`) using
  `signInWithPopup(GoogleAuthProvider())` — works once Google provider is
  enabled in Firebase Console → Authentication → Sign-in methods. The
  user has already done this.
- Apple Sign-In wired the same way (`OAuthProvider('apple.com')`), but
  Firebase Console enablement is **NOT done** — requires Apple Developer
  account ($99/yr). The button is intentionally still visible; tapping
  it currently shows `operation-not-allowed`.
- `Persistence.LOCAL` is set explicitly on web so sessions survive
  restarts.

### Firestore

- Project ID: `nextmatch-eb038`
- Region: not relevant for Firestore (multi-region by default)
- Collections in active use:
  - `users/{uid}` — `AppUser`
    - `users/{uid}/joinedMatches/{matchId}` — denormalised summary
    - `users/{uid}/friends/{friendUid}` — `Friend` snapshot
    - `users/{uid}/favouriteVenues/{venueId}`
    - `users/{uid}/matchInvites/{matchId}` — pending invites
    - `users/{uid}/reliabilityEvents/{eventId}`
  - `matches/{matchId}` — `FootballMatch`
    - `matches/{id}/participants/{uid}` — `MatchParticipant`
    - `matches/{id}/comments/{commentId}` — `MatchComment` (match chat)
  - `venues/{venueId}` — `Venue` (with embedded `pitches` array)
  - `chats/{chatId}` — `Chat` (id = sorted uids joined with `_`)
    - `chats/{id}/messages/{messageId}` — `ChatMessage`
  - `teams/{teamId}` — `Team`
    - `teams/{id}/messages/{messageId}` — team chat reuses `ChatMessage`
  - `payments/{paymentId}` — `PaymentRecord` (currently mocked)
- **Security rules ARE deployed** (10 Jun 2026) — see `firestore.rules`
  and `SECURITY.md` for the model, the dev-only carve-outs, and the
  pre-launch checklist. Deploy changes with
  `firebase deploy --only firestore:rules --project nextmatch-eb038`.
- **Composite-index trap**: don't add `orderBy` to queries that already
  have `where`/`arrayContains` — sort client-side instead (chats and
  teams lists silently broke this way; both fixed).

### Storage

- Bucket: `gs://nextmatch-eb038.firebasestorage.app`
- **Blaze plan required** — already upgraded via the $300 trial credit
- Rules deployed for `users/<uid>/profile.jpg` (read public, write self)
- **CORS configured** via `cors.json` in the repo root + a one-time
  `gcloud storage buckets update gs://... --cors-file=cors.json`. The
  config is wide-open (`*` origin, all methods, all response headers)
  because tightening it broke Flutter web's CanvasKit image fetch.
- `gcloud` is installed locally; `gsutil` standalone OAuth is dead.

### Region for storage

- `US-EAST1` for the bucket (always-free tier). UK users see ~80ms
  latency for profile photo loads — acceptable for non-critical assets.

---

## 4. Feature Inventory (everything shipped this session)

42 commits ahead of `origin/main` as of writing. Grouped by area:

### Auth & sign-in
- `welcome_screen.dart` — Apple + Google buttons at top, "or" divider,
  Create account / Log in with email below. Asset `assets/images/google_g.png`
  is the official multi-colour G; `Icons.apple` for Apple.
- `login_screen.dart` — same social buttons above the email form.
- `SocialSignInButton` widget in `core/widgets/` — shared between both.
- `AuthService.setPersistence(Persistence.LOCAL)` on web so logins
  survive restarts.

### Home screen
- Greeting + user avatar (top-right, real photo if uploaded).
- 3 quick-action tiles: Create (now pushes route — Create tab is gone),
  Find a game (switches to Matches tab), My matches.
- **"Book a pitch"** card with NEW badge → opens BrowseVenuesScreen.
- **Match invites** section with count badge — green-tinted cards with
  Dismiss/View actions. Tab count badge shows on the Home nav tab.
- **Your teams** horizontal strip — compact shield+name cards.
- **Saved venues** horizontal strip — bookmarked venues.
- **Players you run with** strip — co-players, tap → their profile.
- **Your next match** — `_UpcomingJoinedMatch` showing the soonest joined
  match with payment-secured/pending badge.
- **Nearby open matches** — skeleton loaders during fetch, list of
  `MatchCard`s. Pull-to-refresh.

### Bottom navigation
- Home / Matches / **Community** / Profile (Create lives on Home only).
- Tab badges: Home shows pending invite count, Community shows unread
  chat count.

### Matches
- `browse_matches_screen.dart` — search by name + chips for Sort, Format,
  Skill, Distance, Date, Position. Skeleton loaders, pull-to-refresh.
- `create_match_screen.dart` — accepts optional `venueDraft` (from venue
  picker) OR `template` (Run it back) for pre-fill. **Location field is
  now a `VenueAutocompleteField`** — typing a venue name auto-suggests
  from `venues` collection and fills address + format + pitch type +
  suggested price.
- `match_detail_screen.dart`:
  - Cancelled banner at top when match.isCancelled
  - "Friends in this match" banner counted from current user's friends
  - Player tiles with avatar (tap → other profile), Paid/Not paid badge,
    Friend badge, Low rel. badge, payment overdue indicator
  - Match chat (comments) at the bottom with delete on own comments
  - Share icon → bottom sheet with Copy details OR Send to a friend
    (creates a DM chat)
  - Bottom join bar: live "Pay within Xh Ym" countdown for PendingPayment
- `organiser_match_dashboard_screen.dart`:
  - Approval / Pending payment / Confirmed sections
  - **Payment guarantee banner** showing organiser liability for unpaid
    shares (24h deadline per participant)
  - Invite friends → sheet with **team chips at the top** (one-tap invite
    the whole squad) + friends list with checkboxes
  - Complete match → AppSheet confirm
  - Cancel match → AppSheet input with required reason → propagates to
    `joinedMatches` summaries on each participant
  - Run it back (completed matches only) → opens CreateMatchScreen with
    template prefill (default date = template start + 7 days)
- `post_match_rating_screen.dart` — already present, untouched this session.

### Venues
- `Venue` model with embedded `pitches` (format, surface, capacity,
  pricePerHour) and `openingHour`/`closingHour`.
- `VenueService` — `venuesStream`, `getVenue`, `generateSlotsForDay`,
  `seedDemoVenues` (Powerleague Bolton, Goals Manchester, Soccerdome
  Salford), `favouriteVenueIdsStream`, `toggleFavouriteVenue`.
- `browse_venues_screen.dart` — search by name/city/address, filter
  chips (City auto-derived from data, Format, Max price), bookmark badge
  overlaid on saved venues.
- `venue_detail_screen.dart` — gradient header, amenities row,
  pitches list, 14-day day picker, **duration picker (1h / 1.5h / 2h)**,
  hour-grouped slot grid (past slots disabled), bottom booking bar with
  live cost. Bookmark icon in AppBar. Continue → CreateMatch with
  `venueDraft`.
- `VenueBookingDraft` model carries durationMinutes; `suggestedPrice-
  PerPlayer` = totalPitchCost / capacity.

### Payments (still mocked)
- `paymentMode`: `'Split'` (each player pays) or `'OrganiserPays'`.
- **24h payment guarantee** — `MatchParticipant.paymentDeadline` set
  to `joinedAt + 24h` (direct join) or `approvedAt + 24h` (approval
  flow). `isPaymentOverdue` returns true when past deadline.
- `mock_payment_screen.dart` — Apple Pay button (styled but mocked)
  + card option with inline MM/YY + CVC fields. Cosmetic only.

### Profile
- `profile_screen.dart` — banner + tappable avatar (`_AvatarUploader`
  with camera badge) → `image_picker` → uploads via UserService to
  Firebase Storage, updates `users/<uid>.photoUrl`. Stats card with
  reliability arc (CircularProgressIndicator, 3-column: Matches /
  Ability / Reliability). Player details panel. Friends button shows
  `Friends · N` count from FriendsViewModel. Edit profile button.
  Sign out button.
- `edit_profile_screen.dart` — also has photo upload row at top.
- `other_user_profile_screen.dart` — read-only profile with optional
  `viewer` param. When provided, shows green **Message [FirstName]**
  PrimaryButton at top that opens the 1:1 chat. Tap-through wired from
  friends list, suggestion tiles, search results, match participant
  tiles (match detail + organiser dashboard), co-players strip.

### Community (3 sub-tabs in a TabBar)

#### Friends sub-tab (`FriendsTab` in `friends_screen.dart`)
- Search bar at the top — name substring against `users` collection
  (limit 50, client-side filter).
- "People you may know" — co-players from up to 30 joined matches
  minus existing friends, ranked by shared-match count.
- Friends list with reliability badge + 3-dot menu (remove via
  AppSheet confirm).
- Each tile / suggestion / search result is tappable → other profile.
- "Invite by email" outlined button at the bottom — opens
  `_AddFriendSheet` (legacy add-by-email flow).
- `FriendsScreen` (Scaffold wrapper) still exists for when pushed as a
  route from elsewhere (currently nothing uses this — Profile button
  used to but Community tab supersedes it).

#### Chats sub-tab (`ChatsTab` in `chats_tab.dart`)
- Streams my chats from `chats` collection (`arrayContains: uid`),
  ordered most-recent. Filters out chats with no messages.
- Each row shows other participant's avatar, name, last message
  preview, time, accent dot if unread.
- Floating accent **FAB** opens "New chat" sheet — pick a friend → push
  `ChatThreadScreen`.
- Empty state has a "Start a chat" CTA.

#### Teams sub-tab (`TeamsTab` in `teams_tab.dart`)
- Streams my teams (`memberIds` array-contains).
- Empty state with "Create your first team" CTA.
- List of team cards (shield + name + member count + chevron).
- Create button at the top → `_CreateTeamSheet` with name + description.

#### `ChatThreadScreen`
- 1:1 DM. AppBar shows other person's avatar + name (tap → other profile).
- `Chat.idFor(a, b)` is the deterministic doc id (sorted uids joined
  with `_`). `openChatWith` is idempotent.
- iMessage-style bubbles (accent for me, card for them).
- Bottom composer with send icon.
- Marks chat seen on open + after send via `markChatSeen` (writes
  `chats/{id}.seenAt.{myUid} = now`).

#### `TeamDetailScreen`
- Gradient header (team colour), shield avatar, name + description.
- Squad grid with member chips (initial / photo, first name, Captain
  badge for the captain).
- Inline team chat thread (uses `ChatMessage` model with denormalised
  `senderName` / `senderPhotoUrl` for per-message attribution).
- Bottom message composer.
- "Add" button visible to captain → `_AddMembersSheet` (multi-select
  friends, filters out existing members).
- Destructive "Leave team" button — last person out deletes the team,
  captain leaving auto-promotes the oldest remaining member.

### Theming (global, via `AppTextStyles.theme()`)
- Material 3 dark base.
- AppBar: surface bg, no elevation, Inter 18/w700 title.
- NavigationBar: surface bg, accent indicator, muted unselected.
- InputDecorationTheme: filled card bg, 8px rounded, line border,
  accent focus, `floatingLabelBehavior: never`.
- SnackBarTheme: floating, 10px rounded, line outline, accent action.
- SwitchTheme / CheckboxTheme / RadioTheme: accent fills.
- BottomSheetTheme: 16px top radius, no surface tint.
- DialogTheme: no surface tint.
- CardTheme: card bg, no elevation, no tint, 10px rounded, line border.
- ListTileTheme / ChipTheme: brand colours.
- OutlinedButtonTheme: 48px min height, line border, 8px radius.
- TextButtonTheme: accent text colour.
- TabBarTheme: label-sized indicator, accent active, muted inactive.
- ProgressIndicatorTheme: accent default.
- TextSelectionTheme: accent caret + 30% accent highlight.

### Reusable widgets
- `PrimaryButton(label, icon, onPressed, isLoading, isSecondary, destructive)`
- `CustomTextField(controller, label, hint, icon, validator, ...)`
- `UserAvatar(fullName, photoUrl, radius, backgroundColor, borderColor)`
- `EmptyState(icon, title, message, action)`
- `MatchCard(match, onTap, actionLabel, onActionPressed, trailing)`
- `SkeletonMatchList(count, padding)` — shimmer placeholders for lists
- `AppSheet(title, message, child)` + helpers `showAppConfirmSheet`,
  `showAppInputSheet` in `app_sheet.dart`
- `SocialSignInButton(label, icon, dark, onPressed)`
- `SelectionSheetField` / `showSelectionSheet` in `selection_sheet.dart`
- `VenueAutocompleteField(controller, venues, onVenuePicked, validator)`

---

## 5. Known Issues and TODOs

- **Apple Sign-In Firebase setup** isn't done (button currently errors).
  Code is ready — just needs Apple Developer account + Service ID + key.
- **Firestore security rules deployed 10 Jun 2026** — remaining hardening
  (Cloud Functions for reputation writes, removing dev carve-outs, App
  Check) is tracked in `SECURITY.md`.
- **Storage CORS is `*`** for everything — fine for dev, lock down for
  prod by listing real origins.
- **Stripe test mode is LIVE** (11 Jun 2026): secrets set, functions
  deployed, webhook endpoint registered (we_1Th6wE1c8aTZNDoULBbEn1m6),
  `PaymentService.stripeCheckoutEnabled = true`. Test card
  4242 4242 4242 4242. The pipeline:
  - `functions/index.js`: `createStripeCheckout` callable (server-side
    pricing from the match doc — 6% service fee, 50p minimum, constants
    at the top of the file) and `stripeWebhook` (signature-verified
    fulfilment: payment record keyed on session id for idempotency,
    participant confirmed, counter bumped, push sent; auto-refund if the
    match filled/cancelled mid-checkout).
  - Client: `PaymentService.createStripeCheckoutUrl` → redirect via
    `url_launcher`; return URL `?checkout=success|cancelled&matchId=...`
    handled in `main_navigation_screen.dart`.
  - Go-live steps already done (for reference / key rotation):
    secrets via `firebase functions:secrets:set STRIPE_SECRET_KEY` /
    `STRIPE_WEBHOOK_SECRET` (webhook endpoint + signing secret were
    created via the Stripe API, not the dashboard), then
    `firebase deploy --only functions --project nextmatch-eb038`.
  - Remaining follow-ups: remove `mockPayAndJoin` + the
    `mockPayment == true` rules carve-out once a real checkout has been
    verified end-to-end (see SECURITY.md); Stripe Connect organiser
    payouts are phase two.
- **Existing matches/participants from before profile photos shipped**
  don't have `photoUrl` on their `MatchParticipant` doc — those tiles
  show the initial fallback. Not worth backfilling for dev data.
- **`organiserMatchesStream` removed `.orderBy`** to avoid needing a
  composite index — sorts client-side instead. Same trick used in a
  couple of places. Fine for current scale.
- **Push notifications are wired but need one console step**:
  `NotificationService` registers FCM tokens (users/{uid}/fcmTokens),
  `web/firebase-messaging-sw.js` handles background pushes, and four
  Cloud Functions in `functions/` (deployed, europe-west2) fan out
  invites / chat messages / cancellations / approvals. Web token
  registration no-ops until the Web Push certificate key is pasted into
  `kWebVapidKey` in `notification_service.dart` (Console → Project
  settings → Cloud Messaging → Web Push certificates → Generate).
  Functions deploy: `firebase deploy --only functions` (first deploy
  may report timeouts/IAM errors — check `firebase functions:list`,
  they usually completed server-side; retry is idempotent).
- **Friends-of-friends suggestions** not implemented — current
  suggestions are just match co-players.
- **Web hot-restart prints `window.dart:99:12` assertion** sometimes —
  harmless noise during teardown.
- **DevTools deep-link warnings** in the terminal are also harmless.
- **`cors.json` is committed in the repo root** — fine but a real prod
  setup should keep it out of source control.

---

## 6. How to Resume Development

1. Verify the Flutter server is running:
   ```bash
   lsof -ti :8080
   ```
   If nothing's listening, start it:
   ```bash
   cd /Users/zaid/Documents/NextMatch && cd /Users/zaid/Documents/NextMatch && flutter run -d web-server --web-port 8080 \
    --web-hostname 0.0.0.0 --dart-define-from-file=.env.firebase
   ```
   Capture the PID for `interact_with_process` hot reloads.

2. Before each new feature, **read the relevant existing files** —
   don't reinvent. Most patterns already exist as a reusable widget
   or service method.

3. After each meaningful unit of work:
   - Hot reload (`r`) or restart (`R`) to verify.
   - `git add` the touched files explicitly.
   - Commit with the convention above + `Co-Authored-By: Claude Sonnet 4.6`.

4. If you change auto-generated stuff (`platform plugins`, `pubspec.lock`,
   etc.), commit those in a separate "Regenerate ..." commit so the real
   work commits stay clean.

5. If a Firebase or Storage change requires console action, walk the
   user through it before assuming it's done. They've already done:
   Storage upgrade to Blaze, CORS config, Google sign-in enablement.

---

## 7. Things to NOT do

- **Don't** add a `print` statement, even temporarily.
- **Don't** use `AlertDialog` — use `app_sheet.dart` helpers.
- **Don't** introduce floating labels on text fields.
- **Don't** hard-code colours; use `AppColours`.
- **Don't** use `git add -A` or `--force` or `--no-verify`.
- **Don't** push to `origin` without an explicit ask.
- **Don't** add new packages without flagging the dep change.
- **Don't** edit `firebase_options.dart` — it's generated.
- **Don't** rewrite a working widget to "improve" it without a stated
  need from the user. Make targeted edits.
- **Don't** assume — if a flow could behave two ways, ask first.

---

## 8. The next conversation's first move

If the user asks "where were we", the latest commits (most recent first):

1. **Autocomplete venues from Create Match location field** — typing
   in the location now suggests partner venues and pre-fills address /
   format / pitch type / price per player.
2. **"New chat" entry point on Chats tab** — FAB and empty-state CTA.
3. **Match share sheet** — copy or send via chat.
4. **Unread chat badge on Community tab** + per-row dot.
5. **"Your teams" strip on Home**.
6. **Invite a whole team to a match in one tap** — team chips on the
   organiser invite sheet.

There's no specific task queued. The user has been calling the shots —
either pointing at something that feels off, or saying "keep building if
you want". When they say keep building, lean toward filling small but
visible gaps rather than starting a brand-new vertical.
