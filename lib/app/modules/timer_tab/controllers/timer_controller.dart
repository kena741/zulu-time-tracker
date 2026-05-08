import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../services/session_service.dart';

class TimerController extends GetxController {
  final SessionService session = Get.find();
  late final TextEditingController titleEdit;

  static DateTime _dateOnly(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Local calendar day for Work Diary history and daily total on the Time tab.
  final diaryDate = _dateOnly(DateTime.now()).obs;

  void setDiaryDate(DateTime day) {
    diaryDate.value = _dateOnly(day);
  }

  @override
  void onInit() {
    titleEdit = TextEditingController();
    super.onInit();
  }

  @override
  void onReady() {
    if (!session.isRunning.value) {
      titleEdit.text = session.sessionTitle.value;
    }
    super.onReady();
  }

  Future<void> toggle() async {
    if (session.isRunning.value) {
      await session.stopSession();
    } else {
      final name = titleEdit.text.trim();
      if (name.isEmpty) {
        Get.snackbar(
          'Memo required',
          'Please enter a work memo before starting a session.',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 2),
        );
        return;
      }
      await session.startSession(name);
    }
  }

  @override
  void onClose() {
    final t = titleEdit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      t.dispose();
    });
    super.onClose();
  }
}
