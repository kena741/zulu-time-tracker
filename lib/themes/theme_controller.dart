import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ThemeController extends GetxController {
  final Rx<ThemeMode> themeMode = ThemeMode.dark.obs;

  void setLight() => themeMode.value = ThemeMode.light;

  void setDark() => themeMode.value = ThemeMode.dark;

  void useSystem() => themeMode.value = ThemeMode.system;
}
