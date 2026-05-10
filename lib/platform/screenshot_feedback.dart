import 'dart:io';

import 'package:flutter/services.dart';

/// Short feedback after a screenshot file is written. On macOS the shutter is controlled by
/// [playSound] via `screencapture` `-x`; this adds haptics / optional beeps elsewhere.
Future<void> playScreenshotCapturedFeedback({bool playSound = true}) async {
  if (!playSound) {
    return;
  }

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
