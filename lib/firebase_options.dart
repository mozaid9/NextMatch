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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBmcYuuqbxHKSPPlNhYzrTLViLkUPtPz_g',
    appId: '1:562392184918:web:587b361e90d5d1aad3e3f7',
    messagingSenderId: '562392184918',
    projectId: 'nextmatch-eb038',
    authDomain: 'nextmatch-eb038.firebaseapp.com',
    storageBucket: 'nextmatch-eb038.firebasestorage.app',
    measurementId: 'G-SW1K87HHGF',
  );

  // Firebase project is ready. These placeholders keep the MVP compiling.

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCqi5ygR-dMOU73_1X2efTPtP3BQDNTZTM',
    appId: '1:562392184918:android:c2365ff46ce939b7d3e3f7',
    messagingSenderId: '562392184918',
    projectId: 'nextmatch-eb038',
    storageBucket: 'nextmatch-eb038.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCS69IAGAUyQ2uoC3ZL8FggiJ8HPnbXit8',
    appId: '1:562392184918:ios:9e6c5b8291e95d74d3e3f7',
    messagingSenderId: '562392184918',
    projectId: 'nextmatch-eb038',
    storageBucket: 'nextmatch-eb038.firebasestorage.app',
    iosBundleId: 'com.nextmatch.nextMatch',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCS69IAGAUyQ2uoC3ZL8FggiJ8HPnbXit8',
    appId: '1:562392184918:ios:9e6c5b8291e95d74d3e3f7',
    messagingSenderId: '562392184918',
    projectId: 'nextmatch-eb038',
    storageBucket: 'nextmatch-eb038.firebasestorage.app',
    iosBundleId: 'com.nextmatch.nextMatch',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyBmcYuuqbxHKSPPlNhYzrTLViLkUPtPz_g',
    appId: '1:562392184918:web:53fc4cbcafef2c8dd3e3f7',
    messagingSenderId: '562392184918',
    projectId: 'nextmatch-eb038',
    authDomain: 'nextmatch-eb038.firebaseapp.com',
    storageBucket: 'nextmatch-eb038.firebasestorage.app',
    measurementId: 'G-PHHX77N2VD',
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