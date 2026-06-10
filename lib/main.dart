import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(NextMatchApp(startupFuture: _initialiseFirebase()));
}

Future<void> _initialiseFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    _configureFirestoreForClient();
  } on FirebaseException catch (error) {
    if (error.code != 'duplicate-app') rethrow;
    _configureFirestoreForClient();
  }
}

void _configureFirestoreForClient() {
  if (!kIsWeb) return;

  // Hot restart on web can leave Firestore's persistent JS cache in a bad
  // listener state. Memory-only cache is steadier for the MVP dev workflow.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
}
