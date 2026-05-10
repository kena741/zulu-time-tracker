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
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Obx(
                () {
                  final isExtended = MediaQuery.sizeOf(context).width > 1100;
                  final railTheme = NavigationRailTheme.of(context);
                  final railBg = railTheme.backgroundColor ??
                      Theme.of(context).colorScheme.surfaceContainerHigh;
                  // Match Material navigation rail widths so layout does not overflow.
                  final railWidth =
                      isExtended ? (railTheme.minExtendedWidth ?? 256) : 80.0;

                  return SizedBox(
                    width: railWidth,
                    height: constraints.maxHeight,
                    child: Material(
                      color: railBg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: NavigationRail(
                              backgroundColor: Colors.transparent,
                              selectedIndex: controller.railIndex.value,
                              onDestinationSelected: controller.selectRail,
                              extended: isExtended,
                              labelType: isExtended
                                  ? NavigationRailLabelType.none
                                  : NavigationRailLabelType.all,
                              leading: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Icon(
                                  Icons.timer,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
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
                              ],
                            ),
                          ),
                          Obx(
                            () => _RailPrivacyButton(
                              extended: isExtended,
                              selected: controller.privacySelected.value,
                              onTap: controller.selectPrivacy,
                            ),
                          ),
                        ],
                      ),
                    ),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                          index: controller.bodyIndex,
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
          );
        },
      ),
    );
  }
}

/// Privacy entry pinned to the bottom of the navigation rail (not in the main destination list).
class _RailPrivacyButton extends StatelessWidget {
  const _RailPrivacyButton({
    required this.extended,
    required this.selected,
    required this.onTap,
  });

  final bool extended;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final railTheme = NavigationRailTheme.of(context);
    final cs = Theme.of(context).colorScheme;
    final Color iconColor = selected
        ? (railTheme.selectedIconTheme?.color ?? cs.onSecondaryContainer)
        : (railTheme.unselectedIconTheme?.color ?? cs.onSurfaceVariant);
    final Color? bg = selected
        ? (railTheme.indicatorColor ?? cs.secondaryContainer)
        : null;

    final icon = Icon(Icons.privacy_tip_outlined, size: 24, color: iconColor);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: extended ? 12 : 8,
              vertical: 10,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: extended
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(width: 12),
                          Text(
                            'Privacy',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight:
                                      selected ? FontWeight.w600 : FontWeight.w500,
                                  color: iconColor,
                                ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          icon,
                          const SizedBox(height: 4),
                          Text(
                            'Privacy',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: iconColor,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
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
