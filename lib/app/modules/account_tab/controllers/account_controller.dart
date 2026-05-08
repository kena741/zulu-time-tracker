import 'dart:async';

import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../data/models/employee_profile.dart';
import '../../../../utils/supabase_env.dart';

/// Loads `public.employees` for the signed-in Supabase user (Account tab).
class AccountController extends GetxController {
  final loading = false.obs;
  final errorMessage = RxnString();
  final profile = Rxn<EmployeeProfile>();

  StreamSubscription<AuthState>? _authSub;

  @override
  void onInit() {
    super.onInit();
    if (SupabaseEnv.configured) {
      _authSub = SupabaseEnv.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          fetchProfile();
        }
        if (data.event == AuthChangeEvent.signedOut) {
          profile.value = null;
          errorMessage.value = null;
        }
      });
    }
  }

  @override
  void onReady() {
    super.onReady();
    fetchProfile();
  }

  @override
  void onClose() {
    _authSub?.cancel();
    super.onClose();
  }

  Future<void> fetchProfile() async {
    errorMessage.value = null;
    if (!SupabaseEnv.configured) {
      profile.value = null;
      return;
    }
    final uid = SupabaseEnv.client.auth.currentUser?.id;
    if (uid == null) {
      profile.value = null;
      return;
    }

    loading.value = true;
    try {
      final row = await SupabaseEnv.client
          .from('employees')
          .select()
          .eq('user_id', uid)
          .maybeSingle();

      if (row == null) {
        profile.value = null;
        return;
      }
      profile.value = EmployeeProfile.fromJson(
        Map<String, dynamic>.from(row as Map<dynamic, dynamic>),
      );
    } on PostgrestException catch (e) {
      errorMessage.value = e.message;
      profile.value = null;
    } catch (e) {
      errorMessage.value = '$e';
      profile.value = null;
    } finally {
      loading.value = false;
    }
  }
}
