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
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: _placeholder,
    appId: _placeholder,
    messagingSenderId: _placeholder,
    projectId: _placeholder,
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
