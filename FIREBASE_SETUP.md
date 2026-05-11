# Firebase Setup

NextMatch is wired for Firebase Auth, Cloud Firestore and Firebase Storage placeholders.

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

Replace `lib/firebase_options.dart` with the generated file. The current file contains placeholders so the code compiles before a Firebase project exists.

## 3. Deploy Firestore rules

```bash
firebase deploy --only firestore:rules
```

The starter rules allow the MVP client transaction to increment match counts after mock payment. Move this fulfilment to Cloud Functions when Stripe goes live.

## 4. Run the app

```bash
flutter pub get
flutter run
```

After registering, complete the player profile. If the match list is empty, use the in-app `Add demo matches` button.
