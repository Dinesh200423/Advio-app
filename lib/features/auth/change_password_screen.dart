import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import 'auth_providers.dart';

/// Choose a new password. Shown straight after sign-in when the login still has a temporary password,
/// and reachable from Settings at any other time.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forced = ref.watch(authProvider.select((a) => a.mustChangePassword));

    return FormPage(
      title: forced ? 'Choose your password' : 'Change password',
      submitLabel: 'Save password',
      successMessage: 'Password changed',
      onSubmit: () async {
        try {
          await ref.read(authProvider.notifier).changePassword(_password.text);
          return true;
        } on AuthFailure catch (e) {
          if (context.mounted) AppSnack.error(context, e.message);
          return false;
        }
      },
      children: [
        if (forced) ...[
          Text('You signed in with a temporary password. Choose one only you know to continue.', style: AppText.body.copyWith(color: AppColors.muted)),
          const FormGap(),
        ],
        AppTextField(
          controller: _password,
          label: 'New password',
          obscure: true,
          required: true,
          textInputAction: TextInputAction.next,
          validator: (v) => (v == null || v.length < 8) ? 'Use at least 8 characters' : null,
        ),
        const FormGap(),
        AppTextField(
          controller: _confirm,
          label: 'Confirm new password',
          obscure: true,
          required: true,
          validator: (v) => v != _password.text ? 'The two passwords do not match' : null,
        ),
      ],
    );
  }
}
