import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import 'session_service.dart';

/// Native sleep/shutdown signals and window close: end tracking before the process dies.
Future<void> registerSessionDesktopLifecycle() async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;

  const ch = MethodChannel('com.zulutime.tracker/lifecycle');
  ch.setMethodCallHandler((call) async {
    if (call.method == 'suspendOrTerminate') {
      if (Get.isRegistered<SessionService>()) {
        // On suspend/shutdown the OS may stop scheduling quickly; don't block on async I/O.
        unawaited(Get.find<SessionService>().stopSession());
      }
    }
  });

  await windowManager.setPreventClose(true);
  windowManager.addListener(_SessionWindowCloseListener());
}

class _SessionWindowCloseListener with WindowListener {
  @override
  void onWindowClose() {
    unawaited(_handleClose());
  }

  Future<void> _handleClose() async {
    try {
      if (Get.isRegistered<SessionService>()) {
        await Get.find<SessionService>().stopSession();
      }
    } catch (_) {
      // Still close the window.
    } finally {
      await windowManager.setPreventClose(false);
      await windowManager.destroy();
    }
  }
}
