import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/supabase_env.dart';
import '../../../routes/app_routes.dart';

/// Email + password sign-in: Supabase when configured, otherwise local [AuthService] demo users.
class CloudLoginController extends GetxController {
  final email = TextEditingController();
  final password = TextEditingController();
  final loading = false.obs;
  final obscurePassword = true.obs;

  @override
  void onInit() {
    super.onInit();
    if (!SupabaseEnv.configured) {
      email.text = 'user@local';
    }
  }

  void toggleObscurePassword() => obscurePassword.toggle();

  Future<void> submit() async {
    final trimmed = email.text.trim();
    if (trimmed.isEmpty || password.text.isEmpty) {
      Get.snackbar('Sign in', 'Enter both email and password.');
      return;
    }

    if (!SupabaseEnv.configured) {
      Get.snackbar(
        'Supabase not configured',
        'Add SUPABASE_URL and SUPABASE_ANON_KEY to assets .env.',
      );
      return;
    }

    loading.value = true;
    try {
      await SupabaseEnv.client.auth.signInWithPassword(
        email: trimmed,
        password: password.text,
      );
      loading.value = false;
      Get.offAllNamed(Routes.SHELL);
    } on AuthException catch (e) {
      Get.snackbar('Sign in failed', e.message);
    } finally {
      if (!isClosed) loading.value = false;
    }
  }

  @override
  void onClose() {
    final e = email;
    final p = password;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      e.dispose();
      p.dispose();
    });
    super.onClose();
  }
}
