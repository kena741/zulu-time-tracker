import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../platform/native_desktop.dart';
import '../../../../services/preferences_service.dart';
import '../../../../services/screenshot_scheduler.dart';
import '../../../utils/nav_helper.dart';

class PrivacyController extends GetxController {
  Future<void> saveAndContinue() async {
    final prefs = Get.find<PreferencesService>();
    await prefs.setPrivacyConsentAccepted(true);
    await Get.find<ScreenshotScheduler>().syncWithPreferences();

    // Desktop OS permissions cannot be granted during "install" — prompt at first consent.
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      await NativeDesktop.requestAccessibilityPromptIfNeeded();

      var trusted = true;
      if (Platform.isMacOS) {
        trusted = await NativeDesktop.isAccessibilityTrusted();
      }

      await Get.dialog<void>(
        AlertDialog(
          title: const Text('Enable system permissions'),
          content: Text(
            Platform.isMacOS
                ? 'To count keyboard activity reliably, macOS usually requires Accessibility '
                    'and Input Monitoring for this app.\n\n'
                    'Screenshots typically require Screen Recording permission.\n\n'
                    'We never record what you type — only numeric counters for your Work Diary slots.'
                : 'To count keyboard and mouse activity reliably, your OS may prompt for '
                    'privacy permissions depending on platform settings.\n\n'
                    'Screenshots may require screen capture permission.',
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () async {
                await NativeDesktop.openPrivacySettings();
                Get.back();
              },
              child: Text(
                Platform.isMacOS && !trusted
                    ? 'Open Privacy settings (finish Accessibility)'
                    : 'Open privacy settings',
              ),
            ),
          ],
        ),
        barrierDismissible: false,
      );
    }

    NavHelper.enterApp();
  }
}
