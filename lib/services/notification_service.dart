import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web push certificate key pair (Firebase Console → Project settings →
/// Cloud Messaging → Web configuration → Web Push certificates).
/// Required for FCM tokens on web; harmless on mobile.
/// TODO: paste the real key — until then web token registration no-ops.
const String kWebVapidKey = 'REPLACE_WITH_WEB_PUSH_CERTIFICATE_KEY';

/// Registers this device for push notifications and keeps its FCM token
/// stored under `users/{uid}/fcmTokens/{token}` so Cloud Functions can
/// fan out invites, chat messages and match updates.
class NotificationService {
  NotificationService({
    FirebaseMessaging? messaging,
    FirebaseFirestore? firestore,
  }) : _messaging = messaging ?? FirebaseMessaging.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _firestore;

  String? _registeredForUid;

  /// Foreground messages, surfaced so the UI can show an in-app banner.
  Stream<RemoteMessage> get foregroundMessages => FirebaseMessaging.onMessage;

  /// Ask for permission and store this device's token. Safe to call on
  /// every sign-in; it no-ops when already registered for the same user,
  /// when permission is declined, or when the web VAPID key isn't set yet.
  Future<void> initialise(String uid) async {
    if (_registeredForUid == uid) return;
    if (kIsWeb && kWebVapidKey.startsWith('REPLACE_WITH')) {
      if (kDebugMode) {
        debugPrint('FCM: web VAPID key not configured, skipping registration.');
      }
      return;
    }

    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? kWebVapidKey : null,
      );
      if (token == null) return;

      await _saveToken(uid, token);
      _registeredForUid = uid;

      _messaging.onTokenRefresh.listen((refreshed) {
        final owner = _registeredForUid;
        if (owner != null) _saveToken(owner, refreshed);
      });
    } catch (error) {
      // Notifications are an enhancement — never block sign-in on them.
      if (kDebugMode) debugPrint('FCM registration failed: $error');
    }
  }

  Future<void> _saveToken(String uid, String token) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token)
        .set({
          'token': token,
          'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        });
  }

  /// Drop this device's token so a signed-out device stops receiving
  /// another account's notifications.
  Future<void> unregister() async {
    final uid = _registeredForUid;
    _registeredForUid = null;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? kWebVapidKey : null,
      );
      if (token != null) {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(token)
            .delete();
      }
      await _messaging.deleteToken();
    } catch (error) {
      if (kDebugMode) debugPrint('FCM unregister failed: $error');
    }
  }
}
