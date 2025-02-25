// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDn6nACDQ-0evPWv1_8tDF1onLoGX8UZk0',
    appId: '1:126666789177:web:01c0e45d842ebc0c3098e8',
    messagingSenderId: '126666789177',
    projectId: 'alarmit-557f4',
    authDomain: 'alarmit-557f4.firebaseapp.com',
    storageBucket: 'alarmit-557f4.firebasestorage.app',
    measurementId: 'G-EH12EKDWL4',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCjLLbT1lBrBF4xNoXbO4SRiEId9J1rcPk',
    appId: '1:126666789177:android:d77f7a0e887b78c23098e8',
    messagingSenderId: '126666789177',
    projectId: 'alarmit-557f4',
    storageBucket: 'alarmit-557f4.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_G7tTJhxxgxLskhEZd3pphbZ9jKgZa1A',
    appId: '1:126666789177:ios:374f70700bf12a073098e8',
    messagingSenderId: '126666789177',
    projectId: 'alarmit-557f4',
    storageBucket: 'alarmit-557f4.firebasestorage.app',
    androidClientId: '126666789177-64rdl91bp7l9bnnui4s8lnumsekpu4ab.apps.googleusercontent.com',
    iosClientId: '126666789177-u1ff5i9vrcon0dua1rcr1q71jbu7s43g.apps.googleusercontent.com',
    iosBundleId: 'com.example.alarmIt',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyD_G7tTJhxxgxLskhEZd3pphbZ9jKgZa1A',
    appId: '1:126666789177:ios:374f70700bf12a073098e8',
    messagingSenderId: '126666789177',
    projectId: 'alarmit-557f4',
    storageBucket: 'alarmit-557f4.firebasestorage.app',
    androidClientId: '126666789177-64rdl91bp7l9bnnui4s8lnumsekpu4ab.apps.googleusercontent.com',
    iosClientId: '126666789177-u1ff5i9vrcon0dua1rcr1q71jbu7s43g.apps.googleusercontent.com',
    iosBundleId: 'com.example.alarmIt',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDn6nACDQ-0evPWv1_8tDF1onLoGX8UZk0',
    appId: '1:126666789177:web:43ea5af4e4483e233098e8',
    messagingSenderId: '126666789177',
    projectId: 'alarmit-557f4',
    authDomain: 'alarmit-557f4.firebaseapp.com',
    storageBucket: 'alarmit-557f4.firebasestorage.app',
    measurementId: 'G-DB82FVH5YG',
  );

}