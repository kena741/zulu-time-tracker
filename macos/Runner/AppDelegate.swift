import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private static let lifecycleChannelName = "com.zulutime.tracker/lifecycle"

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    let center = NSWorkspace.shared.notificationCenter
    center.addObserver(
      self,
      selector: #selector(workspaceSleepOrPowerOff(_:)),
      name: NSWorkspace.willSleepNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(workspaceSleepOrPowerOff(_:)),
      name: NSWorkspace.willPowerOffNotification,
      object: nil
    )
  }

  @objc private func workspaceSleepOrPowerOff(_ notification: Notification) {
    Self.notifyDartSuspendOrTerminate()
  }

  @objc private static func notifyDartSuspendOrTerminate() {
    guard
      let controller =
        NSApp.mainWindow?.contentViewController as? FlutterViewController
        ?? NSApp.windows.compactMap({ $0.contentViewController as? FlutterViewController }).first
    else {
      return
    }
    let channel = FlutterMethodChannel(
      name: lifecycleChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.invokeMethod("suspendOrTerminate", arguments: nil)
  }

  override func applicationWillTerminate(_ notification: Notification) {
    Self.notifyDartSuspendOrTerminate()
    super.applicationWillTerminate(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
