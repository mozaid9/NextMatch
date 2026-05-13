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

## 2. Generate real Firebase options

Install FlutterFire CLI if needed, then run:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Replace the placeholder values in `lib/firebase_options.dart`, `android/app/google-services.json`, and the Apple `GoogleService-Info.plist` files with the generated local Firebase config.

Important: if GitHub secret scanning flags the generated Google API keys, either keep the generated files local or ensure the keys are restricted to the correct app identifiers in Google Cloud Console before committing.

## 3. Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

The starter rules cover profiles, public match reads, organiser approvals, withdrawals, attendance marking, completed-match ratings and relevant payment reads.

TODO: move trust score writes, Stripe fulfilment, refunds and no-show enforcement into Cloud Functions before production.

## 4. Run the app

```bash
flutter pub get
flutter run
```

After registering, complete the player profile. If the match list is empty, use the in-app `Add demo matches` button.
