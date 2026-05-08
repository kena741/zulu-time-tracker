import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utils/supabase_env.dart';
import '../../../routes/app_routes.dart';
import '../../account_tab/views/account_tab_view.dart';
import '../../privacy_tab/views/privacy_tab_view.dart';
import '../../settings_tab/views/settings_tab_view.dart';
import '../../timer_tab/views/timer_tab_view.dart';
import '../controllers/shell_controller.dart';

class ShellView extends GetView<ShellController> {
  const ShellView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!SupabaseEnv.configured ||
          SupabaseEnv.client.auth.currentUser == null) {
        if (Get.currentRoute != Routes.LOGIN) {
          Get.offAllNamed(Routes.LOGIN);
        }
      }
    });
    return Scaffold(
      body: Row(
        children: [
          Obx(
            () {
              final isExtended = MediaQuery.sizeOf(context).width > 1100;
              return NavigationRail(
              selectedIndex: controller.selectedIndex.value,
              onDestinationSelected: (i) => controller.selectedIndex.value = i,
              extended: isExtended,
              // Flutter asserts: if extended==true then labelType must be null/none.
              labelType:
                  isExtended ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.timer, color: Theme.of(context).colorScheme.primary),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.play_circle_outline),
                  label: Text('Timer'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: Text('Settings'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  label: Text('Account'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.privacy_tip_outlined),
                  label: Text('Privacy'),
                ),
              ],
              );
            },
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Material(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'ZuluTime Tracker',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Spacer(),
                        _SupabaseUserHeader(),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: Obx(
                    () => IndexedStack(
                      index: controller.selectedIndex.value,
                      children: [
                        TimerTabView(),
                        SettingsTabView(),
                        AccountTabView(),
                        PrivacyTabView(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Header badge: Supabase email, user id, optional local role when enabled.
class _SupabaseUserHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return StreamBuilder<AuthState>(
      stream: SupabaseEnv.client.auth.onAuthStateChange,
      builder: (context, _) {
        final user = SupabaseEnv.client.auth.currentUser;
        if (user == null) {
          return Text(
            'Signed out',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.error,
                ),
          );
        }

        final id = user.id;
        final idShort = id.length > 12 ? '${id.substring(0, 8)}…' : id;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user.email ?? 'Signed in',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            Tooltip(
              message: id,
              child: Text(
                'ID: $idShort',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
              ),
            ),
          ],
        );
      },
    );
  }
}
