import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../models/activity_models.dart';
import '../../models/session_models.dart';
import '../../services/cloud_refresh_service.dart';
import '../../services/cloud_service.dart';
import '../../services/session_service.dart';
import '../../services/work_diary_remote_service.dart';
import '../../themes/app_colors.dart';
import '../../utils/supabase_env.dart';
import '../modules/timer_tab/controllers/timer_controller.dart';

String _fmtHrs(int elapsedSecs) {
  final h = elapsedSecs ~/ 3600;
  final m = (elapsedSecs % 3600) ~/ 60;
  return '$h:${m.toString().padLeft(2, '0')} hrs';
}

Future<void> _deleteSlotById(String slotId) async {
  if (!SupabaseEnv.configured || SupabaseEnv.client.auth.currentUser == null) {
    return;
  }
  await Get.find<CloudService>().deleteSlotById(slotId);
}

void _showActivityLevelDetail(
  BuildContext context,
  TenMinuteBlockData block,
  DateTime windowEnd,
) {
  final cs = Theme.of(context).colorScheme;
  final df = DateFormat('h:mm a');
  final activeCount = block.minuteActive.where((e) => e).length;
  final blockEnd = block.blockStart.add(const Duration(minutes: 10));

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    '10-minute slot',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    activeCount > 0 ? 'Active' : 'Idle',
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: activeCount > 0
                              ? AppColors.royalGreen
                              : cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${df.format(block.blockStart)} – ${df.format(blockEnd)}',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _activityDetailImage(block, cs),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (var i = 0; i < 10; i++) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      child: Container(
                        height: 12,
                        color: _minuteBarColor(block, i, windowEnd),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Activity totals',
                style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              _CountTile(
                icon: Icons.keyboard_outlined,
                label: 'Keyboard',
                value: block.keyboardCount,
              ),
              const SizedBox(height: 6),
              _CountTile(
                icon: Icons.mouse_outlined,
                label: 'Mouse move',
                value: block.mouseMoveCount > 0
                    ? block.mouseMoveCount
                    : (block.pointerCount - block.clickCount).clamp(0, 1 << 30),
              ),
              const SizedBox(height: 6),
              _CountTile(
                icon: Icons.swap_vert_outlined,
                label: 'Scroll',
                value: block.scrollCount,
              ),
              const SizedBox(height: 6),
              _CountTile(
                icon: Icons.touch_app_outlined,
                label: 'Clicks',
                value: block.clickCount,
              ),
              const SizedBox(height: 12),
              Text(
                'Counts are aggregated for this 10-minute slot. Green minute '
                'bars use real activity timing (keyboard / mouse / wheel / clicks). '
                'We never store keystroke contents or cursor positions.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Color _minuteBarColor(
  TenMinuteBlockData block,
  int index,
  DateTime windowEnd,
) {
  final minuteStart = block.blockStart.add(Duration(minutes: index));
  if (!minuteStart.isBefore(windowEnd)) {
    return const Color(0xFF383838);
  }
  return block.minuteActive[index]
      ? AppColors.royalGreen
      : const Color(0xFF383838);
}

Widget _activityDetailImage(TenMinuteBlockData block, ColorScheme cs) {
  if (block.screenshotSignedUrl != null) {
    return Image.network(
      block.screenshotSignedUrl!,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => ColoredBox(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.broken_image_outlined, color: cs.outline),
      ),
    );
  }
  final path = block.screenshotPath;
  if (path != null && File(path).existsSync()) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => Icon(Icons.broken_image_outlined),
    );
  }
  return ColoredBox(
    color: cs.surfaceContainerHighest,
    child: Icon(Icons.desktop_windows_outlined, color: cs.outline, size: 48),
  );
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Upwork-style Work Diary: per-session 10-minute columns from `session_slots_10m`.
/// Each column shows the latest screenshot and ten 1-minute activity flags
/// (full royal green = activity in this slot, dark grey = idle / not yet elapsed).
class WorkDiaryPanel extends StatefulWidget {
  const WorkDiaryPanel({super.key});

  @override
  State<WorkDiaryPanel> createState() => _WorkDiaryPanelState();
}

class _WorkDiaryPanelState extends State<WorkDiaryPanel> {
  Timer? _timer;
  Future<List<CloudSessionRow>>? _sessionsFuture;
  DateTime? _sessionsDayLoaded;
  int? _sessionsEpochLoaded;

  Future<List<TenMinuteBlockData>?>? _activeBlocksFuture;
  String? _activeBlocksSessionId;
  int? _activeBlocksEpochLoaded;

  @override
  void initState() {
    super.initState();
    _sessionsFuture = _loadSessions();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final s = Get.find<SessionService>();
      if (!mounted) return;
      if (s.isRunning.value) {
        setState(() {});
      }
    });
  }

  Future<List<CloudSessionRow>> _loadSessions() async {
    final tc = Get.find<TimerController>();
    final day = tc.diaryDate.value;
    return WorkDiaryRemoteService.sessionsOverlappingDay(day);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmtDurationHours(int elapsedSecs) => _fmtHrs(elapsedSecs);

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final cs = Theme.of(context).colorScheme;
    final jm = DateFormat.jm();

    return Obx(() {
      final tc = Get.find<TimerController>();
      final diaryDay = tc.diaryDate.value;
      session.isRunning.value;
      session.elapsedSeconds.value;
      // Reload sessions list when cloud data mutates (e.g. after slot delete).
      final epoch = Get.find<CloudRefreshService>().epoch.value;
      if (_sessionsFuture == null ||
          _sessionsDayLoaded == null ||
          _sessionsEpochLoaded == null ||
          !DateUtils.isSameDay(_sessionsDayLoaded, diaryDay) ||
          _sessionsEpochLoaded != epoch) {
        _sessionsDayLoaded = diaryDay;
        _sessionsEpochLoaded = epoch;
        _sessionsFuture = _loadSessions();
      }
      return FutureBuilder<List<CloudSessionRow>>(
        future: _sessionsFuture,
        builder: (context, snap) {
          final dayHeading =
              'Sessions on ${DateFormat.yMMMEd().format(diaryDay)}';
          final sections = <Widget>[];

          final sessions = snap.data ?? const <CloudSessionRow>[];
          final activeId = session.activeSessionId.value;
          final running = session.isRunning.value;
          final pastSessions = running && activeId != null
              ? sessions.where((s) => s.id != activeId).toList()
              : sessions;

          if (running && activeId != null) {
            final now = DateTime.now();
            final startedAt = session.sessionStartedAt.value ??
                now.subtract(Duration(seconds: session.elapsedSeconds.value));

            // IMPORTANT: Do not recreate this Future on every tick. This widget rebuilds
            // frequently (elapsedSeconds), so we cache and only refresh on epoch/session change.
            if (_activeBlocksFuture == null ||
                _activeBlocksSessionId != activeId ||
                _activeBlocksEpochLoaded != epoch) {
              _activeBlocksSessionId = activeId;
              _activeBlocksEpochLoaded = epoch;
              _activeBlocksFuture = WorkDiaryRemoteService.tryRemoteBlocks(
                sessionId: activeId,
                sessionStart: startedAt,
                windowEnd: now,
                liveClock: now,
              );
            }
            sections.add(
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.royalGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Current session · ${session.sessionTitle.value}',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete session',
                          icon: Icon(Icons.delete_outline, color: cs.error),
                          onPressed: () async {
                            final sid = session.activeSessionId.value;
                            if (sid == null) return;
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete session?'),
                                content: const Text(
                                  'Remove the current session and all of its 10-minute slots (including screenshots). This cannot be undone.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: cs.error,
                                      foregroundColor: cs.onError,
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete session'),
                                  ),
                                ],
                              ),
                            );
                            if (ok != true || !context.mounted) return;
                            try {
                              await session.stopSession();
                              print('UI delete session: $sid');
                              await Get.find<CloudService>()
                                  .deleteSessionById(sid);
                              WorkDiaryRemoteService.invalidateTotalsCache();
                              Get.find<CloudRefreshService>().bump();
                              Get.snackbar(
                                'Deleted',
                                'Session removed.',
                                snackPosition: SnackPosition.BOTTOM,
                                duration: const Duration(seconds: 2),
                              );
                            } catch (e) {
                              Get.snackbar(
                                'Delete failed',
                                '$e',
                                snackPosition: SnackPosition.BOTTOM,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<TenMinuteBlockData>?>(
                      future: _activeBlocksFuture,
                      builder: (context, snap) {
                        final blocks = snap.data;
                        final trackedSecs = blocks != null && blocks.isNotEmpty
                            ? blocks.length * 600
                            : session.elapsedSeconds.value;
                        return Text(
                          '${jm.format(startedAt)} – ${jm.format(now)} (${_fmtDurationHours(trackedSecs)} tracked)',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      session.sessionTitle.value.trim().isEmpty
                          ? '—'
                          : session.sessionTitle.value.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 208,
                      child: FutureBuilder<List<TenMinuteBlockData>?>(
                        key: ValueKey(
                          'active_${activeId}_$epoch',
                        ),
                        future: _activeBlocksFuture,
                        builder: (context, blockSnap) {
                          if (blockSnap.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          }
                          final blocks = blockSnap.data ?? [];
                          if (blocks.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No 10-minute slots recorded yet — keep working.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            );
                          }
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: blocks.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final b = blocks[i];
                              final splitAfter =
                                  _splitMinuteWithinTenMinuteBlock(
                                b.blockStart,
                                now,
                              );
                              final inBlock = _nowInTenMinuteBlock(
                                b.blockStart,
                                now,
                              );
                              return _TenMinuteBlockColumn(
                                block: b,
                                now: now,
                                timeLabel: jm.format(b.blockStart),
                                splitAfterMinute: splitAfter,
                                showProgressDivider: inBlock &&
                                    splitAfter > 0 &&
                                    splitAfter < 10,
                                onTap: () =>
                                    _showActivityLevelDetail(context, b, now),
                                onDeleteSlot: () => _handleDelete(b, jm),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          if (pastSessions.isNotEmpty) {
            if (sections.isNotEmpty) sections.add(const SizedBox(height: 24));
            sections.add(
              Text(
                running ? 'Earlier on this day' : dayHeading,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            );
            sections.add(const SizedBox(height: 12));
            for (final r in pastSessions) {
              sections.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _SessionHistoryTile(row: r),
                ),
              );
            }
          }

          if (sections.isEmpty) {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Work diary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snap.connectionState == ConnectionState.waiting
                        ? 'Loading sessions…'
                        : 'No sessions recorded for ${DateFormat.yMMMEd().format(diaryDay)}.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start a session to capture screenshots and minute-by-minute activity (keyboard + mouse) in each 10-minute segment.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: sections,
          );
        },
      );
    });
  }

  Future<void> _handleDelete(
    TenMinuteBlockData b,
    DateFormat jm,
  ) async {
    final slotId = b.slotId;
    if (slotId == null) {
      Get.snackbar(
        'Nothing to delete',
        'This slot has no activity or screenshot recorded yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      print('UI delete slot: $slotId');
      await _deleteSlotById(slotId);
      WorkDiaryRemoteService.invalidateTotalsCache();
      Get.find<CloudRefreshService>().bump();
      Get.snackbar(
        'Deleted',
        'Removed ${jm.format(b.blockStart)} – '
            '${jm.format(b.blockStart.add(const Duration(minutes: 10)))}.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Delete failed',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

class _SessionHistoryTile extends StatefulWidget {
  const _SessionHistoryTile({required this.row});

  final CloudSessionRow row;

  @override
  State<_SessionHistoryTile> createState() => _SessionHistoryTileState();
}

class _SessionHistoryTileState extends State<_SessionHistoryTile> {
  late Future<List<TenMinuteBlockData>> _blocksFuture;
  Worker? _epochWatch;

  @override
  void initState() {
    super.initState();
    _blocksFuture = _loadBlocks();
    _epochWatch = ever<int>(Get.find<CloudRefreshService>().epoch, (_) {
      if (mounted) _reloadBlocks();
    });
  }

  @override
  void dispose() {
    _epochWatch?.dispose();
    super.dispose();
  }

  void _reloadBlocks() {
    setState(() {
      _blocksFuture = _loadBlocks();
    });
  }

  Future<List<TenMinuteBlockData>> _loadBlocks() async {
    final row = widget.row;
    final windowEnd = row.endedAt ?? DateTime.now();
    final liveClock = row.endedAt == null ? windowEnd : null;
    final remote = await WorkDiaryRemoteService.tryRemoteBlocks(
      sessionId: row.id,
      sessionStart: row.startedAt,
      windowEnd: windowEnd,
      liveClock: liveClock,
    );
    return remote ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final jm = DateFormat.jm();
    final cs = Theme.of(context).colorScheme;
    final row = widget.row;
    final windowEnd = row.endedAt ?? DateTime.now();
    final durationSecs = row.endedAt != null
        ? row.endedAt!.difference(row.startedAt).inSeconds
        : DateTime.now().difference(row.startedAt).inSeconds;
    final ended = row.endedAt != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  row.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (!ended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.royalGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Open',
                    style: TextStyle(
                      color: AppColors.royalGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Delete session',
                icon: Icon(Icons.delete_outline, color: cs.error),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete session?'),
                      content: Text(
                        'Remove “${row.title}” and all of its 10-minute slots (including screenshots). This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.error,
                            foregroundColor: cs.onError,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete session'),
                        ),
                      ],
                    ),
                  );
                  if (ok != true || !context.mounted) return;
                  try {
                    // If user deletes an active session, stop tracking first.
                    final sessionSvc = Get.find<SessionService>();
                    if (sessionSvc.isRunning.value &&
                        sessionSvc.activeSessionId.value == row.id) {
                      await sessionSvc.stopSession();
                    }
                    print('UI delete session: ${row.id}');
                    await Get.find<CloudService>().deleteSessionById(row.id);
                    WorkDiaryRemoteService.invalidateTotalsCache();
                    Get.find<CloudRefreshService>().bump();
                    Get.snackbar(
                      'Deleted',
                      'Session removed.',
                      snackPosition: SnackPosition.BOTTOM,
                      duration: const Duration(seconds: 2),
                    );
                  } catch (e) {
                    Get.snackbar(
                      'Delete failed',
                      '$e',
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          FutureBuilder<List<TenMinuteBlockData>>(
            future: _blocksFuture,
            builder: (context, snap) {
              final blocks = snap.data;
              final tracked = (blocks != null && blocks.isNotEmpty)
                  ? _fmtHrs(blocks.length * 600)
                  : _fmtHrs(durationSecs);
              return Text(
                ended
                    ? '${jm.format(row.startedAt)} – ${jm.format(row.endedAt!)} ($tracked tracked)'
                    : '${jm.format(row.startedAt)} – … ($tracked tracked)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<TenMinuteBlockData>>(
            future: _blocksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 208,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final blocks = snapshot.data ?? [];
              if (blocks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No activity segments for this session.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                );
              }
              return SizedBox(
                height: 208,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: blocks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final b = blocks[i];
                    return _TenMinuteBlockColumn(
                      block: b,
                      now: windowEnd,
                      timeLabel: jm.format(b.blockStart),
                      splitAfterMinute: 0,
                      showProgressDivider: false,
                      onTap: () =>
                          _showActivityLevelDetail(context, b, windowEnd),
                      onDeleteSlot: () => _handleDelete(b, jm),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(
    TenMinuteBlockData b,
    DateFormat jm,
  ) async {
    final slotId = b.slotId;
    if (slotId == null) {
      Get.snackbar(
        'Nothing to delete',
        'This slot has no activity or screenshot recorded yet.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    try {
      await _deleteSlotById(slotId);
      WorkDiaryRemoteService.invalidateTotalsCache();
      Get.find<CloudRefreshService>().bump();
      Get.snackbar(
        'Deleted',
        'Removed ${jm.format(b.blockStart)} – '
            '${jm.format(b.blockStart.add(const Duration(minutes: 10)))}.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Delete failed',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) _reloadBlocks();
    }
  }
}

/// Wall-clock minutes elapsed since [blockStart], capped at 10 (divider before index).
int _splitMinuteWithinTenMinuteBlock(DateTime blockStart, DateTime now) {
  final d = now.difference(blockStart);
  if (d.isNegative) return 0;
  return d.inMinutes.clamp(0, 10);
}

bool _nowInTenMinuteBlock(DateTime blockStart, DateTime now) {
  final blockEnd = blockStart.add(const Duration(minutes: 10));
  return !now.isBefore(blockStart) && now.isBefore(blockEnd);
}

class _TenMinuteBlockColumn extends StatelessWidget {
  const _TenMinuteBlockColumn({
    required this.block,
    required this.now,
    required this.timeLabel,
    required this.splitAfterMinute,
    required this.showProgressDivider,
    this.onTap,
    required this.onDeleteSlot,
  });

  final TenMinuteBlockData block;
  final DateTime now;
  final String timeLabel;
  final int splitAfterMinute;
  final bool showProgressDivider;
  final VoidCallback? onTap;

  /// Deletes this 10-minute slot row in `session_slots_10m` (and its screenshot).
  final Future<void> Function() onDeleteSlot;

  static const _inactiveSegment = Color(0xFF383838);

  bool _minuteShowsActivity(int index) {
    final minuteStart = block.blockStart.add(Duration(minutes: index));
    if (!minuteStart.isBefore(now)) {
      return false;
    }
    return block.minuteActive[index];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = block.screenshotPath;
    final signed = block.screenshotSignedUrl;
    final canDelete = block.slotId != null;

    final thumb = ColoredBox(
      color: cs.surfaceContainerHighest,
      child: signed != null
          ? Image.network(
              signed,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Icon(
                Icons.broken_image_outlined,
                color: cs.outline,
              ),
            )
          : path != null && File(path).existsSync()
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.broken_image_outlined,
                    color: cs.outline,
                  ),
                )
              : Icon(
                  Icons.desktop_windows_outlined,
                  color: cs.outline,
                  size: 40,
                ),
    );

    return SizedBox(
      width: 152,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumb,
                      ),
                    ),
                  ),
                ),
                if (canDelete)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        tooltip: 'Delete 10-minute slot',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 30,
                          minHeight: 30,
                        ),
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete this 10-minute slot?'),
                              content: const Text(
                                'Removes this slot’s keyboard / pointer / click '
                                'counts and its screenshot. The rest of the '
                                'session is unchanged.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete slot'),
                                ),
                              ],
                            ),
                          );
                          if (ok == true) await onDeleteSlot();
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < 10; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 12,
                        color: _minuteShowsActivity(i)
                            ? AppColors.royalGreen
                            : _inactiveSegment,
                      ),
                      if (showProgressDivider &&
                          splitAfterMinute > 0 &&
                          i == splitAfterMinute - 1)
                        Positioned(
                          right: -1,
                          top: -1,
                          bottom: -1,
                          child: Container(
                            width: 1,
                            color: Colors.white.withValues(alpha: 0.92),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            timeLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
