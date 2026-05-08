import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/privacy_controller.dart';

class PrivacyView extends GetView<PrivacyController> {
  const PrivacyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & consent')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              Text(
                'How ZuluTime works',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'ZuluTime Tracker’s Work Diary is available while you are signed in.\n\n'
                'What we collect (never typed content):\n\n'
                '• Sessions — start/end timestamps and the memo/title you enter.\n'
                '• 10-minute activity slots — numeric counters only (keyboard events, pointer movement + scroll + mouse buttons, '
                'plus an idle estimate derived from OS idle signals). These are aggregated into each slot; we do not record '
                'what you type, cursor coordinates, window titles, URLs, or clipboard.\n'
                '• Screenshots — PNG captures on a fixed schedule (default every 10 minutes). Images may be cached briefly on '
                'your device, then sent when you are signed in; afterward the local cache copy is removed.\n\n'
                'macOS permissions:\n'
                '• Accessibility / Input Monitoring — needed for reliable keyboard + global pointer counting.\n'
                '• Screen Recording — typically needed for screenshots.\n\n'
                'By continuing, you accept this processing as part of using ZuluTime.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: controller.saveAndContinue,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
