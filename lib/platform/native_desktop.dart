import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Optional native desktop integrations: aggregated input activity (keyboard counts,
/// pointer moves/clicks/scroll — never key identity, positions, or page content)
/// and opening system privacy settings. Falls back safely on unsupported platforms.
class NativeDesktop {
  NativeDesktop._();

  static const _channel = MethodChannel('com.zulutime.tracker/platform');

  static Future<Map<String, int>> getPointerBreakdownAndReset() async {
    if (!_desktop) return const {'moves': 0, 'scroll': 0, 'clicks': 0};
    try {
      final v = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getPointerBreakdownAndReset',
      );
      if (v == null) return const {'moves': 0, 'scroll': 0, 'clicks': 0};
      int asInt(dynamic x) => x is num ? x.toInt() : int.tryParse('$x') ?? 0;
      return <String, int>{
        'moves': asInt(v['moves']),
        'scroll': asInt(v['scroll']),
        'clicks': asInt(v['clicks']),
      };
    } on MissingPluginException {
      return const {'moves': 0, 'scroll': 0, 'clicks': 0};
    }
  }

  static Future<int> getKeyboardCountAndReset() async {
    if (!_desktop) return 0;
    try {
      final v = await _channel.invokeMethod<int>('getKeyboardCountAndReset');
      final n = v ?? 0;
      if (kDebugMode && n > 0) {
        debugPrint('NativeDesktop keyboard count (since last reset): $n');
      }
      return n;
    } on MissingPluginException {
      return 0;
    }
  }

  /// Mouse move / click / scroll events (counts only), reset after read.
  static Future<int> getPointerCountAndReset() async {
    if (!_desktop) return 0;
    try {
      final v = await _channel.invokeMethod<int>('getPointerCountAndReset');
      return v ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  /// OS-reported seconds since last keyboard or pointer input.
  static Future<double> getIdleSeconds() async {
    if (!_desktop) return 0;
    try {
      final v = await _channel.invokeMethod<double>('getIdleSeconds');
      return v ?? 0;
    } on MissingPluginException {
      return 0;
    }
  }

  static Future<bool> startKeyboardMonitoring() async {
    if (!_desktop) return false;
    try {
      final v = await _channel.invokeMethod<bool>('startKeyboardMonitoring');
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static Future<void> stopKeyboardMonitoring() async {
    if (!_desktop) return;
    try {
      await _channel.invokeMethod<void>('stopKeyboardMonitoring');
    } on MissingPluginException {}
  }

  static Future<void> openPrivacySettings() async {
    if (!_desktop) return;
    try {
      await _channel.invokeMethod<void>('openPrivacySettings');
    } on MissingPluginException {}
  }

  /// macOS: Quartz preflight for screen capture. Can be **false negatives** on newer macOS even
  /// when Settings shows Screen & System Audio Recording enabled — prefer attempting capture.
  static Future<bool> isScreenRecordingTrusted() async {
    if (!_desktop || !Platform.isMacOS) return true;
    try {
      final v = await _channel.invokeMethod<bool>('isScreenRecordingTrusted');
      return v ?? false;
    } on MissingPluginException {
      return true;
    }
  }

  /// macOS: shows the OS Screen Recording permission prompt (first time only).
  static Future<void> requestScreenRecordingAccess() async {
    if (!_desktop || !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('requestScreenRecordingAccess');
    } on MissingPluginException {}
  }

  /// macOS: opens Privacy & Security → Screen Recording.
  static Future<void> openScreenRecordingSettings() async {
    if (!_desktop || !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('openScreenRecordingSettings');
    } on MissingPluginException {}
  }

  /// macOS: prompts for Accessibility if needed (may show a system dialog once).
  static Future<void> requestAccessibilityPromptIfNeeded() async {
    if (!_desktop || !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('requestAccessibilityPromptIfNeeded');
    } on MissingPluginException {}
  }

  /// macOS: returns whether this process is trusted for Accessibility APIs.
  static Future<bool> isAccessibilityTrusted() async {
    if (!_desktop || !Platform.isMacOS) return false;
    try {
      final v = await _channel.invokeMethod<bool>('isAccessibilityTrusted');
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Captures the user's active **work** window (frontmost window not belonging to this app)
  /// when the native implementation supports it (macOS). Returns `false` to let callers fall back
  /// to full-screen capture.
  static Future<bool> captureWorkAreaToFile(String outputPath) async {
    if (!_desktop) return false;
    try {
      final v =
          await _channel.invokeMethod<bool>('captureWorkAreaToFile', outputPath);
      return v ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  static bool get _desktop =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
