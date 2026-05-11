import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

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

  // Replace this file with the output of `flutterfire configure` when your
  // Firebase project is ready. These placeholders keep the MVP compiling.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:web:nextmatch',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    authDomain: 'nextmatch-dev.firebaseapp.com',
    storageBucket: 'nextmatch-dev.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:android:nextmatch',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    storageBucket: 'nextmatch-dev.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:ios:nextmatch',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    storageBucket: 'nextmatch-dev.appspot.com',
    iosBundleId: 'com.nextmatch.nextMatch',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:ios:nextmatchmacos',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    storageBucket: 'nextmatch-dev.appspot.com',
    iosBundleId: 'com.nextmatch.nextMatch',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:web:nextmatchwindows',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    authDomain: 'nextmatch-dev.firebaseapp.com',
    storageBucket: 'nextmatch-dev.appspot.com',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'replace-with-firebase-api-key',
    appId: '1:000000000000:web:nextmatchlinux',
    messagingSenderId: '000000000000',
    projectId: 'nextmatch-dev',
    authDomain: 'nextmatch-dev.firebaseapp.com',
    storageBucket: 'nextmatch-dev.appspot.com',
  );
}
