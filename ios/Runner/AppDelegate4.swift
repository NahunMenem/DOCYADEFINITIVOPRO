import UIKit
import Flutter
import GoogleMaps   // 👈 dejamos solo Maps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 🌍 Inicializa Google Maps
    GMSServices.provideAPIKey("AIzaSyDnaoExuqJAcquC_joiPZA1lGDdhRHV4wY")

    // 🔗 Plugins Flutter
    GeneratedPluginRegistrant.register(with: self)

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
