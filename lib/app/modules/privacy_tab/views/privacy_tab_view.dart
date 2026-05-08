import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../platform/native_desktop.dart';

class PrivacyTabView extends StatelessWidget {
  const PrivacyTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            children: [
              Text(
                'Privacy & transparency',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'What ZuluTime collects\n\n'
                '• Sessions — start/end times and the memo/title you enter.\n'
                '• 10-minute slots — aggregated numeric counters only (keyboard events; pointer movement + scroll + mouse buttons; '
                'idle seconds estimated from OS idle signals). No keystroke contents, cursor coordinates, window titles, URLs, '
                'or clipboard.\n'
                '• Screenshots — periodic PNG captures (default every 10 minutes). Each image may be cached briefly on your '
                'device, then sent when you are signed in; afterward the local cache copy is removed.\n\n'
                'Desktop OS permissions\n\n'
                '• Accessibility / Input Monitoring — needed for reliable keyboard + global pointer counting.\n'
                '• Screen Recording — typically needed for screenshots.\n\n'
                'Deleting data\n\n'
                '• Deleting a session or slot removes that recorded Work Diary data, including any screenshot tied to that slot, '
                'from what your signed-in account can see in the app.\n\n'
                'Stopping tracking\n\n'
                '• Stop your session in the app and revoke Screen Recording / Input Monitoring in system settings if you want '
                'OS-level tracking disabled.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  await NativeDesktop.openPrivacySettings();
                  Get.snackbar(
                    'System settings',
                    'Grant Screen Recording for screenshots. Grant Accessibility / Input Monitoring for aggregated keyboard + pointer counts.',
                  );
                },
                icon: const Icon(Icons.settings_suggest_outlined),
                label: const Text('Open system privacy settings'),
              ),
              const SizedBox(height: 16),
              Text(
                'To stop tracking entirely, uninstall the app or revoke Accessibility / Screen Recording / Input Monitoring in system settings.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
