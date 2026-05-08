import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../services/preferences_service.dart';
import '../../../../themes/theme_controller.dart';

class SettingsController extends GetxController {
  final prefs = Get.find<PreferencesService>();

  void setThemeMode(ThemeMode mode) {
    Get.find<ThemeController>().themeMode.value = mode;
  }
}
