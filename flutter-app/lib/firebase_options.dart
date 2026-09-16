// Generated / maintained for FlutterFire. Run `flutterfire configure` to replace placeholders.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String _placeholder = 'REPLACE_ME';

  /// True after `flutterfire configure` or manual Firebase setup.
  static bool get isConfigured {
    final o = _optionsForPlatform();
    return o.apiKey != _placeholder && o.projectId != _placeholder;
  }

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return _optionsForPlatform();
  }

  static FirebaseOptions _optionsForPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyD-nwx-gt6alGH16B_jtMkzRWSNPavvTN0',
    appId: '1:807733628490:android:a5a027290f740bbb4e20b3',
    messagingSenderId: '807733628490',
    projectId: 'omniplex-1a046',
    storageBucket: 'omniplex-1a046.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBrCreWyF2y9HpJCwb49rrlLlk0Yu01Zg8',
    appId: '1:807733628490:ios:4634e9ef9b18ddf54e20b3',
    messagingSenderId: '807733628490',
    projectId: 'omniplex-1a046',
    storageBucket: 'omniplex-1a046.firebasestorage.app',
    iosBundleId: 'com.handstand.app',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
    iosBundleId: 'com.handstand.app',
  );
}
