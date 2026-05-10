import 'package:get/get.dart';

class ShellController extends GetxController {
  /// Main rail: 0 Timer, 1 Settings, 2 Account (must match [NavigationRail] destinations).
  final railIndex = 0.obs;

  /// When true, body shows Privacy; rail keeps a valid [railIndex] for Flutter asserts.
  final privacySelected = false.obs;

  /// IndexedStack index: 0–2 main tabs, 3 Privacy.
  int get bodyIndex => privacySelected.value ? 3 : railIndex.value;

  void selectRail(int i) {
    railIndex.value = i;
    privacySelected.value = false;
  }

  void selectPrivacy() {
    privacySelected.value = true;
  }
}
