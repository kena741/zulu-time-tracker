import 'dart:io';

/// One minute in the rolling activity strip (Timer dashboard).
///
/// Remote rows include `active_minute_mask` for real per-minute activity; the
/// strip maps each column to one minute and scales activity vs the busiest minute.
class MinuteSlotData {
  MinuteSlotData({
    required this.slotStart,
    required this.keystrokes,
    this.screenshotPath,
    this.remoteStoragePath,
    this.screenshotSignedUrl,
  });

  final DateTime slotStart;
  final int keystrokes;
  final String? screenshotPath;

  /// Supabase Storage object path when the PNG was uploaded.
  final String? remoteStoragePath;
  final String? screenshotSignedUrl;

  MinuteSlotData copyWith({String? screenshotSignedUrl}) {
    return MinuteSlotData(
      slotStart: slotStart,
      keystrokes: keystrokes,
      screenshotPath: screenshotPath,
      remoteStoragePath: remoteStoragePath,
      screenshotSignedUrl: screenshotSignedUrl ?? this.screenshotSignedUrl,
    );
  }
}

/// One 10-minute Work Diary column.
///
/// In the v2 schema each block corresponds to exactly one row in
/// `session_slots_10m`. [slotId] is the UUID of that row, used to delete or
/// update the slot. When [slotId] is null the slot has not been written yet
/// (no activity / screenshot for that 10-minute window).
class TenMinuteBlockData {
  TenMinuteBlockData({
    required this.blockStart,
    required this.minuteActive,
    List<int>? minuteKeyboard,
    List<int>? minutePointer,
    this.slotId,
    this.keyboardCount = 0,
    this.pointerCount = 0,
    this.mouseMoveCount = 0,
    this.scrollCount = 0,
    this.clickCount = 0,
    this.screenshotPath,
    this.screenshotSignedUrl,
    this.remoteScreenshotStoragePath,
  })  : minuteKeyboard = minuteKeyboard ?? List<int>.filled(10, 0),
        minutePointer = minutePointer ?? List<int>.filled(10, 0);

  final DateTime blockStart;
  final List<bool> minuteActive;

  /// Per-minute keyboard counts (length 10) — from slot total spread across
  /// minutes marked active in `active_minute_mask` when present.
  final List<int> minuteKeyboard;

  /// Per-minute pointer counts (length 10), same derivation as [minuteKeyboard].
  final List<int> minutePointer;

  /// Slot UUID in `session_slots_10m`. Null when no row exists for this block.
  final String? slotId;

  /// Aggregated counters for the slot.
  final int keyboardCount;
  final int pointerCount;
  final int mouseMoveCount;
  final int scrollCount;
  final int clickCount;

  final String? screenshotPath;

  /// Signed Storage URL when loaded from Supabase (preferred over [screenshotPath]).
  final String? screenshotSignedUrl;

  /// Supabase Storage path for the screenshot when uploaded.
  final String? remoteScreenshotStoragePath;

  bool isVisibleInWorkDiary(DateTime windowEnd, {DateTime? liveClock}) {
    if (liveClock != null) {
      final blockEnd = blockStart.add(const Duration(minutes: 10));
      if (!liveClock.isBefore(blockStart) && liveClock.isBefore(blockEnd)) {
        return true;
      }
    }
    // Any row in `session_slots_10m` (idle-only, partial minute mask, etc.) should
    // still render a column if it overlaps the diary window.
    if (slotId != null && blockStart.isBefore(windowEnd)) {
      return true;
    }
    for (var i = 0; i < 10; i++) {
      final minuteStart = blockStart.add(Duration(minutes: i));
      if (!minuteStart.isBefore(windowEnd)) break;
      if (minuteActive[i]) return true;
    }
    if (screenshotSignedUrl != null && screenshotSignedUrl!.trim().isNotEmpty) {
      return true;
    }
    if (screenshotPath != null && screenshotPath!.trim().isNotEmpty) {
      final f = File(screenshotPath!);
      if (f.existsSync()) return true;
    }
    if (remoteScreenshotStoragePath != null &&
        remoteScreenshotStoragePath!.trim().isNotEmpty) {
      return true;
    }
    return false;
  }

  TenMinuteBlockData copyWith({
    String? screenshotSignedUrl,
    String? screenshotPath,
    String? remoteScreenshotStoragePath,
  }) {
    return TenMinuteBlockData(
      blockStart: blockStart,
      minuteActive: minuteActive,
      minuteKeyboard: minuteKeyboard,
      minutePointer: minutePointer,
      slotId: slotId,
      keyboardCount: keyboardCount,
      pointerCount: pointerCount,
      mouseMoveCount: mouseMoveCount,
      scrollCount: scrollCount,
      clickCount: clickCount,
      screenshotPath: screenshotPath ?? this.screenshotPath,
      screenshotSignedUrl: screenshotSignedUrl ?? this.screenshotSignedUrl,
      remoteScreenshotStoragePath:
          remoteScreenshotStoragePath ?? this.remoteScreenshotStoragePath,
    );
  }
}
