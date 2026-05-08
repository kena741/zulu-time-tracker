import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../../data/models/employee_profile.dart';
import '../../../../utils/supabase_env.dart';
import '../controllers/account_controller.dart';

/// Account: employee profile from `public.employees`.
class AccountTabView extends StatelessWidget {
  const AccountTabView({super.key});

  @override
  Widget build(BuildContext context) {
    final account = Get.find<AccountController>();
    final cs = Theme.of(context).colorScheme;
    final df = DateFormat.yMMMd().add_jm();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Obx(() {
            if (!SupabaseEnv.configured) {
              return ListView(
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Add SUPABASE_URL and SUPABASE_ANON_KEY to your .env asset to load your employee profile.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            }

            final uid = SupabaseEnv.client.auth.currentUser?.id;
            if (uid == null) {
              return ListView(
                children: [
                  Text(
                    'Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sign in on the login screen to see your profile.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              );
            }

            return ListView(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Account',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh profile',
                      onPressed:
                          account.loading.value ? null : account.fetchProfile,
                      icon: account.loading.value
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          : Icon(Icons.refresh, color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Profile data comes from the employees table in Supabase (linked to your auth user).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                if (account.errorMessage.value != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: cs.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          account.errorMessage.value!,
                          style: TextStyle(color: cs.onErrorContainer),
                        ),
                      ),
                    ),
                  ),
                if (account.loading.value && account.profile.value == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (account.profile.value != null)
                  _ProfileCard(
                    profile: account.profile.value!,
                    dateFormat: df,
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No employee profile row found for your user. '
                      'Insert a row in public.employees with user_id = your auth user id (typically via admin / service role).',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.dateFormat,
  });

  final EmployeeProfile profile;
  final DateFormat dateFormat;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = profile;
    final phoneDisplay =
        p.phone != null && p.phone!.trim().isNotEmpty ? p.phone! : '—';

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.fullName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
            _ProfileRow(icon: Icons.email_outlined, label: 'Email', value: p.email),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: phoneDisplay,
            ),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.badge_outlined,
              label: 'Employee ID',
              value: p.id,
            ),
            const SizedBox(height: 10),
            _ProfileRow(
              icon: Icons.calendar_today_outlined,
              label: 'Profile created',
              value: dateFormat.format(p.createdAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
              SelectableText(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
