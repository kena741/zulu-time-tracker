import 'package:get/get.dart';

import '../../services/preferences_service.dart';
import '../../utils/supabase_env.dart';
import '../routes/app_routes.dart';

class NavHelper {
  NavHelper._();

  /// Cold start: splash → privacy → email/password login (if required) → shell.
  static void routeFromSplash() {
    final prefs = Get.find<PreferencesService>();
    if (!prefs.privacyConsentAccepted) {
      Get.offAllNamed(Routes.PRIVACY);
      return;
    }
    if (_needsEmailPasswordLogin()) {
      Get.offAllNamed(Routes.LOGIN);
      return;
    }
    Get.offAllNamed(Routes.SHELL);
  }

  /// After privacy consent is granted, route to login or shell.
  static void enterApp() {
    if (_needsEmailPasswordLogin()) {
      Get.offAllNamed(Routes.LOGIN);
      return;
    }
    Get.offAllNamed(Routes.SHELL);
  }

  /// Supabase: must have a session. Local: optional auth enabled and not signed in.
  static bool _needsEmailPasswordLogin() {
    if (!SupabaseEnv.configured) return true;
    return SupabaseEnv.client.auth.currentUser == null;
  }
}
