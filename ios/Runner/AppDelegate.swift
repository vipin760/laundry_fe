import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Created and run eagerly here (instead of relying on Flutter's default
  // "implicit engine" template mechanism) so plugins are registered before
  // application(_:didFinishLaunchingWithOptions:) returns.
  //
  // Why this matters: firebase_messaging's iOS plugin (FLTFirebaseMessagingPlugin)
  // registers an NSNotificationCenter observer for
  // UIApplicationDidFinishLaunchingNotification inside its own plugin
  // registration code, and getInitialMessage() only ever resolves once that
  // observer fires. With the default implicit-engine template, plugins are
  // only registered once a Scene connects (FlutterImplicitEngineDelegate,
  // previously used here) — which happens AFTER
  // application(_:didFinishLaunchingWithOptions:) returns and AFTER
  // UIApplicationDidFinishLaunchingNotification has already been posted by
  // UIKit. The observer is then registered too late to ever see it, so
  // FirebaseMessaging.instance.getInitialMessage() awaits forever with no
  // error — exactly the white-screen-on-launch symptom this was causing.
  //
  // FlutterSceneDelegate's own scene:willConnectToSession:options:
  // implementation already knows how to adopt a rootViewController set up
  // here and move it onto the Scene's window instead of creating its own
  // implicit engine (see moveRootViewControllerFrom:to: in the Flutter
  // engine source) — so SceneDelegate.swift needs no changes for this fix.
  let flutterEngine = FlutterEngine(name: "main engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = FlutterViewController(
      engine: flutterEngine, nibName: nil, bundle: nil)
    window?.makeKeyAndVisible()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
