import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models/activity_models.dart';
import '../models/session_models.dart';
import '../utils/supabase_env.dart';

/// Loads Work Diary data from the v2 Supabase schema:
///   public.sessions          — `sessionsOverlappingDay`
///   public.session_slots_10m — `tryRemoteBlocks`, `rollingTenMinuteSlots`,
///                              `totalSlotSecondsInRange`
///
/// Returns empty / null when offline or unauthenticated so callers can show
/// an idle state.
class WorkDiaryRemoteService {
  WorkDiaryRemoteService._();

  static const _bucket = 'timetracker';
  static const _slotsTable = 'session_slots_10m';
  static const _sessionsTable = 'sessions';

  static final _slotSecondsCache = <String, _CacheEntry<int>>{};

  static Future<bool> _isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity.any((c) => c != ConnectivityResult.none);
  }

  static String? _userIdOrNull() {
    if (!SupabaseEnv.configured) return null;
    final u = SupabaseEnv.client.auth.currentUser;
    return u?.id;
  }

  /// Floors [t] to the start of its 10-minute slot in local time.
  static DateTime _floorToTenMin(DateTime t) {
    final m = (t.minute ~/ 10) * 10;
    return DateTime(t.year, t.month, t.day, t.hour, m);
  }

  static Future<List<Map<String, dynamic>>> _fetchSlotRows({
    required String userId,
    required String sessionId,
    required String select,
  }) async {
    final res = await SupabaseEnv.client
        .from(_slotsTable)
        .select(select)
        .eq('user_id', userId)
        .eq('session_id', sessionId)
        .order('slot_start');
    final rows = <Map<String, dynamic>>[];
    for (final raw in (res as List<dynamic>)) {
      rows.add(Map<String, dynamic>.from(raw as Map));
    }
    return rows;
  }

  /// Safe Supabase JSON integer parsing (avoids cast crashes if types drift).
  static int _asNonNegativeInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v < 0 ? 0 : v;
    if (v is num) {
      final n = v.toInt();
      return n < 0 ? 0 : n;
    }
    if (v is String) {
      final n = int.tryParse(v.trim());
      if (n == null) return 0;
      return n < 0 ? 0 : n;
    }
    return 0;
  }

  /// Returns the 10-minute Work Diary blocks for one session, or null when
  /// offline / unauthenticated.
  static Future<List<TenMinuteBlockData>?> tryRemoteBlocks({
    required String sessionId,
    required DateTime sessionStart,
    required DateTime windowEnd,
    DateTime? liveClock,
  }) async {
    final userId = _userIdOrNull();
    if (userId == null) return null;
    if (!await _isOnline()) return null;

    List<Map<String, dynamic>> rows;
    try {
      rows = await _fetchSlotRows(
        userId: userId,
        sessionId: sessionId,
        select:
            'id, slot_start, keyboard_count, pointer_count, click_count, '
            'mouse_move_count, scroll_count, '
            'idle_seconds, active_minute_mask, '
            'storage_path, captured_at',
      );
    } catch (e) {
      debugPrint(
        'WorkDiaryRemoteService.tryRemoteBlocks: full slot select failed ($e); '
        'retrying without newer columns.',
      );
      rows = await _fetchSlotRows(
        userId: userId,
        sessionId: sessionId,
        select:
            'id, slot_start, keyboard_count, pointer_count, click_count, '
            'storage_path, captured_at',
      );
    }

    return _buildBlocksFromSlots(
      sessionStart: sessionStart,
      windowEnd: windowEnd,
      liveClock: liveClock,
      slots: rows,
    );
  }

  /// Rolling last 10 minutes (one column per minute) for the Timer dashboard.
  /// Each minute borrows the per-minute share of the matching 10-minute slot.
  static Future<List<MinuteSlotData>> rollingTenMinuteSlots() async {
    final userId = _userIdOrNull();
    if (userId == null) return [];
    if (!await _isOnline()) return [];

    final now = DateTime.now();
    final origin = now.subtract(const Duration(minutes: 10));
    // Slot floors that intersect the rolling window.
    final firstSlot = _floorToTenMin(origin);
    final lastSlotExclusive =
        _floorToTenMin(now).add(const Duration(minutes: 10));

    final fromIso = firstSlot.toUtc().toIso8601String();
    final toIso = lastSlotExclusive.toUtc().toIso8601String();

    List<Map<String, dynamic>> slotRows;
    try {
      final res = await SupabaseEnv.client
          .from(_slotsTable)
          .select(
            'slot_start, keyboard_count, pointer_count, click_count, '
            'active_minute_mask, storage_path',
          )
          .eq('user_id', userId)
          .gte('slot_start', fromIso)
          .lt('slot_start', toIso)
          .order('slot_start');
      slotRows = <Map<String, dynamic>>[];
      for (final raw in (res as List<dynamic>)) {
        slotRows.add(Map<String, dynamic>.from(raw as Map));
      }
    } catch (e) {
      debugPrint(
        'WorkDiaryRemoteService.rollingTenMinuteSlots: select failed ($e); retry.',
      );
      final res = await SupabaseEnv.client
          .from(_slotsTable)
          .select(
            'slot_start, keyboard_count, pointer_count, click_count, '
            'storage_path',
          )
          .eq('user_id', userId)
          .gte('slot_start', fromIso)
          .lt('slot_start', toIso)
          .order('slot_start');
      slotRows = <Map<String, dynamic>>[];
      for (final raw in (res as List<dynamic>)) {
        slotRows.add(Map<String, dynamic>.from(raw as Map));
      }
    }

    final byStart = <int, Map<String, dynamic>>{};
    for (final m in slotRows) {
      final s = DateTime.parse(m['slot_start'] as String).toLocal();
      byStart[s.millisecondsSinceEpoch] = m;
    }

    final slots = <MinuteSlotData>[];
    for (var i = 0; i < 10; i++) {
      final a = origin.add(Duration(minutes: i));
      final slotKey = _floorToTenMin(a).millisecondsSinceEpoch;
      final row = byStart[slotKey];
      final kb = _asNonNegativeInt(row?['keyboard_count']);
      final ptr = _asNonNegativeInt(row?['pointer_count']);
      final clicks = _asNonNegativeInt(row?['click_count']);
      final mask = _asNonNegativeInt(row?['active_minute_mask']);
      final idx = a.minute % 10;
      final combined = kb + ptr + clicks;
      final activeInSlot = _popcount10(mask);
      final inactiveMinute =
          mask != 0 && ((mask >> idx) & 1) == 0;
      final activityUnits = inactiveMinute
          ? 0
          : (mask != 0
              ? (activeInSlot > 0
                  ? (combined / activeInSlot).ceil()
                  : combined ~/ 10)
              : kb ~/ 10);
      final remotePath = row?['storage_path'] as String?;
      slots.add(
        MinuteSlotData(
          slotStart: a,
          keystrokes: activityUnits,
          remoteStoragePath: remotePath,
        ),
      );
    }
    return hydrateMinuteSlots(slots);
  }

  /// Sessions whose [`started_at`, `ended_at`] window touches [day]'s local calendar day.
  static Future<List<CloudSessionRow>> sessionsOverlappingDay(
    DateTime day,
  ) async {
    final userId = _userIdOrNull();
    if (userId == null) return [];
    if (!await _isOnline()) return [];

    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final endIso = dayEnd.toUtc().toIso8601String();

    final res = await SupabaseEnv.client
        .from(_sessionsTable)
        .select('id, title, started_at, ended_at, is_active')
        .eq('user_id', userId)
        .lt('started_at', endIso)
        .order('started_at');

    final out = <CloudSessionRow>[];
    for (final raw in (res as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final startedAt = DateTime.parse(m['started_at'] as String).toLocal();
      final endedRaw = m['ended_at'];
      final endedAt = endedRaw == null
          ? null
          : DateTime.parse(endedRaw as String).toLocal();
      final overlaps = startedAt.isBefore(dayEnd) &&
          (endedAt == null || endedAt.isAfter(dayStart));
      if (!overlaps) continue;
      out.add(
        CloudSessionRow(
          id: m['id'] as String,
          title: (m['title'] as String?) ?? 'Session',
          startedAt: startedAt,
          endedAt: endedAt,
          isActive: (m['is_active'] as bool?) ?? false,
        ),
      );
    }
    return out.reversed.toList(); // newest first
  }

  /// Total seconds tracked in `[from, to)` based on distinct 10-minute slots.
  /// Each slot counts as 600 s, so deletions immediately reduce the total.
  static Future<int> totalSlotSecondsInRange(
    DateTime from,
    DateTime to,
  ) async {
    final userId = _userIdOrNull();
    if (userId == null) return 0;
    if (!await _isOnline()) return 0;

    final cacheKey =
        '${userId}_${from.toIso8601String()}_${to.toIso8601String()}';
    final cached = _slotSecondsCache[cacheKey];
    final now = DateTime.now();
    if (cached != null &&
        now.difference(cached.at) < const Duration(seconds: 5)) {
      return cached.value;
    }

    final fromIso = from.toUtc().toIso8601String();
    final toIso = to.toUtc().toIso8601String();
    final res = await SupabaseEnv.client
        .from(_slotsTable)
        .select('slot_start')
        .eq('user_id', userId)
        .gte('slot_start', fromIso)
        .lt('slot_start', toIso);

    final unique = <int>{};
    for (final raw in (res as List<dynamic>)) {
      final m = Map<String, dynamic>.from(raw as Map);
      final t = DateTime.parse(m['slot_start'] as String);
      unique.add(t.millisecondsSinceEpoch);
    }
    final secs = unique.length * 600;
    _slotSecondsCache[cacheKey] = _CacheEntry(now, secs);
    return secs;
  }

  /// Clears the totals cache so the next call re-queries Supabase.
  static void invalidateTotalsCache() {
    _slotSecondsCache.clear();
  }

  static Future<List<TenMinuteBlockData>> _buildBlocksFromSlots({
    required DateTime sessionStart,
    required DateTime windowEnd,
    DateTime? liveClock,
    required List<Map<String, dynamic>> slots,
  }) async {
    final blocks = <TenMinuteBlockData>[];
    if (!windowEnd.isAfter(sessionStart) && (liveClock == null)) {
      return blocks;
    }

    final byStart = <int, Map<String, dynamic>>{};
    for (final s in slots) {
      final k = DateTime.parse(s['slot_start'] as String)
          .toLocal()
          .millisecondsSinceEpoch;
      byStart[k] = s;
    }

    final firstBlockStart = _floorToTenMin(sessionStart);
    final lastBlockEnd = liveClock != null && liveClock.isAfter(windowEnd)
        ? _floorToTenMin(liveClock).add(const Duration(minutes: 10))
        : _floorToTenMin(windowEnd.subtract(const Duration(seconds: 1)))
            .add(const Duration(minutes: 10));

    final totalMinutes =
        lastBlockEnd.difference(firstBlockStart).inMinutes.clamp(10, 288 * 10);
    final blockCount = (totalMinutes / 10).ceil();

    for (var k = 0; k < blockCount; k++) {
      final blockStart = firstBlockStart.add(Duration(minutes: k * 10));
      final row = byStart[blockStart.millisecondsSinceEpoch];

      final keyboardTotal = _asNonNegativeInt(row?['keyboard_count']);
      final clickTotal = _asNonNegativeInt(row?['click_count']);
      final moveTotal = _asNonNegativeInt(row?['mouse_move_count']);
      final scrollTotal = _asNonNegativeInt(row?['scroll_count']);
      // Back-compat: if the split columns are missing, use pointer_count as the combined value.
      final pointerTotal = _asNonNegativeInt(row?['pointer_count']);
      final combinedPointer = (moveTotal + scrollTotal) > 0
          ? (moveTotal + scrollTotal)
          : pointerTotal;
      final mask = _asNonNegativeInt(row?['active_minute_mask']);
      final hasActivity =
          (keyboardTotal + combinedPointer + clickTotal + scrollTotal) > 0;
      final slotId = row?['id'] as String?;
      final remotePath = row?['storage_path'] as String?;

      final minuteActive =
          _minuteActiveFromMask(mask, legacyHasActivity: hasActivity);
      final activeCount = minuteActive.where((e) => e).length;
      final perMinKey =
          activeCount > 0 ? keyboardTotal ~/ activeCount : 0;
      final perMinPtr =
          activeCount > 0 ? combinedPointer ~/ activeCount : 0;
      final minuteKeyboard =
          List.generate(10, (i) => minuteActive[i] ? perMinKey : 0);
      final minutePointer =
          List.generate(10, (i) => minuteActive[i] ? perMinPtr : 0);

      String? signedUrl;
      if (remotePath != null && remotePath.isNotEmpty) {
        try {
          signedUrl = await SupabaseEnv.client.storage
              .from(_bucket)
              .createSignedUrl(remotePath, 3600);
        } catch (_) {}
      }

      final block = TenMinuteBlockData(
        blockStart: blockStart,
        minuteActive: minuteActive,
        minuteKeyboard: minuteKeyboard,
        minutePointer: minutePointer,
        slotId: slotId,
        keyboardCount: keyboardTotal,
        pointerCount: combinedPointer,
        mouseMoveCount: moveTotal,
        scrollCount: scrollTotal,
        clickCount: clickTotal,
        screenshotSignedUrl: signedUrl,
        remoteScreenshotStoragePath: remotePath,
      );
      if (!block.isVisibleInWorkDiary(windowEnd, liveClock: liveClock)) {
        continue;
      }
      blocks.add(block);
    }

    return blocks;
  }

  /// Fills [TenMinuteBlockData.screenshotSignedUrl] from Supabase Storage for
  /// blocks that only carry a `remoteScreenshotStoragePath`.
  static Future<List<TenMinuteBlockData>> hydrateTenMinuteBlocks(
    List<TenMinuteBlockData> blocks,
  ) async {
    if (!SupabaseEnv.configured ||
        SupabaseEnv.client.auth.currentUser == null) {
      return blocks;
    }
    if (!await _isOnline()) return blocks;
    final out = <TenMinuteBlockData>[];
    for (final b in blocks) {
      final existing = b.screenshotSignedUrl?.trim();
      if (existing != null && existing.isNotEmpty) {
        out.add(b);
        continue;
      }
      final remote = b.remoteScreenshotStoragePath?.trim();
      if (remote != null && remote.isNotEmpty) {
        try {
          final url = await SupabaseEnv.client.storage
              .from(_bucket)
              .createSignedUrl(remote, 3600);
          out.add(b.copyWith(screenshotSignedUrl: url));
        } catch (_) {
          out.add(b);
        }
      } else {
        out.add(b);
      }
    }
    return out;
  }

  /// Same as [hydrateTenMinuteBlocks] but for per-minute Timer strip tiles.
  static Future<List<MinuteSlotData>> hydrateMinuteSlots(
    List<MinuteSlotData> slots,
  ) async {
    if (!SupabaseEnv.configured ||
        SupabaseEnv.client.auth.currentUser == null) {
      return slots;
    }
    if (!await _isOnline()) return slots;
    final out = <MinuteSlotData>[];
    for (final s in slots) {
      final existing = s.screenshotSignedUrl?.trim();
      if (existing != null && existing.isNotEmpty) {
        out.add(s);
        continue;
      }
      final remote = s.remoteStoragePath?.trim();
      if (remote != null && remote.isNotEmpty) {
        try {
          final url = await SupabaseEnv.client.storage
              .from(_bucket)
              .createSignedUrl(remote, 3600);
          out.add(s.copyWith(screenshotSignedUrl: url));
        } catch (_) {
          out.add(s);
        }
      } else {
        out.add(s);
      }
    }
    return out;
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.at, this.value);
  final DateTime at;
  final T value;
}

int _popcount10(int m) {
  var v = m & 1023;
  var c = 0;
  while (v != 0) {
    c++;
    v &= v - 1;
  }
  return c;
}

List<bool> _minuteActiveFromMask(int mask, {required bool legacyHasActivity}) {
  if (mask != 0) {
    return List.generate(10, (i) => ((mask >> i) & 1) != 0);
  }
  return List<bool>.filled(10, legacyHasActivity);
}
