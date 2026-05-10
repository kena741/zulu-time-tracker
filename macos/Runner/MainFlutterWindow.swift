import Cocoa
import CoreGraphics
import FlutterMacOS
import ApplicationServices

private var keyCounter = 0
private var keyMonitor: Any?
private var pointerCounter = 0
private var mouseMoveCounter = 0
private var scrollCounter = 0
private var clickCounter = 0
private var pointerMonitor: Any?

private func isScreenRecordingTrusted() -> Bool {
  if #available(macOS 10.15, *) {
    return CGPreflightScreenCaptureAccess()
  }
  return true
}

private func requestScreenRecordingAccess() {
  if #available(macOS 10.15, *) {
    CGRequestScreenCaptureAccess()
  }
}

private func startKeyboardMonitoring() -> Bool {
  stopKeyboardMonitoring()
  keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in
    keyCounter += 1
  }
  return keyMonitor != nil
}

private func stopKeyboardMonitoring() {
  if let m = keyMonitor {
    NSEvent.removeMonitor(m)
    keyMonitor = nil
  }
}

/// Mouse movement, clicks, and scroll — counted only, never positions (Work Diary activity bars).
private func startPointerMonitoring() -> Bool {
  stopPointerMonitoring()
  let mask: NSEvent.EventTypeMask = [
    .mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel,
  ]
  pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { e in
    pointerCounter += 1
    switch e.type {
    case .mouseMoved:
      mouseMoveCounter += 1
    case .scrollWheel:
      scrollCounter += 1
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      clickCounter += 1
    default:
      break
    }
  }
  return pointerMonitor != nil
}

private func stopPointerMonitoring() {
  if let m = pointerMonitor {
    NSEvent.removeMonitor(m)
    pointerMonitor = nil
  }
}

/// PIDs for processes belonging to this app bundle (main + helpers listed by AppKit).
private func pidsListedForOurBundle() -> Set<Int> {
  var pids = Set<Int>()
  pids.insert(Int(ProcessInfo.processInfo.processIdentifier))
  guard let bundleId = Bundle.main.bundleIdentifier else { return pids }
  for app in NSWorkspace.shared.runningApplications {
    if app.bundleIdentifier == bundleId {
      pids.insert(Int(app.processIdentifier))
    }
  }
  return pids
}

/// True if Quartz window owner PID is this app (any process with our bundle id).
private func pidBelongsToOurApp(_ ownerPid: Int, listedPids: Set<Int>) -> Bool {
  if listedPids.contains(ownerPid) { return true }
  guard let mine = Bundle.main.bundleIdentifier else {
    return ownerPid == Int(ProcessInfo.processInfo.processIdentifier)
  }
  guard let run = NSRunningApplication(processIdentifier: pid_t(ownerPid)),
        let theirs = run.bundleIdentifier else { return false }
  return mine == theirs
}

private func passesWindowCaptureFilters(_ entry: [String: Any]) -> Bool {
  guard let layer = entry["kCGWindowLayer"] as? Int, layer == 0 else { return false }
  if let boundsDict = entry["kCGWindowBounds"] as? [String: Any],
     let wNum = boundsDict["Width"] as? NSNumber,
     let hNum = boundsDict["Height"] as? NSNumber {
    let w = wNum.doubleValue
    let h = hNum.doubleValue
    if w < 48 || h < 48 { return false }
  }
  return true
}

private func runScreencaptureWindow(windowId: UInt32, to path: String, mute: Bool) -> Bool {
  let proc = Process()
  proc.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
  // `-x` disables the system shutter sound when requested.
  if mute {
    proc.arguments = ["-x", "-l", String(windowId), path]
  } else {
    proc.arguments = ["-l", String(windowId), path]
  }
  do {
    try proc.run()
    proc.waitUntilExit()
    return proc.terminationStatus == 0 && FileManager.default.fileExists(atPath: path)
  } catch {
    return false
  }
}

/// Capture the user's **foreground work app** when possible (e.g. Chrome, Cursor), not merely the
/// first non-tracker window in z-order (which could still be our UI if a helper PID was missed).
private func captureFrontNonSelfWindow(to path: String, mute: Bool) -> Bool {
  guard let cfList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as NSArray?
  else {
    return false
  }
  let windowList = cfList as? [[String: Any]] ?? []
  let listed = pidsListedForOurBundle()

  // 1) Foreground app is not ZuluTime → capture **that** app's front window (matches “what I’m working in”).
  if let front = NSWorkspace.shared.frontmostApplication,
     let frontBid = front.bundleIdentifier,
     let mine = Bundle.main.bundleIdentifier,
     frontBid != mine {
    let targetPid = Int(front.processIdentifier)
    for entry in windowList {
      guard let ownerPid = entry["kCGWindowOwnerPID"] as? Int, ownerPid == targetPid else { continue }
      guard passesWindowCaptureFilters(entry) else { continue }
      guard let wid = entry["kCGWindowNumber"] as? UInt32 else { continue }
      if runScreencaptureWindow(windowId: wid, to: path, mute: mute) { return true }
    }
  }

  // 2) Foreground is us (or unknown) → first on-screen window not owned by our bundle.
  for entry in windowList {
    guard let ownerPid = entry["kCGWindowOwnerPID"] as? Int else { continue }
    if pidBelongsToOurApp(ownerPid, listedPids: listed) { continue }
    guard passesWindowCaptureFilters(entry) else { continue }
    guard let wid = entry["kCGWindowNumber"] as? UInt32 else { continue }
    if runScreencaptureWindow(windowId: wid, to: path, mute: mute) { return true }
  }
  return false
}

/// Seconds since the last user input event (keyboard or pointer).
/// This uses CoreGraphics' combined session state.
private func idleSecondsSinceLastInput() -> Double {
  let src = CGEventSourceStateID.combinedSessionState
  let candidates: [CGEventType] = [
    .keyDown,
    .mouseMoved,
    .leftMouseDown,
    .rightMouseDown,
    .otherMouseDown,
    .scrollWheel,
  ]
  var best = Double.greatestFiniteMagnitude
  for t in candidates {
    let s = CGEventSource.secondsSinceLastEventType(src, eventType: t)
    if s >= 0 && s < best { best = s }
  }
  return best == Double.greatestFiniteMagnitude ? 0 : best
}

private func isAccessibilityTrusted() -> Bool {
  AXIsProcessTrusted()
}

/// Shows the macOS Accessibility prompt if this app is not yet trusted.
private func requestAccessibilityPromptIfNeeded() {
  if AXIsProcessTrusted() { return }
  let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
  _ = AXIsProcessTrustedWithOptions(opts)
}

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.zulutime.tracker/platform",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isScreenRecordingTrusted":
        result(isScreenRecordingTrusted())
      case "requestScreenRecordingAccess":
        requestScreenRecordingAccess()
        result(nil)
      case "getKeyboardCountAndReset":
        let c = keyCounter
        keyCounter = 0
        result(c)
      case "getPointerCountAndReset":
        let c = pointerCounter
        pointerCounter = 0
        result(c)
      case "getPointerBreakdownAndReset":
        let moves = mouseMoveCounter
        let scroll = scrollCounter
        let clicks = clickCounter
        mouseMoveCounter = 0
        scrollCounter = 0
        clickCounter = 0
        result([
          "moves": moves,
          "scroll": scroll,
          "clicks": clicks,
        ])
      case "startKeyboardMonitoring":
        let kb = startKeyboardMonitoring()
        let pt = startPointerMonitoring()
        result(kb || pt)
      case "stopKeyboardMonitoring":
        stopKeyboardMonitoring()
        stopPointerMonitoring()
        result(nil)
      case "openPrivacySettings":
        if let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ) {
          NSWorkspace.shared.open(url)
        }
        result(nil)
      case "openScreenRecordingSettings":
        if let url = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        ) {
          NSWorkspace.shared.open(url)
        } else if let fallback = URL(
          string: "x-apple.systempreferences:com.apple.preference.security?Privacy"
        ) {
          NSWorkspace.shared.open(fallback)
        }
        result(nil)
      case "captureWorkAreaToFile":
        let path: String
        var mute = false
        if let s = call.arguments as? String {
          path = s
        } else if let m = call.arguments as? [String: Any],
                  let p = m["path"] as? String {
          path = p
          if let playShutter = m["playShutterSound"] as? Bool {
            mute = !playShutter
          }
        } else {
          result(false)
          return
        }
        result(captureFrontNonSelfWindow(to: path, mute: mute))
      case "getIdleSeconds":
        result(idleSecondsSinceLastInput())
      case "isAccessibilityTrusted":
        result(isAccessibilityTrusted())
      case "requestAccessibilityPromptIfNeeded":
        requestAccessibilityPromptIfNeeded()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
