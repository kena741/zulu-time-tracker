import 'package:get/get.dart';

import '../../account_tab/controllers/account_controller.dart';
import '../../settings_tab/controllers/settings_controller.dart';
import '../../timer_tab/controllers/timer_controller.dart';
import '../controllers/shell_controller.dart';

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(ShellController.new);
    Get.lazyPut(TimerController.new);
    Get.lazyPut(SettingsController.new);
    Get.lazyPut(AccountController.new);
  }
}
