import 'package:get/get.dart';

/// Simple epoch counter to force UI to refresh after cloud mutations.
class CloudRefreshService extends GetxService {
  final RxInt epoch = 0.obs;
  void bump() => epoch.value++;
}

