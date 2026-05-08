// hid_monitor dispatches RawKeyEvent; Flutter deprecates it in favor of KeyEvent.
// ignore_for_file: deprecated_member_use

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hid_monitor/hid_monitor.dart' deferred as hm;

/// Slice of HID activity accumulated since the last flush (typically 30s).
class HidFlushSlice {
  const HidFlushSlice({
    required this.keyboard,
    required this.pointer,
    required this.clicks,
    required this.minuteMask,
  });

  final int keyboard;
  final int pointer;
  final int clicks;

  /// Bits 0–9: minute index within the current 10-minute wall-clock slot (`minute % 10`)
  /// had at least one counted HID event since the last [consumePendingSlice].
  final int minuteMask;
}

/// Global HID capture via [hid_monitor]: key down, mouse move, wheel, left/right button down.
///
/// Privacy: only aggregate counts and which minute inside a slot saw activity — no key text,
/// key codes in storage, or cursor positions sent to the cloud.
///
/// **macOS:** The Dart FFI loader must not open `hid_monitor.framework` while CocoaPods
/// already links the same framework (duplicate Obj‑C class registration and
/// `Failed to load ... HidMonitorBindings`). On macOS we skip deferred load entirely and
/// rely on [NativeDesktop] in [SessionService].
class HidTrackingService extends GetxService {
  /// Single in-flight warm-up so concurrent callers await the same work (SessionService + bootstrap).
  Future<void>? _warmUpFuture;

  bool _initialized = false;
  bool _listenersAttached = false;

  bool _recording = false;

  int _pendingKb = 0;
  int _pendingPtr = 0;
  int _pendingClicks = 0;
  int _pendingMinuteMask = 0;

  static const int _maskLen = 10;
  static const int _maskAll = (1 << _maskLen) - 1;

  int _lastKbLogMs = 0;

  bool get isDesktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  bool get isReady => _initialized && _listenersAttached;

  Future<void> warmUp() async {
    if (!isDesktop) return;
    _warmUpFuture ??= _doWarmUp();
    await _warmUpFuture!;
  }

  Future<void> _doWarmUp() async {
    if (Platform.isMacOS) {
      return;
    }

    try {
      await hm.loadLibrary();
      final backend = hm.getListenerBackend();
      if (backend == null) return;

      if (!backend.initialize()) return;
      _initialized = true;

      final kbdOk = backend.addKeyboardListener(_onKeyboard);
      // Deferred libraries forbid `is`/`as` on hid_monitor types; dispatch dynamically.
      final mouseOk = backend.addMouseListener(_onMouseDeferred);
      _listenersAttached = kbdOk != null && mouseOk != null;
    } catch (e, st) {
      debugPrint('HidTrackingService: hid_monitor unavailable ($e)');
      debugPrint('$st');
      _initialized = false;
      _listenersAttached = false;
    }
  }

  void setRecording(bool on) {
    _recording = on;
  }

  void _touchMinuteMask() {
    final idx = DateTime.now().minute % _maskLen;
    _pendingMinuteMask |= (1 << idx);
  }

  void _printKeyboardCountDuringTracking() {
    if (!kDebugMode) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_pendingKb <= 0) return;

    // Throttle: log at most once per second, and also on every 25th keypress.
    final shouldLog = (_pendingKb % 25 == 0) || (now - _lastKbLogMs >= 1000);
    if (!shouldLog) return;

    _lastKbLogMs = now;
    debugPrint('HID keyboard count (pending slice): $_pendingKb');
  }

  void _onKeyboard(RawKeyEvent event) {
    if (!_recording) return;
    if (event is! RawKeyDownEvent) return;
    _pendingKb++;
    _touchMinuteMask();
    _printKeyboardCountDuringTracking();
  }

  void _onMouseDeferred(dynamic event) {
    if (!_recording) return;
    try {
      final wd = event.wheelDelta;
      if (wd != null) {
        _pendingPtr++;
        _touchMinuteMask();
        return;
      }
    } on NoSuchMethodError catch (_) {}
    try {
      final type = event.type;
      final desc = type.toString();
      if (desc.contains('leftButtonDown') || desc.contains('rightButtonDown')) {
        _pendingClicks++;
      }
      _touchMinuteMask();
      return;
    } on NoSuchMethodError catch (_) {}
    _pendingPtr++;
    _touchMinuteMask();
  }

  HidFlushSlice consumePendingSlice() {
    final slice = HidFlushSlice(
      keyboard: _pendingKb,
      pointer: _pendingPtr,
      clicks: _pendingClicks,
      minuteMask: _pendingMinuteMask & _maskAll,
    );
    _pendingKb = 0;
    _pendingPtr = 0;
    _pendingClicks = 0;
    _pendingMinuteMask = 0;
    return slice;
  }
}
