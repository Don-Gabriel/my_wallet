// File generated from the Firebase console values for MyWallet.
// Re-run `flutterfire configure` if you add platforms or change Firebase apps.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => throw UnsupportedError(
        'DefaultFirebaseOptions are configured for Android and Web only.',
      ),
    };
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCmWH2BhQ9NBMHMESNwHd2unaGpKu1-row',
    appId: '1:343256388815:web:2304988dbf730c2594d3ba',
    messagingSenderId: '343256388815',
    projectId: 'mywallet-d581d',
    authDomain: 'mywallet-d581d.firebaseapp.com',
    storageBucket: 'mywallet-d581d.firebasestorage.app',
    measurementId: 'G-07FTW51DF8',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDCzJUf7TsUR6kKE9Na9hVNqvx8kHv9ehY',
    appId: '1:343256388815:android:5c6f7b5a1918685194d3ba',
    messagingSenderId: '343256388815',
    projectId: 'mywallet-d581d',
    storageBucket: 'mywallet-d581d.firebasestorage.app',
  );
}
