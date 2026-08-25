import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for Jokarz Engineering
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.linux:
        return linux;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDpWYXEVu_Ij013KQmlP6tj9hOH0AY30-E',
    appId: '1:693644308941:web:35ca8915df8296ae355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCtUWu5YUFLstM0FJHLgEp1MMtS0v6wPt0',
    appId: '1:693644308941:android:9bbd7e2d3a30b227355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );

  // Windows Desktop shares web/rest credentials for cross-device desktop sync
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDpWYXEVu_Ij013KQmlP6tj9hOH0AY30-E',
    appId: '1:693644308941:web:35ca8915df8296ae355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDpWYXEVu_Ij013KQmlP6tj9hOH0AY30-E',
    appId: '1:693644308941:web:35ca8915df8296ae355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDpWYXEVu_Ij013KQmlP6tj9hOH0AY30-E',
    appId: '1:693644308941:web:35ca8915df8296ae355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );

  static const FirebaseOptions linux = FirebaseOptions(
    apiKey: 'AIzaSyDpWYXEVu_Ij013KQmlP6tj9hOH0AY30-E',
    appId: '1:693644308941:web:35ca8915df8296ae355484',
    messagingSenderId: '693644308941',
    projectId: 'jokarz-engineering',
    storageBucket: 'jokarz-engineering.firebasestorage.app',
  );
}
