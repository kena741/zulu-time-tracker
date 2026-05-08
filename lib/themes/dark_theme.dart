import 'package:flutter/material.dart';

import 'app_colors.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.royalGreen,
    onPrimary: const Color(0xFF0D0D0D),
    primaryContainer: AppColors.royalGreen.withValues(alpha: 0.18),
    onPrimaryContainer: AppColors.royalGreen,
    secondary: AppColors.royalGreen.withValues(alpha: 0.85),
    onSecondary: Colors.black,
    surface: AppColors.surfaceDark,
    onSurface: Colors.white,
    onSurfaceVariant: const Color(0xFFB0B0B0),
    surfaceContainerHighest: AppColors.surfaceRaised,
    outline: const Color(0xFF3D3D3D),
    outlineVariant: const Color(0xFF2C2C2C),
    error: const Color(0xFFFFB4AB),
    onError: const Color(0xFF690005),
  ),
  scaffoldBackgroundColor: AppColors.surfaceDark,
  appBarTheme: const AppBarTheme(
    elevation: 0,
    centerTitle: true,
    scrolledUnderElevation: 0,
  ),
  navigationRailTheme: NavigationRailThemeData(
    backgroundColor: AppColors.surfaceRaised,
    indicatorColor: AppColors.royalGreen.withValues(alpha: 0.16),
    selectedIconTheme: const IconThemeData(color: AppColors.royalGreen),
    selectedLabelTextStyle: const TextStyle(
      color: AppColors.royalGreen,
      fontWeight: FontWeight.w600,
    ),
    unselectedIconTheme: IconThemeData(
      color: Colors.white.withValues(alpha: 0.72),
    ),
    unselectedLabelTextStyle: TextStyle(
      color: Colors.white.withValues(alpha: 0.72),
    ),
  ),
);
