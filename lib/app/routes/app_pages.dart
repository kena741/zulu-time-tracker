import 'package:get/get.dart';

import '../modules/cloud_login/bindings/cloud_login_binding.dart';
import '../modules/cloud_login/views/cloud_login_view.dart';
import '../modules/privacy_screen/bindings/privacy_binding.dart';
import '../modules/privacy_screen/views/privacy_view.dart';
import '../modules/shell_screen/bindings/shell_binding.dart';
import '../modules/shell_screen/views/shell_view.dart';
import '../modules/splash_screen/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = <GetPage>[
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashView(),
    ),
    GetPage(
      name: Routes.PRIVACY,
      page: () => const PrivacyView(),
      binding: PrivacyBinding(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const CloudLoginView(),
      binding: CloudLoginBinding(),
    ),
    GetPage(
      name: Routes.AUTH,
      page: () => const CloudLoginView(),
      binding: CloudLoginBinding(),
    ),
    GetPage(
      name: Routes.SHELL,
      page: () => const ShellView(),
      binding: ShellBinding(),
    ),
  ];
}
