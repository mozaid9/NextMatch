# NextMatch

NextMatch helps football players find, join and pay for local football matches without messy group chats or chasing payments.

## Current MVP

- Flutter app with Firebase Authentication and Cloud Firestore
- Email/password login and registration
- Player profile setup with positions, skill level, town, bio and trust stats
- Home, browse matches, match detail, create match, my matches and profile screens
- Split payment mode where players join the match view first, then mock-pay to secure a slot
- Organiser Pays mode where players join free and owe the organiser
- Joined player tracking, owed amount tracking and payment records
- Reliability score, low-reliability approval requests and organiser dashboard
- Post-match ability ratings for attended players

## Payment Modes

Split:
- Player joins the match view first with `attendanceStatus: PendingPayment`
- Player can review the match details and player list before paying
- `MockPaymentScreen` simulates the future Stripe flow
- Participant is confirmed and counted after successful mock payment

Organiser Pays:
- Player can join without paying in-app
- The app records `paymentStatus: Owed`
- `amountOwed` is written to the user's joined match record

TODO: replace mock payments with Stripe PaymentIntents/Checkout, webhooks and refund handling in Cloud Functions.

## Trust and Ratings

Reliability is separate from ability:

- Reliability score: 0-100, starts at 100
- Labels: Excellent, Good, Risky, Low
- Attendance gives +1, no-shows apply -15, late withdrawals apply stronger penalties
- Low reliability players can require organiser approval before joining strict matches

Ability rating:

- 1.0-5.0, starts at 3.0
- Attended players can rate other attended players after completed matches
- MVP uses a running average
- TODO: move to Elo/Glicko-style football ability modelling later

## Organiser Dashboard

Organisers can open the dashboard from match detail to:

- Review pending low-reliability player requests
- Approve or reject players
- See reliability and ability snapshots
- Mark players attended or no-show
- Complete the match and unlock post-match ratings

## Firebase Setup

The app is connected to Firebase project `nextmatch-eb038`, but the committed Firebase config uses placeholder API keys to avoid publishing live keys. To refresh generated config locally:

```bash
flutterfire configure
```

Then replace the placeholder Firebase config values locally before running against the live project.

Deploy Firestore rules:

```bash
firebase deploy --only firestore:rules
```

Run the app:

```bash
flutter pub get
flutter run
```

## Validation

```bash
dart format .
flutter analyze
flutter test
```
