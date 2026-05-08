import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../utils/supabase_env.dart';
import '../controllers/cloud_login_controller.dart';

class CloudLoginView extends GetView<CloudLoginController> {
  const CloudLoginView({super.key});

  String _subtitle() {
    if (!SupabaseEnv.configured) {
      return 'Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY to assets .env.';
    }
    return 'Use the email and password for your Supabase Auth account.';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.lock_outline, size: 56, color: cs.primary),
                const SizedBox(height: 16),
                Text(
                  'Sign in',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _subtitle(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: controller.email,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Obx(
                  () => TextField(
                    controller: controller.password,
                    obscureText: controller.obscurePassword.value,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: controller.obscurePassword.value
                            ? 'Show password'
                            : 'Hide password',
                        icon: Icon(
                          controller.obscurePassword.value
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: controller.toggleObscurePassword,
                      ),
                    ),
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.submit(),
                  ),
                ),
                const SizedBox(height: 24),
                Obx(
                  () => FilledButton(
                    onPressed:
                        controller.loading.value ? null : controller.submit,
                    child: controller.loading.value
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign in'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
