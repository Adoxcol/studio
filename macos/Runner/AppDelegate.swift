import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillFinishLaunching(_ notification: Notification) {
    super.applicationWillFinishLaunching(notification)
    guard let bundleId = Bundle.main.bundleIdentifier else { return }
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
      .filter { $0 != NSRunningApplication.current }
    if let existing = others.first {
      if #available(macOS 14.0, *) {
        existing.activate()
      } else {
        existing.activate(options: [.activateIgnoringOtherApps])
      }
      // Before the Flutter window nib loads, so this process never opens sqlite.
      NSApp.terminate(nil)
    }
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      sender.windows.forEach { $0.makeKeyAndOrderFront(nil) }
    }
    return true
  }
}
