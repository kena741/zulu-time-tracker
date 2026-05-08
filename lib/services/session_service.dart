import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../platform/native_desktop.dart';
import 'cloud_service.dart';
import 'hid_tracking_service.dart';
import 'preferences_service.dart';

/// Orchestrates active tracking sessions, elapsed time, and aggregated activity
/// counters which are flushed every ~30 seconds into the current 10-minute slot
/// (`public.session_slots_10m`).
class SessionService extends GetxService {
  SessionService(this._cloud);

  final CloudService _cloud;
  final _uuid = const Uuid();

  /// UUID of the active row in `public.sessions`, or null when stopped.
  final RxnString activeSessionId = RxnString();
  final RxString sessionTitle = ''.obs;
  final RxInt elapsedSeconds = 0.obs;
  final RxBool isRunning = false.obs;

  /// When the active session started (used to upsert the same session row on stop).
  final Rxn<DateTime> sessionStartedAt = Rxn<DateTime>();

  Timer? _clock;
  Timer? _activityFlush;
  Timer? _debugInputPoll;
  DateTime? _lastActivityFlushAt;
  DateTime? _lastEnsuredSlotStart;

  int _debugAccKeys = 0;
  int _debugAccMoves = 0;
  int _debugAccScroll = 0;
  int _debugAccClicks = 0;

  bool _macPermissionDialogShown = false;

  /// Updated every tick while running; used to detect machine sleep in the same process.
  DateTime? _lastWallClockTick;

  static const _resumeGapEndsSession = Duration(minutes: 3);
  static const _coldStartHeartbeatMaxAgeMs = 60000;

  @override
  void onClose() {
    _clock?.cancel();
    _activityFlush?.cancel();
    _debugInputPoll?.cancel();
    super.onClose();
  }

  /// Closes a session left active by a previous process (kill, OS shutdown).
  Future<void> recoverInterruptedTrackingOnLaunch() async {
    final prefs = Get.find<PreferencesService>();
    final hbMs = prefs.trackingHeartbeatWallMs;
    final hbSid = prefs.trackingHeartbeatSessionId;
    if (hbMs == null || hbSid == null || hbSid.isEmpty) {
      await prefs.clearTrackingHeartbeat();
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if ((nowMs - hbMs) > _coldStartHeartbeatMaxAgeMs) {
      final endedAt = DateTime.fromMillisecondsSinceEpoch(hbMs);
      try {
        await _cloud.upsertSession(
          sessionId: hbSid,
          title: sessionTitle.value,
          startedAt: endedAt,
          endedAt: endedAt,
          isActive: false,
        );
      } catch (_) {}
      await prefs.clearTrackingHeartbeat();
    }
  }

  /// Called when the app returns to [AppLifecycleState.resumed] after possible system sleep.
  Future<void> checkResumeGapAfterPossibleSleep() async {
    if (!isRunning.value) return;
    final last = _lastWallClockTick;
    if (last == null) return;
    if (DateTime.now().difference(last) > _resumeGapEndsSession) {
      await stopSession(endedAt: last);
    }
  }

  Future<void> hydrateFromDb() async {}

  Future<void> startSession(String title) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Session memo/title is required.');
    }
    if (isRunning.value) await stopSession();
    await Get.find<PreferencesService>().setSessionMemo('');
    final now = DateTime.now();
    final id = _uuid.v4();
    activeSessionId.value = id;
    sessionTitle.value = trimmed;
    sessionStartedAt.value = now;
    elapsedSeconds.value = 0;
    isRunning.value = true;
    _lastWallClockTick = now;
    _lastActivityFlushAt = now;
    _lastEnsuredSlotStart = CloudService.slotStartFor(now);
    _startClock();
    unawaited(_persistHeartbeat());
    await _maybeStartKeyboard();
    // Ensure the first slot row exists immediately so Work Diary can render it.
    unawaited(_cloud.ensureSlotExists(
      sessionId: id,
      slotStart: _lastEnsuredSlotStart!,
    ));
    try {
      await _cloud.upsertSession(
        sessionId: id,
        title: trimmed,
        startedAt: now,
        endedAt: null,
        isActive: true,
      );
    } catch (_) {}
  }

  Future<void> stopSession({DateTime? endedAt}) async {
    final id = activeSessionId.value;
    final startedAt = sessionStartedAt.value ??
        DateTime.now().subtract(Duration(seconds: elapsedSeconds.value));
    _clock?.cancel();
    _clock = null;
    _activityFlush?.cancel();
    _activityFlush = null;
    _debugInputPoll?.cancel();
    _debugInputPoll = null;
    _lastActivityFlushAt = null;
    _lastEnsuredSlotStart = null;
    _lastWallClockTick = null;
    if (id != null) {
      await _flushActivitySlice(id);
    }
    await _stopInputMonitoring();
    if (id != null) {
      try {
        await _cloud.upsertSession(
          sessionId: id,
          title: sessionTitle.value,
          startedAt: startedAt,
          endedAt: endedAt ?? DateTime.now(),
          isActive: false,
        );
      } catch (_) {}
    }
    await Get.find<PreferencesService>().clearTrackingHeartbeat();
    activeSessionId.value = null;
    sessionStartedAt.value = null;
    isRunning.value = false;
    elapsedSeconds.value = 0;
  }

  void _startClock() {
    _clock?.cancel();
    var n = 0;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!isRunning.value) return;
      final now = DateTime.now();
      final last = _lastWallClockTick;
      if (last != null && now.difference(last) > _resumeGapEndsSession) {
        // Windows sleep/resume doesn't always surface a Flutter lifecycle callback.
        // Catch it here on the first tick after wake and end the session.
        unawaited(stopSession(endedAt: last));
        return;
      }
      elapsedSeconds.value++;
      _lastWallClockTick = now;
      n++;
      if (n % 30 == 0) {
        unawaited(_persistHeartbeat());
      }
    });
  }

  Future<void> _persistHeartbeat() async {
    final id = activeSessionId.value;
    if (id == null || !isRunning.value) return;
    await Get.find<PreferencesService>().setTrackingHeartbeat(
      sessionId: id,
      wallMs: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _maybeStartKeyboard() async {
    _activityFlush?.cancel();
    if (!isRunning.value) {
      await _stopInputMonitoring();
      return;
    }
    await _startInputMonitoring();
    _lastActivityFlushAt = DateTime.now();
    _activityFlush = Timer.periodic(const Duration(seconds: 30), (_) async {
      final sid = activeSessionId.value;
      if (sid == null || !isRunning.value) return;
      await _flushActivitySlice(sid);
    });
  }

  Future<void> _startInputMonitoring() async {
    await NativeDesktop.stopKeyboardMonitoring();
    if (Platform.isMacOS) {
      // macOS global input monitors may require Accessibility trust.
      final trusted = await NativeDesktop.isAccessibilityTrusted();
      if (kDebugMode) debugPrint('macOS Accessibility trusted: $trusted');
      if (!trusted) {
        // Best-effort: prompt + open settings so the user can enable the app.
        // Note: Keyboard capture is often gated by Privacy & Security → Input Monitoring.
        await NativeDesktop.requestAccessibilityPromptIfNeeded();
        unawaited(NativeDesktop.openPrivacySettings());
        if (kDebugMode) {
          debugPrint(
            'macOS permission needed: enable this app under Privacy & Security → Input Monitoring '
            '(and/or Accessibility), then re-launch.',
          );
        }

        if (!_macPermissionDialogShown) {
          _macPermissionDialogShown = true;
          // No BuildContext needed: GetX can present dialogs globally.
          Get.dialog(
            AlertDialog(
              title: const Text('Permission needed for keyboard tracking'),
              content: const Text(
                'To count keyboard activity on macOS, enable this app in:\n\n'
                'System Settings → Privacy & Security → Input Monitoring\n'
                '(and sometimes also Accessibility).\n\n'
                'After enabling, quit and re-launch the app.',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    await NativeDesktop.openPrivacySettings();
                  },
                  child: const Text('Open Settings'),
                ),
                TextButton(
                  onPressed: () async {
                    Get.back();
                    // Re-check + restart monitoring (still may require relaunch).
                    await refreshKeyboardToggle();
                  },
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () {
                    Get.back();
                  },
                  child: const Text('Not now'),
                ),
              ],
            ),
            barrierDismissible: true,
          );
        }
      }
    }
    final hid = Get.isRegistered<HidTrackingService>()
        ? Get.find<HidTrackingService>()
        : null;
    await hid?.warmUp();
    if (hid != null && hid.isReady) {
      hid.setRecording(true);
      return;
    }
    final ok = await NativeDesktop.startKeyboardMonitoring();
    if (kDebugMode) {
      debugPrint('NativeDesktop.startKeyboardMonitoring ok=$ok');
    }

    // Debug-only: poll every second so you see activity immediately in the terminal.
    // We accumulate the polled values and let the normal 30s flush send the totals.
    if (kDebugMode) {
      _debugInputPoll?.cancel();
      _debugAccKeys = 0;
      _debugAccMoves = 0;
      _debugAccScroll = 0;
      _debugAccClicks = 0;
      _debugInputPoll = Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!isRunning.value) return;
        final keys = await NativeDesktop.getKeyboardCountAndReset();
        final p = await NativeDesktop.getPointerBreakdownAndReset();
        final moves = p['moves'] ?? 0;
        final scroll = p['scroll'] ?? 0;
        final clicks = p['clicks'] ?? 0;

        _debugAccKeys += keys;
        _debugAccMoves += moves;
        _debugAccScroll += scroll;
        _debugAccClicks += clicks;

        if ((keys + moves + scroll + clicks) > 0) {
          debugPrint(
            'LIVE input (1s): keys=$keys moves=$moves scroll=$scroll clicks=$clicks',
          );
        }
      });
    }
  }

  Future<void> _stopInputMonitoring() async {
    if (Get.isRegistered<HidTrackingService>()) {
      Get.find<HidTrackingService>().setRecording(false);
    }
    _debugInputPoll?.cancel();
    _debugInputPoll = null;
    await NativeDesktop.stopKeyboardMonitoring();
  }

  Future<void> refreshKeyboardToggle() => _maybeStartKeyboard();

  static int _minuteMaskForRange(DateTime a, DateTime b) {
    if (!b.isAfter(a)) return 0;
    final start = DateTime(a.year, a.month, a.day, a.hour, a.minute);
    final end = DateTime(b.year, b.month, b.day, b.hour, b.minute);
    var cur = start;
    var mask = 0;
    while (!cur.isAfter(end)) {
      mask |= (1 << (cur.minute % 10));
      cur = cur.add(const Duration(minutes: 1));
    }
    return mask & 1023;
  }

  /// Adds the latest 30-second counters into the current 10-minute slot row.
  Future<void> _flushActivitySlice(String sessionId) async {
    const flushWindowSeconds = 30;
    var keys = 0;
    var pointer = 0;
    var clicks = 0;
    var minuteMask = 0;
    var moves = 0;
    var scroll = 0;
    final now = DateTime.now();
    final prevFlushAt =
        _lastActivityFlushAt ?? now.subtract(const Duration(seconds: 30));
    _lastActivityFlushAt = now;
    final slotStart = CloudService.slotStartFor(now);
    if (_lastEnsuredSlotStart == null ||
        _lastEnsuredSlotStart!.millisecondsSinceEpoch !=
            slotStart.millisecondsSinceEpoch) {
      _lastEnsuredSlotStart = slotStart;
      // If a new 10-min window started, ensure a row exists even before activity arrives.
      unawaited(_cloud.ensureSlotExists(sessionId: sessionId, slotStart: slotStart));
    }

    final hid = Get.isRegistered<HidTrackingService>()
        ? Get.find<HidTrackingService>()
        : null;
    if (hid != null && hid.isReady) {
      final slice = hid.consumePendingSlice();
      keys = slice.keyboard;
      pointer = slice.pointer;
      clicks = slice.clicks;
      minuteMask = slice.minuteMask;
    } else {
      if (kDebugMode && _debugInputPoll != null) {
        // Debug polling already resets native counters every second; just flush accumulated totals.
        keys = _debugAccKeys;
        moves = _debugAccMoves;
        scroll = _debugAccScroll;
        clicks = _debugAccClicks;
        _debugAccKeys = 0;
        _debugAccMoves = 0;
        _debugAccScroll = 0;
        _debugAccClicks = 0;
      } else {
        keys = await NativeDesktop.getKeyboardCountAndReset();
        final breakdown = await NativeDesktop.getPointerBreakdownAndReset();
        moves = breakdown['moves'] ?? 0;
        scroll = breakdown['scroll'] ?? 0;
        clicks = breakdown['clicks'] ?? 0;
      }
      pointer = moves + scroll;
      if ((keys + pointer) > 0) {
        minuteMask = _minuteMaskForRange(prevFlushAt, now);
      }
      if (kDebugMode && (keys > 0)) {
        debugPrint('SessionService input flush: keys=$keys (native)');
      }
    }
    try {
      final slot = slotStart;
      // Minimal idle detection:
      // - if we recorded any input in this flush window, idleSeconds=0
      // - otherwise, if the OS reports idle >= flushWindowSeconds, count the whole window as idle
      var idleSeconds = 0;
      if (keys <= 0 && pointer <= 0 && clicks <= 0 && minuteMask == 0) {
        final osIdle = await NativeDesktop.getIdleSeconds();
        if (osIdle >= flushWindowSeconds) {
          idleSeconds = flushWindowSeconds;
        }
      }
      await _cloud.addSlotActivity(
        sessionId: sessionId,
        slotStart: slot,
        keyboardCount: keys,
        pointerCount: pointer,
        clickCount: clicks,
        mouseMoveCount: moves,
        scrollCount: scroll,
        idleSeconds: idleSeconds,
        activeMinuteMask: minuteMask,
      );
    } catch (e) {
      // Drop on failure; the next flush will pick up new counters.
      // In debug builds, surface the error so schema/RPC mismatches are obvious.
      assert(() {
        // ignore: avoid_print
        print('SessionService _flushActivitySlice failed: $e');
        return true;
      }());
    }
  }
}
