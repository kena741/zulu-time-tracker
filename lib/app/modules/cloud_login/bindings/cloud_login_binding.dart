import 'package:get/get.dart';

import '../controllers/cloud_login_controller.dart';

class CloudLoginBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CloudLoginController());
  }
}
