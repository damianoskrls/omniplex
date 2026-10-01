import 'services/global_auth_service.dart';

/// Exits that stay available inside a gym, even if the screen was opened
/// from a cached session and did not receive callbacks.
class AppNav {
  static void Function()? leaveGym;
  static Future<void> Function(GlobalGym gym)? enterAsRole;
}
