# Firebase Setup

NextMatch is wired for Firebase Auth, Cloud Firestore and Firebase Storage placeholders. The current Firebase project is `nextmatch-eb038`.

## 1. Create the Firebase project

1. Create a Firebase project, for example `nextmatch-dev`.
2. Add Android and iOS apps:
   - Android package: `com.nextmatch.next_match`
   - iOS bundle identifier: check Xcode if you change it, otherwise use the generated Runner bundle ID.
3. Enable Email/Password in Firebase Authentication.
4. Create a Cloud Firestore database.
5. Create a Firebase Storage bucket if you want profile photos later.

## 2. Add local Firebase options

NextMatch keeps real Firebase client config out of Git using a local `.env.firebase` file. The committed `lib/firebase_options.dart` reads those values at runtime via Flutter dart-defines and falls back to safe placeholders when the local file is missing.

Create your local file:

```bash
cp .env.firebase.example .env.firebase
```

Fill `.env.firebase` with the values from Firebase Console project settings, or run FlutterFire CLI in a temporary/local workspace and copy the generated values into `.env.firebase`.

Run the app with:

```bash
flutter run -d chrome --dart-define-from-file=.env.firebase
```

For iOS or Android:

```bash
flutter run -d ios --dart-define-from-file=.env.firebase
flutter run -d android --dart-define-from-file=.env.firebase
```

Important: Firebase API keys in client apps are not server secrets because they are still shipped in web/mobile builds. Keeping them in `.env.firebase` prevents accidental Git commits and GitHub alerts, but you must also restrict the keys in Google Cloud Console to the correct domains, bundle IDs and package names.

If the login screen says the app is using placeholder API keys, `.env.firebase` is missing, still contains placeholder values, or the app was launched without `--dart-define-from-file=.env.firebase`.

## 3. Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

The starter rules cover profiles, public match reads, organiser approvals, withdrawals, attendance marking, completed-match ratings and relevant payment reads.

TODO: move trust score writes, Stripe fulfilment, refunds and no-show enforcement into Cloud Functions before production.

## 4. Run the app

```bash
flutter pub get
flutter run -d chrome --dart-define-from-file=.env.firebase
```

After registering, complete the player profile. If the match list is empty, use the in-app `Add demo matches` button.
