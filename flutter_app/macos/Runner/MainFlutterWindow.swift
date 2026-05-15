import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController

    // Set reasonable window size limits (only applies to non-fullscreen)
    self.minSize = NSSize(width: 400, height: 600)
    self.collectionBehavior = .fullScreenPrimary

    // Set initial window size
    let initialFrame = NSRect(x: windowFrame.origin.x,
                              y: windowFrame.origin.y,
                              width: 480,
                              height: 720)
    self.setFrame(initialFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    self.title = "AI离线翻译"

    super.awakeFromNib()
  }
}
