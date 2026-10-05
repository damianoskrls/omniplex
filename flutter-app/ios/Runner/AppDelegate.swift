import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Stripe presents the card sheet from this window. With a scene-based
  /// Flutter app the AppDelegate window is empty, so the sheet never appears.
  override var window: UIWindow? {
    get {
      if let current = super.window, current.rootViewController != nil {
        return current
      }
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
      return scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first
    }
    set { super.window = newValue }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
