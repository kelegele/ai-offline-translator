import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let translatorChannelHandler = TranslatorChannelHandler()

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      translatorChannelHandler.register(with: controller)
    }
    super.applicationDidFinishLaunching(notification)
  }
}
