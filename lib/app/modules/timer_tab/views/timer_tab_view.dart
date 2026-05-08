import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../services/cloud_refresh_service.dart';
import '../../../../services/work_diary_remote_service.dart';
import '../../../widgets/work_diary_panel.dart';
import '../controllers/timer_controller.dart';

class TimerTabView extends GetView<TimerController> {
  const TimerTabView({super.key});

  String _fmt(int secs) {
    final d = Duration(seconds: secs);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _fmtWeekHrsM(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(() {
                // Bump this epoch after cloud deletes so totals refresh instantly.
                Get.find<CloudRefreshService>().epoch.value;
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final monday = today.subtract(
                  Duration(days: today.weekday - DateTime.monday),
                );
                final nextMonday = monday.add(const Duration(days: 7));
                final sunday = monday.add(const Duration(days: 6));
                final rangeText =
                    '${DateFormat.MMMd().format(monday)} – ${DateFormat.MMMd().format(sunday)}';
                return FutureBuilder<int>(
                  future: WorkDiaryRemoteService.totalSlotSecondsInRange(
                    monday,
                    nextMonday,
                  ),
                  builder: (context, snap) {
                    final weekSecs = snap.data ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_outlined, color: cs.primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Weekly total (Mon–Sun)',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  rangeText,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _fmtWeekHrsM(weekSecs),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
              const SizedBox(height: 20),
              Text(
                'Work memo',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Describe what you’re working on. Keyboard metrics are aggregated counts only—never what you type. Screenshots follow your Privacy settings.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              Obx(
                () => TextField(
                  controller: controller.titleEdit,
                  decoration: const InputDecoration(
                    labelText: 'Memo (what are you working on?)',
                    hintText: 'E.g. “Design homepage”, “Fix billing bug”, “Client meeting notes”…',
                    border: OutlineInputBorder(),
                  ),
                  enabled: !controller.session.isRunning.value,
                ),
              ),
              const SizedBox(height: 16),
              Obx(
                () => FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: controller.toggle,
                  icon: Icon(
                    controller.session.isRunning.value
                        ? Icons.stop_circle_outlined
                        : Icons.play_circle_outline,
                  ),
                  label: Text(
                    controller.session.isRunning.value
                        ? 'Stop session'
                        : 'Start session',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Center(
                child: Obx(
                  () => Text(
                    _fmt(controller.session.elapsedSeconds.value),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          letterSpacing: 2,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Obx(
                () {
                  final d = controller.diaryDate.value;
                  controller.session.elapsedSeconds.value;
                  controller.session.isRunning.value;
                  Get.find<CloudRefreshService>().epoch.value;
                  final dateLabel = DateFormat.yMMMEd().format(d);
                  final isToday = DateUtils.isSameDay(d, DateTime.now());
                  final dayStart = DateTime(d.year, d.month, d.day);
                  final dayEnd = dayStart.add(const Duration(days: 1));
                  return FutureBuilder<int>(
                    future: WorkDiaryRemoteService.totalSlotSecondsInRange(
                      dayStart,
                      dayEnd,
                    ),
                    builder: (context, snap) {
                      final secs = snap.data ?? 0;
                      return Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: d,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) controller.setDiaryDate(picked);
                            },
                            icon: const Icon(Icons.calendar_today_outlined, size: 18),
                            label: Text(dateLabel),
                          ),
                          if (!isToday)
                            TextButton(
                              onPressed: () => controller.setDiaryDate(DateTime.now()),
                              child: const Text('Today'),
                            ),
                          Tooltip(
                            message:
                                'Sum of recorded 10-minute slots on this day. '
                                'Each slot contributes 10 minutes; deleting a '
                                'slot reduces this total instantly.',
                            child: Text(
                              'Day total: ${_fmt(secs)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Obx(() {
                if (!controller.session.isRunning.value) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Stored in the cloud · activity counts never include typed content or cursor positions.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
              const SizedBox(height: 12),
              const WorkDiaryPanel(),
            ],
          ),
        ),
      ),
    );
  }
}
