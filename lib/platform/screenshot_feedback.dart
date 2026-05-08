import 'dart:io';

import 'package:flutter/services.dart';

/// Short feedback after a screenshot file is written. On macOS, `screencapture` is run
/// without `-x` so the system shutter already played; we only add light haptics where supported.
Future<void> playScreenshotCapturedFeedback() async {
  await HapticFeedback.lightImpact();

  if (Platform.isMacOS) {
    return;
  }

  if (Platform.isWindows) {
    try {
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          '[console]::beep(880,40)',
        ],
      );
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
    return;
  }

  if (Platform.isLinux) {
    try {
      await Process.run('paplay', [
        '/usr/share/sounds/freedesktop/stereo/message.oga',
      ]);
    } catch (_) {
      await SystemSound.play(SystemSoundType.click);
    }
    return;
  }

  await SystemSound.play(SystemSoundType.click);
}
