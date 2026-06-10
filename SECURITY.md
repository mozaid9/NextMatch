# NextMatch — Security Posture

Last updated: 10 June 2026. This is the working record of what is locked
down, what is deliberately loose during development, and what MUST happen
before real money flows. Read alongside `firestore.rules`.

## What is enforced today (deployed to nextmatch-eb038)

Firestore rules were deployed on 10 June 2026 (previously the database ran
on permissive defaults — any holder of the public web config could read and
rewrite everything, unauthenticated).

- **Authentication required for every read and write.** No anonymous access
  to any collection.
- **Profile identity is owner-only.** Nobody can change another user's
  name, email, photo, bio or positions. Deletes are disabled.
- **Matches** are created with `organiserId == auth.uid`; only the
  organiser can update them freely or delete them. Non-organisers can only
  move the join counter by exactly ±1 with a matching status, or flip
  `isRated` after completion.
- **Participants**: players can only create their *own* entry (uid-keyed),
  only withdraw themselves with a validated status transition, and only
  confirm their own payment from a pending state. Organisers manage
  approvals, rejections and attendance.
- **Private matches** are readable only by the organiser, joined
  participants, and invited users. List queries are forced to constrain to
  public matches (`openMatchesStream` filters `visibility == 'Public'`
  server-side).
- **Chats**: participants only, both the doc and its messages. The
  participant list is immutable after creation. Message sender must be the
  authenticated user; bodies capped at 2,000 chars.
- **Teams**: members only, including team chat.
- **Follow graph**: my `following` list is writable only by me; my entry in
  your `followers` list is writable only by me. No third party can forge a
  follow.
- **Match invites**: only the inviter can write into an invitee's inbox
  (stamped with their uid); only the invitee can dismiss.
- **Payments**: create-only, by the payer, and only while
  `mockPayment == true`. No client can ever update or delete a payment
  record. Readable only by payer and organiser.
- **Ratings**: only after match completion, only by an attended player
  about another attended player, never about yourself, value clamped 1–5,
  immutable once written.

## Known-weak by design (acceptable in dev, NOT at launch)

These are marked `DEV ONLY` / `TODO(Cloud Functions)` in `firestore.rules`:

1. **Cross-user reputation writes happen client-side.** When an organiser
   completes a match, the *client* updates each participant's reliability
   counters and writes reliability events; raters update the rated user's
   ability aggregate. Rules restrict these to an exact field allowlist (so
   identity can't be touched), but a hostile signed-in user could still
   manipulate reliability/rating numbers directly. **Fix before launch:**
   move match completion, reliability events and rating aggregation into
   Cloud Functions; tighten the rules to deny those fields client-side.
2. **Demo seeding carve-outs.** Any signed-in user may create
   `users/demo-*` documents and create venue documents (the "Add demo
   matches/venues" dev buttons). **Fix before launch:** delete both
   carve-outs; venues become admin/backend-managed.
3. **`reliabilityEvents` create is `signedIn()`** for the same reason as
   (1) — needs to be backend-only at launch.

## Before money moves (launch checklist)

- [ ] Stripe (or similar) integration where payment records are written by
      a **backend** (Cloud Function / server) after a verified charge —
      remove the `mockPayment == true` client-create path entirely.
- [ ] Cloud Functions for: match completion bookkeeping, reliability
      events, rating aggregates, invite fan-out, cancellation propagation.
- [ ] Remove the two DEV-ONLY rule carve-outs (demo uids, venue create).
- [ ] **Storage CORS** is currently `*` (see `cors.json`) — restrict to the
      real app origins.
- [ ] **Firebase App Check** on Firestore/Storage to cut off non-app
      clients (the public API key is not a secret; App Check is the control
      for it).
- [ ] Rate limiting / abuse review on chat + comments (consider message
      length caps server-side and a report mechanism).
- [ ] Email enumeration: Firebase Auth "email enumeration protection" is
      recommended in Authentication → Settings.
- [ ] Revisit `users` read access: currently any signed-in user can read
      any profile (needed for search). Consider moving email off the public
      profile doc into a private subdocument.

## Operational notes

- Rules deploy: `firebase deploy --only firestore:rules --project
  nextmatch-eb038` (CLI is authenticated on this machine; `firebase.json`
  carries the `firestore.rules` pointer but is `skip-worktree` by repo
  convention).
- Composite indexes: the codebase deliberately avoids them — list queries
  use a single `where` and sort client-side. If you add `orderBy` to a
  query that already has `where`/`arrayContains`, it will fail with
  FAILED_PRECONDITION at runtime and the stream will silently show an
  empty state (this bit us twice: chats and teams).
- Storage rules: `users/<uid>/profile.jpg` — public read, owner write
  (deployed earlier; unchanged).
