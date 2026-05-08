import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Loads Supabase from `.env` keys `SUPABASE_URL` and `SUPABASE_ANON_KEY`, same pattern as zemen_service.
class SupabaseEnv {
  SupabaseEnv._();

  static bool configured = false;

  /// Call after [dotenv.load]. Safe to call when env vars are empty (desktop stays local-only).
  static Future<void> initializeFromEnv() async {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final anon = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (url.isEmpty || anon.isEmpty) {
      configured = false;
      return;
    }
    await Supabase.initialize(url: url, anonKey: anon);
    configured = true;
  }

  /// Only valid when [configured] is true.
  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserEmail {
    if (!configured) return null;
    return client.auth.currentUser?.email;
  }
}
