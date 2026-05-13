import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initialiseFirebase();

  runApp(const NextMatchApp());
}

Future<void> _initialiseFirebase() async {
  if (Firebase.apps.isNotEmpty) return;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
  }
}
