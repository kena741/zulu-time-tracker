import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/activity_models.dart';
import '../../services/work_diary_remote_service.dart';

/// Last 10 minutes: per-minute screenshot thumbnail + green keystroke bar (grey when idle).
/// Refreshes every minute on the wall clock and every 30s for responsiveness.
class TenMinuteLiveStrip extends StatefulWidget {
  const TenMinuteLiveStrip({super.key});

  @override
  State<TenMinuteLiveStrip> createState() => _TenMinuteLiveStripState();
}

class _TenMinuteLiveStripState extends State<TenMinuteLiveStrip> {
  Timer? _t;
  Future<List<MinuteSlotData>>? _slotsFuture;

  @override
  void initState() {
    super.initState();
    _slotsFuture = _loadSlots();
    _t = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _slotsFuture = _loadSlots();
        });
      }
    });
  }

  Future<List<MinuteSlotData>> _loadSlots() async {
    return WorkDiaryRemoteService.rollingTenMinuteSlots();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hm = DateFormat.Hm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last 10 minutes (1 min per column)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          'Green bar = HID activity (keyboard / mouse / wheel / clicks) vs busiest minute '
          '· Grey = idle that minute.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: FutureBuilder<List<MinuteSlotData>>(
            future: _slotsFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              final slots = snap.data!;
              final maxK = slots.fold<int>(
                1,
                (m, s) => s.keystrokes > m ? s.keystrokes : m,
              );
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < slots.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: _MinuteColumn(
                        slot: slots[i],
                        label: hm.format(slots[i].slotStart),
                        maxKeystrokes: maxK,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MinuteColumn extends StatelessWidget {
  const _MinuteColumn({
    required this.slot,
    required this.label,
    required this.maxKeystrokes,
  });

  final MinuteSlotData slot;
  final String label;
  final int maxKeystrokes;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final path = slot.screenshotPath;
    final signed = slot.screenshotSignedUrl;
    final hasFile = path != null && File(path).existsSync();
    final hasNet = signed != null && signed.trim().isNotEmpty;
    final frac = maxKeystrokes > 0 ? slot.keystrokes / maxKeystrokes : 0.0;
    final barH = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: ColoredBox(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              child: hasNet
                  ? Image.network(
                      signed,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: cs.outline,
                      ),
                    )
                  : hasFile
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
                          Icons.image_not_supported_outlined,
                          color: cs.outline,
                        ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: barH,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fill = slot.keystrokes > 0
                  ? (frac * constraints.maxHeight).clamp(4.0, barH)
                  : 0.0;
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                  ),
                  if (slot.keystrokes > 0)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        height: fill,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          '${slot.keystrokes}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: slot.keystrokes > 0
                    ? cs.primary
                    : cs.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
