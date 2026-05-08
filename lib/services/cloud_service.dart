import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/supabase_env.dart';

/// Cloud-only persistence to Supabase against the v2 schema:
///
/// - `public.sessions`          — one row per work session (uuid id).
/// - `public.session_slots_10m` — one row per 10-minute slot inside a session,
///   holding aggregated keyboard / pointer / click counts, optional per-minute
///   activity mask (`active_minute_mask`), and an optional screenshot reference.
/// - Storage bucket `timetracker` — actual screenshot PNGs.
///
/// All slot writes go through the `add_slot_activity` and `set_slot_screenshot`
/// RPCs so that concurrent flushes accumulate correctly.
class CloudService {
  static const _sessionsTable = 'sessions';
  static const _slotsTable = 'session_slots_10m';
  static const _bucket = 'timetracker';

  bool get available =>
      SupabaseEnv.configured && SupabaseEnv.client.auth.currentUser != null;

  String get _userId => SupabaseEnv.client.auth.currentUser!.id;

  /// Floors [t] to the start of its 10-minute slot in local time.
  static DateTime slotStartFor(DateTime t) {
    final m = (t.minute ~/ 10) * 10;
    return DateTime(t.year, t.month, t.day, t.hour, m);
  }

  /// Ensures a `session_slots_10m` row exists for the given slot.
  ///
  /// This is used to keep the Work Diary timeline stable even when activity
  /// counters are 0 (e.g. permissions not granted yet). The row uses defaults
  /// (all counters 0) and can be incremented later via `add_slot_activity`.
  Future<void> ensureSlotExists({
    required String sessionId,
    required DateTime slotStart,
  }) async {
    if (!available) return;
    final payload = <String, dynamic>{
      'user_id': _userId,
      'session_id': sessionId,
      'slot_start': slotStart.toUtc().toIso8601String(),
    };
    try {
      // Upsert must target the unique constraint (user_id, session_id, slot_start).
      // Default upsert conflicts only on primary key and will throw 23505 here.
      await SupabaseEnv.client.from(_slotsTable).upsert(
            payload,
            onConflict: 'user_id,session_id,slot_start',
          );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CloudService.ensureSlotExists failed: $e');
      }
    }
  }

  /// Inserts a session, or updates it if [sessionId] already exists.
  Future<void> upsertSession({
    required String sessionId,
    required String title,
    required DateTime startedAt,
    DateTime? endedAt,
    required bool isActive,
  }) async {
    if (!available) return;
    final payload = <String, dynamic>{
      'id': sessionId,
      'user_id': _userId,
      'title': title,
      'started_at': startedAt.toUtc().toIso8601String(),
      'ended_at': endedAt?.toUtc().toIso8601String(),
      'is_active': isActive,
    };
    await SupabaseEnv.client.from(_sessionsTable).upsert(payload);
  }

  /// Atomically increments the activity counters on the matching slot row,
  /// creating it if it doesn't exist yet.
  Future<void> addSlotActivity({
    required String sessionId,
    required DateTime slotStart,
    required int keyboardCount,
    required int pointerCount,
    int mouseMoveCount = 0,
    int scrollCount = 0,
    int clickCount = 0,
    int idleSeconds = 0,
    int activeMinuteMask = 0,
  }) async {
    if (!available) return;
    final mask = activeMinuteMask & 1023;
    if (keyboardCount <= 0 &&
        pointerCount <= 0 &&
        mouseMoveCount <= 0 &&
        scrollCount <= 0 &&
        clickCount <= 0 &&
        idleSeconds <= 0 &&
        mask == 0) {
      return;
    }
    final base = <String, dynamic>{
      'p_session_id': sessionId,
      'p_slot_start': slotStart.toUtc().toIso8601String(),
      'p_keyboard': keyboardCount,
      'p_pointer': pointerCount,
    };

    // Backward-compatible RPC calling:
    // - newest: + clicks + idle_seconds + active_minute_mask
    // - older: may not have idle_seconds / active_minute_mask columns/params yet.
    final candidates = <Map<String, dynamic>>[
      {
        ...base,
        'p_mouse_moves': mouseMoveCount,
        'p_scroll': scrollCount,
        'p_clicks': clickCount,
        'p_idle_seconds': idleSeconds,
        'p_active_minute_mask': mask,
      },
      {
        ...base,
        'p_mouse_moves': mouseMoveCount,
        'p_scroll': scrollCount,
        'p_clicks': clickCount,
        'p_idle_seconds': idleSeconds,
      },
      {
        ...base,
        'p_clicks': clickCount,
      },
      base,
    ];

    Object? lastErr;
    for (final params in candidates) {
      try {
        await SupabaseEnv.client.rpc('add_slot_activity', params: params);
        return;
      } catch (e) {
        lastErr = e;
      }
    }

    if (kDebugMode && lastErr != null) {
      debugPrint('CloudService.addSlotActivity failed: $lastErr');
    }
  }

  /// Uploads [filePath] to Supabase Storage, then upserts the slot's screenshot
  /// reference. The local PNG is deleted once the upload succeeds.
  Future<void> uploadScreenshotForSlot({
    required String sessionId,
    required DateTime slotStart,
    required String filePath,
    required DateTime capturedAt,
  }) async {
    if (!available) return;
    final file = File(filePath);
    if (!file.existsSync()) return;

    final slotKeyMs = slotStart.toUtc().millisecondsSinceEpoch;
    final relativePath = '$_userId/$sessionId/$slotKeyMs.png';

    await SupabaseEnv.client.storage.from(_bucket).upload(
          relativePath,
          file,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );

    await SupabaseEnv.client.rpc(
      'set_slot_screenshot',
      params: <String, dynamic>{
        'p_session_id': sessionId,
        'p_slot_start': slotStart.toUtc().toIso8601String(),
        'p_storage_path': relativePath,
        'p_captured_at': capturedAt.toUtc().toIso8601String(),
      },
    );

    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Removes one slot row and its screenshot object (if any) from Storage.
  Future<void> deleteSlotById(String slotId) async {
    print('deleteSlotById: $slotId');
    if (!available) return;

    String? storagePath;
    final res = await SupabaseEnv.client
        .from(_slotsTable)
        .select('storage_path')
        .eq('id', slotId)
        .maybeSingle();
    if (res != null) {
      storagePath = (res['storage_path'] as String?)?.trim();
    }

    if (storagePath != null && storagePath.isNotEmpty) {
      try {
        print('deleteSlotById storage remove: $slotId -> $storagePath');
        await SupabaseEnv.client.storage.from(_bucket).remove([storagePath]);
      } catch (_) {
        // Storage cleanup is best-effort: still delete the row.
      }
    }

    await SupabaseEnv.client.from(_slotsTable).delete().eq('id', slotId);
    print('deleteSlotById done: $slotId');
  }

  /// Deletes a session and all its slots.
  ///
  /// DB rows: deleting the `sessions` row cascades to `session_slots_10m`.
  /// Storage: we remove any slot screenshot objects first (best-effort).
  Future<void> deleteSessionById(String sessionId) async {
    print('deleteSessionById: $sessionId');
    if (!available) return;

    final paths = <String>[];
    final res = await SupabaseEnv.client
        .from(_slotsTable)
        .select('storage_path')
        .eq('session_id', sessionId);
    for (final raw in (res as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final p = (m['storage_path'] as String?)?.trim();
      if (p != null && p.isNotEmpty) paths.add(p);
    }

    if (paths.isNotEmpty) {
      try {
        print('deleteSessionById storage remove: $sessionId -> ${paths.length} objects');
        await SupabaseEnv.client.storage.from(_bucket).remove(paths);
      } catch (_) {
        // Best-effort: still delete the DB session so UI updates.
      }
    }

    await SupabaseEnv.client.from(_sessionsTable).delete().eq('id', sessionId);
    print('deleteSessionById done: $sessionId');
  }
}
