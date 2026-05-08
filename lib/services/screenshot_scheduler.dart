import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../platform/native_desktop.dart';
import '../platform/screenshot_capture.dart';
import '../platform/screenshot_feedback.dart';
import 'cloud_service.dart';
import 'cloud_refresh_service.dart';
import 'preferences_service.dart';
import 'session_service.dart';

/// Periodically captures screenshots after privacy consent (core Work Diary feature).
/// PNGs are written to the app cache directory only until uploaded to Supabase Storage,
/// then the local file is removed.
class ScreenshotScheduler extends GetxService {
  ScreenshotScheduler(this._cloud);

  final CloudService _cloud;
  Timer? _timer;
  final _uuid = const Uuid();

  /// macOS: `CGPreflightScreenCaptureAccess()` can be false even when Screen Recording / Screen &
  /// System Audio Recording is ON — only trust an actual capture attempt.
  static bool _screenCaptureDeniedDialogShown = false;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  Future<void> syncWithPreferences() async {
    _timer?.cancel();
    final prefs = Get.find<PreferencesService>();
    if (!prefs.privacyConsentAccepted) {
      return;
    }
    final minutes = prefs.screenshotIntervalMinutes;
    // Periodic timer waits [minutes] before the first tick — capture once promptly so uploads can start.
    scheduleMicrotask(() async {
      try {
        await _captureOnce();
      } catch (e, st) {
        developer.log(
          'Screenshot capture failed',
          error: e,
          stackTrace: st,
        );
      }
    });
    _timer = Timer.periodic(Duration(minutes: minutes), (_) => _captureOnce());
  }

  Future<void> _captureOnce() async {
    final session = Get.isRegistered<SessionService>()
        ? Get.find<SessionService>()
        : null;
    final sessionId = session?.activeSessionId.value;
    if (sessionId == null || sessionId.isEmpty) {
      // Without an active session we have no slot to attach the screenshot to.
      return;
    }

    final root = await getApplicationCacheDirectory();
    final shotDir = Directory(p.join(root.path, 'zulutime_captures'));
    if (!shotDir.existsSync()) shotDir.createSync(recursive: true);
    final name = '${DateTime.now().millisecondsSinceEpoch}_${_uuid.v4()}.png';
    final path = p.join(shotDir.path, name);

    final ok = await captureScreenToFile(path);
    if (ok) {
      _screenCaptureDeniedDialogShown = false;
    } else {
      developer.log('Screenshot capture returned false (permissions?)');
      if (Platform.isMacOS && !_screenCaptureDeniedDialogShown) {
        _screenCaptureDeniedDialogShown = true;
        await NativeDesktop.requestScreenRecordingAccess();
        Get.dialog(
          AlertDialog(
            title: const Text('Screenshot failed'),
            content: const Text(
              'Could not capture the screen. If macOS shows Screen Recording permission '
              'as enabled already, fully quit the app and open it again (sometimes macOS '
              'needs one restart after granting).\n\n'
              'Also confirm Settings → Privacy & Security → Screen & System Audio Recording '
              '(newer macOS) includes this app, then Quit & Reopen when macOS asks.',
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await NativeDesktop.openScreenRecordingSettings();
                },
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('OK'),
              ),
            ],
          ),
          barrierDismissible: true,
        );
      }
      return;
    }

    await playScreenshotCapturedFeedback();

    final capturedAt = DateTime.now();
    final slotStart = CloudService.slotStartFor(capturedAt);
    try {
      await _cloud.uploadScreenshotForSlot(
        sessionId: sessionId,
        slotStart: slotStart,
        filePath: path,
        capturedAt: capturedAt,
      );
      // Refresh Work Diary UI so newly attached `storage_path` shows immediately.
      if (Get.isRegistered<CloudRefreshService>()) {
        Get.find<CloudRefreshService>().bump();
      }
    } catch (e, st) {
      developer.log(
        'Screenshot upload after capture failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}
