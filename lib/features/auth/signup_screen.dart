import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/validators.dart';
import 'auth_providers.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  bool _agreed = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      AppSnack.error(context, 'Please accept the terms to continue');
      return;
    }
    setState(() => _loading = true);
    await ref.read(authProvider.notifier).signUp(name: _name.text.trim(), email: _email.text.trim(), password: _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Join the ADVIO workspace.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              AppTextField(
                controller: _name,
                label: 'Full name',
                hint: 'Your name',
                icon: Icons.person_outline_rounded,
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const FormGap(),
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
                hint: 'At least 6 characters',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                validator: Validators.password,
              ),
              const FormGap(),
              AppTextField(
                controller: _confirm,
                label: 'Confirm password',
                hint: 'Re-enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Checkbox(
              value: _agreed,
              onChanged: (v) => setState(() => _agreed = v ?? false),
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text('I agree to the Terms of Service and Privacy Policy', style: AppText.label),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AppButton(label: 'Create account', onPressed: _submit, loading: _loading),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Already have an account?', style: AppText.body.copyWith(color: AppColors.muted)),
            TextButton(onPressed: () => context.go(Routes.login), child: const Text('Sign in')),
          ],
        ),
      ],
    );
  }
}
