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
- **Payments**: no client writes at all. Records are created exclusively
  by Cloud Functions after a verified Stripe charge. Readable only by
  payer and organiser.
- **Ratings**: only after match completion, only by an attended player
  about another attended player, never about yourself, value clamped 1–5,
  immutable once written.

## Known-weak by design (acceptable in dev, NOT at launch)

1. ~~Cross-user reputation writes happen client-side.~~ **Closed 12 Jun
   2026.** Reliability scores, reliability events, ability ratings and all
   the counters are now written exclusively by Cloud Functions
   (`onParticipantReputation`, `onRatingCreated`), which react to the
   attendance transitions and rating docs the client legitimately creates.
   The rules deny every client write to those fields, including a user
   writing them onto its own profile doc (`touchesReputation()`), and the
   `reliabilityEvents` / `abilityRatings` subcollections are backend-write
   -only. Verified by direct REST writes with a real ID token: changing
   your own score/counters/ability returns 403, a normal profile edit
   still returns 200.
2. ~~Demo seeding carve-outs.~~ **Removed 11 Jun 2026**: the `demo-*`
   uid and venue-create carve-outs are gone from the rules and the demo
   seed buttons are gone from the app. Venues are backend-managed only.
   Existing demo data in Firestore is untouched and still renders.

## Before money moves (launch checklist)

- [x] Stripe integration where payment records are written by a
      **backend** after a verified charge — built 11 Jun 2026.
      `createStripeCheckout` (callable) prices the charge server-side from
      the match doc; `stripeWebhook` verifies Stripe's signature and writes
      the payment record / confirms the participant with the admin SDK.
      Awaiting test keys (`firebase functions:secrets:set STRIPE_SECRET_KEY`
      + `STRIPE_WEBHOOK_SECRET`), then deploy and flip
      `PaymentService.stripeCheckoutEnabled`.
- [x] Mock payment path removed end to end (11 Jun 2026): rules now deny
      all client writes to `payments`, the app's mock flow is deleted and
      refunds run server-side (full on organiser cancellation or early
      withdrawal, none inside 24h of kick-off).
- [x] Reliability and rating writes moved to Cloud Functions (12 Jun
      2026): `onParticipantReputation` and `onRatingCreated` own every
      score, counter and event; the rules deny all client writes to those
      fields. Penalty tiers are recomputed server-side from kick-off
      timing, so the client's cancel label grants nothing.
- [x] Invite fan-out and cancellation propagation already run in Cloud
      Functions (notification pipeline).
- [x] Remove the two DEV-ONLY rule carve-outs (demo uids, venue create) —
      done 11 Jun 2026, deployed.
- [x] Close the mock-era self-confirmation hole: clients can no longer
      flip their own participant doc to Joined/Confirmed, and 'Joined'
      self-creates plus join counter bumps are only allowed on free or
      organiser-pays matches. Paid spots are confirmed exclusively by the
      Stripe webhook (11 Jun 2026, deployed).
- [x] Stripe checkout return URLs restricted to an origin allowlist
      (localhost dev + the Firebase Hosting domains) — 11 Jun 2026.
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
- Cloud Functions (`functions/`, europe-west2) run with admin
  privileges and handle pushes + Stripe checkout/fulfilment. They remain
  the landing zone for the reputation writes above. `users/{uid}/fcmTokens`
  is owner-only in rules; functions read it via the admin SDK. Stripe
  keys live in Secret Manager (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`),
  never in the repo.
