import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../themes/theme_controller.dart';
import '../../../../utils/supabase_env.dart';
import '../controllers/settings_controller.dart';

class SettingsTabView extends GetView<SettingsController> {
  const SettingsTabView({super.key});

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
                'Settings',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Screenshots and aggregated activity metrics are core to the Work Diary — see the Privacy tab for what '
                'is collected. Grant Screen Recording for screenshots and Accessibility / Input Monitoring '
                'for keyboard + pointer counters when macOS prompts.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setState) {
                  return Column(
                    children: [
                      if (!SupabaseEnv.configured)
                        ListTile(
                          title: const Text('Supabase not configured'),
                          subtitle: const Text(
                            'Add SUPABASE_URL and SUPABASE_ANON_KEY to assets .env to enable cloud tracking.',
                          ),
                        ),
                      ListTile(
                        title: const Text('Appearance'),
                        trailing: Obx(() {
                          final mode =
                              Get.find<ThemeController>().themeMode.value;
                          return DropdownButton<ThemeMode>(
                            value: mode,
                            onChanged: (m) {
                              if (m != null) controller.setThemeMode(m);
                            },
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.system,
                                child: Text('System'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Light'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Dark'),
                              ),
                            ],
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
