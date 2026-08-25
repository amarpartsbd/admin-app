import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase config (Android). iOS needs GoogleService-Info.plist + its options
/// added here later. Guarded in main() so non-Android platforms don't crash.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError('Firebase is only configured for Android in this build.');
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD27fnLczqZvAw3ZQnXkI6V5w8UD8mSk1Q',
    appId: '1:164573520905:android:b97825839ae94fb23a84d8',
    messagingSenderId: '164573520905',
    projectId: 'erp-otp-a4b77',
    storageBucket: 'erp-otp-a4b77.firebasestorage.app',
  );
}
