import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static const _projectId = String.fromEnvironment(
    'NEXTMATCH_FIREBASE_PROJECT_ID',
    defaultValue: 'nextmatch-eb038',
  );
  static const _authDomain = String.fromEnvironment(
    'NEXTMATCH_FIREBASE_AUTH_DOMAIN',
    defaultValue: 'nextmatch-eb038.firebaseapp.com',
  );
  static const _storageBucket = String.fromEnvironment(
    'NEXTMATCH_FIREBASE_STORAGE_BUCKET',
    defaultValue: 'nextmatch-eb038.firebasestorage.app',
  );
  static const _messagingSenderId = String.fromEnvironment(
    'NEXTMATCH_FIREBASE_MESSAGING_SENDER_ID',
    defaultValue: 'REPLACE_WITH_SENDER_ID',
  );

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      _ => throw UnsupportedError('Unsupported platform for Firebase.'),
    };
  }

  // Safe placeholder defaults for source control. Run with
  // `--dart-define-from-file=.env.firebase` to inject local Firebase values.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WEB_API_KEY',
      defaultValue: 'REPLACE_WITH_WEB_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WEB_APP_ID',
      defaultValue: 'REPLACE_WITH_WEB_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
    measurementId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WEB_MEASUREMENT_ID',
      defaultValue: 'REPLACE_WITH_MEASUREMENT_ID',
    ),
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_ANDROID_API_KEY',
      defaultValue: 'REPLACE_WITH_ANDROID_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_ANDROID_APP_ID',
      defaultValue: 'REPLACE_WITH_ANDROID_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_IOS_API_KEY',
      defaultValue: 'REPLACE_WITH_IOS_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_IOS_APP_ID',
      defaultValue: 'REPLACE_WITH_IOS_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: String.fromEnvironment(
      'NEXTMATCH_IOS_BUNDLE_ID',
      defaultValue: 'com.nextmatch.nextMatch',
    ),
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_MACOS_API_KEY',
      defaultValue: 'REPLACE_WITH_MACOS_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_MACOS_APP_ID',
      defaultValue: 'REPLACE_WITH_MACOS_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    storageBucket: _storageBucket,
    iosBundleId: String.fromEnvironment(
      'NEXTMATCH_MACOS_BUNDLE_ID',
      defaultValue: 'com.nextmatch.nextMatch',
    ),
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WINDOWS_API_KEY',
      defaultValue: 'REPLACE_WITH_WINDOWS_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WINDOWS_APP_ID',
      defaultValue: 'REPLACE_WITH_WINDOWS_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
    measurementId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_WINDOWS_MEASUREMENT_ID',
      defaultValue: 'REPLACE_WITH_MEASUREMENT_ID',
    ),
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_LINUX_API_KEY',
      defaultValue: 'REPLACE_WITH_LINUX_API_KEY',
    ),
    appId: String.fromEnvironment(
      'NEXTMATCH_FIREBASE_LINUX_APP_ID',
      defaultValue: 'REPLACE_WITH_LINUX_APP_ID',
    ),
    messagingSenderId: _messagingSenderId,
    projectId: _projectId,
    authDomain: _authDomain,
    storageBucket: _storageBucket,
  );
}
