import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../data/backend/backend_config.dart';
import '../../shared/widgets/app_logo.dart';
import 'auth_providers.dart';

/// Shared layout for login / signup.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(AppSpacing.page + 4, 32, AppSpacing.page + 4, 32),
              children: [
                const Align(alignment: Alignment.centerLeft, child: AppWordmark()),
                const SizedBox(height: 40),
                Text(title, style: AppText.pageTitle),
                const SizedBox(height: 8),
                Text(subtitle, style: AppText.bodyLarge.copyWith(color: AppColors.muted)),
                const SizedBox(height: 32),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  // The demo (sample data) mode is pre-filled so it can be explored; the real sign-in starts empty.
  final _email = TextEditingController(text: BackendConfig.isConfigured ? '' : 'founder@example.com');
  final _password = TextEditingController(text: BackendConfig.isConfigured ? '' : 'password');
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signIn(email: _email.text.trim(), password: _password.text);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) context.go(Routes.home);
  }

  Future<void> _forgot() async {
    if (BackendConfig.isConfigured) {
      AppSnack.info(context, 'Ask the ADVIO founder to reset your password.');
      return;
    }
    final ok = await confirmDialog(
      context,
      title: 'Reset password',
      message: 'We\'ll send a reset link to ${_email.text.trim().isEmpty ? 'your email' : _email.text.trim()}. (Demo only: no email is sent.)',
      confirmLabel: 'Send link',
      icon: Icons.mark_email_read_rounded,
    );
    if (ok && mounted) AppSnack.success(context, 'Reset link sent');
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to run ADVIO.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                controller: _email,
                label: 'Email',
                hint: 'you@example.com',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const FormGap(),
              AppTextField(
                controller: _password,
                label: 'Password',
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                validator: Validators.password,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
        ),
    if (_error != null)
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.tint(AppColors.danger, 0.08), borderRadius: BorderRadius.circular(12)),
        child: Text(_error!, style: AppText.body.copyWith(color: AppColors.danger, fontSize: 13.5)),
      ),
        const SizedBox(height: 8),
        AppButton(label: 'Sign in', onPressed: _submit, loading: _loading),
        const SizedBox(height: 24),
        // Accounts are invite-only once the real backend is on.
        if (!BackendConfig.isConfigured)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('New to the team?', style: AppText.body.copyWith(color: AppColors.muted)),
              TextButton(onPressed: () => context.go(Routes.signup), child: const Text('Create account')),
            ],
          )
        else
          Text('Accounts are created by the ADVIO founder.', textAlign: TextAlign.center, style: AppText.caption),
      ],
    );
  }
}
