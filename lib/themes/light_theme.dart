import 'package:flutter/material.dart';

import 'app_colors.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
    surface: AppColors.surfaceLight,
    primary: AppColors.primary,
  ),
  scaffoldBackgroundColor: AppColors.surfaceLight,
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.primary.withValues(alpha: 0.12),
    selectedIconTheme: const IconThemeData(color: AppColors.primary),
    selectedLabelTextStyle: const TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    ),
  ),
);
