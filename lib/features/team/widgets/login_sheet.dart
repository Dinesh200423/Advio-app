import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/team.dart';
import '../../auth/session_loader.dart';
import '../login_service.dart';

/// Asks the founder for a temporary password, creates the login, then shows what to pass on to the person.
Future<void> showLoginSheet(BuildContext context, TeamMember member) {
  return showAppSheet<void>(
    context,
    title: member.hasLogin ? 'Reset password' : 'Create login',
    builder: (_) => _LoginSheet(member: member),
  );
}

class _LoginSheet extends ConsumerStatefulWidget {
  const _LoginSheet({required this.member});
  final TeamMember member;

  @override
  ConsumerState<_LoginSheet> createState() => _LoginSheetState();
}

class _LoginSheetState extends ConsumerState<_LoginSheet> {
  late final _password = TextEditingController(text: generatePassword());
  String? _error;
  bool _saving = false;
  String? _done; // the password that was set, once it has worked

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final password = _password.text;
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(loginCreatorProvider)(memberId: widget.member.id, password: password);
      // Pick up the new "has a login" state.
      await ref.read(dataRefreshProvider)().catchError((_) {});
      if (mounted) setState(() => _done = password);
    } on LoginFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final member = widget.member;
    final done = _done;

    if (done != null) {
      final details = 'ADVIO login\nEmail: ${member.email}\nPassword: $done';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${member.name} can now sign in.', style: AppText.bodyStrong),
          const SizedBox(height: 12),
          AppCard(
            shadow: false,
            color: AppColors.tint(AppColors.primary, 0.05),
            child: SelectableText(details, style: AppText.body.copyWith(height: 1.6)),
          ),
          const SizedBox(height: 12),
          Text(
            'Send this to them privately. They will be asked to choose their own password the first time they sign in. This is the only time the password is shown.',
            style: AppText.caption,
          ),
          const SizedBox(height: 16),
          AppButton.secondary(
            label: 'Copy details',
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: details));
              if (context.mounted) AppSnack.success(context, 'Copied');
            },
          ),
          const SizedBox(height: 8),
          AppButton(label: 'Done', onPressed: () => Navigator.of(context).pop()),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          member.hasLogin
              ? '${member.name} will sign in with ${member.email} and the new password below. Their old password stops working.'
              : '${member.name} will sign in with ${member.email} and the temporary password below.',
          style: AppText.body,
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _password,
          label: 'Temporary password',
          suffix: IconButton(
            tooltip: 'Make a new one',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() => _password.text = generatePassword()),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: AppText.caption.copyWith(color: AppColors.danger)),
        ],
        const SizedBox(height: 16),
        AppButton(label: member.hasLogin ? 'Reset password' : 'Create login', onPressed: _saving ? null : _save, loading: _saving),
      ],
    );
  }
}
