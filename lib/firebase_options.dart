import 'package:firebase_core/firebase_core.dart';
import 'dart:io' show Platform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (Platform.isAndroid) return android;
    // Add iOS or others if you add those later
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD7dkhKOO4Cb49dwLiUnG6rhG9wV8KKMSg',
    appId: '1:638941931419:android:3a3342b53fafb58829a33e',
    messagingSenderId: '638941931419',
    projectId: 'sports-attendance-system',
    storageBucket: 'sports-attendance-system.firebasestorage.app',
  );
}
