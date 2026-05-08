import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';

import 'app/routes/app_pages.dart';
import 'app/routes/app_routes.dart';
import 'services/cloud_service.dart';
import 'services/cloud_refresh_service.dart';
import 'services/hid_tracking_service.dart';
import 'services/preferences_service.dart';
import 'services/screenshot_scheduler.dart';
import 'services/session_desktop_lifecycle.dart';
import 'services/session_service.dart';
import 'themes/dark_theme.dart';
import 'themes/light_theme.dart';
import 'themes/theme_controller.dart';
import 'utils/supabase_env.dart';
import 'platform/native_desktop.dart';

/// Loads env (same pattern as zemen_service), then starts the app.
/// Use [envFile] `.env`, `.env.staging`, or `.env.production` per flavor entrypoint.
Future<void> bootstrap({required String envFile}) async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: envFile);
  await SupabaseEnv.initializeFromEnv();

  // Avoid waiting on waitUntilReadyToShow — it can hang on some desktop setups and block runApp.
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(960, 640));
    await windowManager.setSize(const Size(1100, 720));
    await windowManager.center();
    await windowManager.setTitle('ZuluTime Tracker');
    await windowManager.show();
    await windowManager.focus();
  }

  final prefs = await PreferencesService.init();
  Get.put(prefs, permanent: true);

  Get.put(CloudService(), permanent: true);
  Get.put(CloudRefreshService(), permanent: true);
  Get.put(ScreenshotScheduler(Get.find<CloudService>()), permanent: true);
  Get.put(HidTrackingService(), permanent: true);
  Get.put(SessionService(Get.find<CloudService>()), permanent: true);

  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await registerSessionDesktopLifecycle();
  }

  await Get.find<SessionService>().recoverInterruptedTrackingOnLaunch();
  await Get.find<SessionService>().hydrateFromDb();

  Get.put(ThemeController(), permanent: true);

  await Get.find<ScreenshotScheduler>().syncWithPreferences();

  _registerSupabaseAuthRouting();

  runApp(const ZuluTimeApp());

  // Request desktop permissions on launch (so starting a session is smooth).
  _maybePromptDesktopPermissionsOnLaunch();

  // Run after [runApp] so a HID / FFI failure never blocks the widget tree (blank window).
  try {
    await Get.find<HidTrackingService>().warmUp();
  } catch (e, st) {
    debugPrint('bootstrap: HidTrackingService.warmUp failed: $e\n$st');
  }
}

void _maybePromptDesktopPermissionsOnLaunch() {
  if (!Platform.isMacOS) return;
  if (!Get.isRegistered<PreferencesService>()) return;
  final prefs = Get.find<PreferencesService>();
  if (!prefs.privacyConsentAccepted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) async {
    try {
      final trusted = await NativeDesktop.isAccessibilityTrusted();
      if (!trusted) {
        // This may show the system Accessibility prompt.
        await NativeDesktop.requestAccessibilityPromptIfNeeded();
        // Also show a gentle in-app hint once per launch.
        Get.snackbar(
          'Permission needed',
          'Enable Accessibility for ZuluTime Tracker to record keyboard/mouse activity.\n'
              'System Settings → Privacy & Security → Accessibility.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 6),
        );
      }

      // Do not gate Screen Recording on CGPreflight alone — on newer macOS it can report false
      // while capture works after Settings shows Screen & System Audio Recording enabled.
    } catch (_) {}
  });
}

/// When Supabase is configured, signing out returns the user to the login screen.
void _registerSupabaseAuthRouting() {
  if (!SupabaseEnv.configured) return;
  SupabaseEnv.client.auth.onAuthStateChange.listen((AuthState data) {
    if (data.event != AuthChangeEvent.signedOut) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (!Get.isRegistered<PreferencesService>()) return;
        final prefs = Get.find<PreferencesService>();
        if (!prefs.privacyConsentAccepted) return;
        final route = Get.currentRoute;
        if (route == Routes.LOGIN ||
            route == Routes.SPLASH ||
            route == Routes.PRIVACY) {
          return;
        }
        Get.offAllNamed(Routes.LOGIN);
      } catch (_) {}
    });
  });
}

class ZuluTimeApp extends StatefulWidget {
  const ZuluTimeApp({super.key});

  @override
  State<ZuluTimeApp> createState() => _ZuluTimeAppState();
}

class _ZuluTimeAppState extends State<ZuluTimeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.microtask(
        () => Get.find<SessionService>().checkResumeGapAfterPossibleSleep(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Get.find<ThemeController>();
    return Obx(
      () => GetMaterialApp(
        title: 'ZuluTime Tracker',
        debugShowCheckedModeBanner: false,
        theme: lightTheme,
        darkTheme: darkTheme,
        themeMode: theme.themeMode.value,
        initialRoute: AppPages.INITIAL,
        getPages: AppPages.routes,
      ),
    );
  }
}
