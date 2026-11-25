import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../auth/auth_providers.dart';
import '../../core/update/app_update.dart';
import '../../data/backend/backend_config.dart';
import 'settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final currency = currencyFor(s.currency);
    final scale = switch (s.textScale) { < 1 => 'Small', > 1 => 'Large', _ => 'Default' };

    return PageScaffold(
      title: 'Settings',
      children: [
        AppCard(
          onTap: () => context.push(Routes.settingsProfile),
          child: Row(
            children: [
              InitialsAvatar(name: s.name, size: 56, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: AppText.cardTitle),
                    Text(s.email, style: AppText.label),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _Group(title: 'Account', rows: [
          _Row('Profile', s.headline, Routes.settingsProfile),
          _Row('Business information', s.businessName, Routes.settingsBusiness),
          _Row('Currency', '${currency.code} (${currency.symbol.trim()})', Routes.settingsCurrency),
          if (BackendConfig.isConfigured) _Row('Change password', null, Routes.changePassword),
        ]),
        const SizedBox(height: 20),
        _Group(title: 'Preferences', rows: [
          _Row('Notifications', null, Routes.settingsNotifications),
          _Row('Appearance', 'Light · $scale text', Routes.settingsAppearance),
        ]),
        const SizedBox(height: 20),
        _Group(title: 'About', rows: [
          _Row('App information', 'Version ${ref.watch(installedVersionProvider).asData?.value ?? ''}', Routes.settingsAbout),
        ]),
        const SizedBox(height: 28),
        AppButton.secondary(
          label: 'Log out',
          onPressed: () async {
            final ok = await confirmDialog(
              context,
              title: 'Log out?',
              message: 'You\'ll need to sign in again. Your sample data is kept until the app closes.',
              confirmLabel: 'Log out',
              destructive: true,
            );
            if (ok) ref.read(authProvider.notifier).signOut();
          },
        ),
      ],
    );
  }
}

class _Row {
  const _Row(this.label, this.value, this.route);
  final String label;
  final String? value;
  final String route;
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text(title.toUpperCase(), style: AppText.caption.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600))),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                InkWell(
                  borderRadius: BorderRadius.vertical(
                    top: i == 0 ? const Radius.circular(16) : Radius.zero,
                    bottom: i == rows.length - 1 ? const Radius.circular(16) : Radius.zero,
                  ),
                  onTap: () => context.push(rows[i].route),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        Text(rows[i].label, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                        const Spacer(),
                        if (rows[i].value != null)
                          Flexible(child: Text(rows[i].value!, overflow: TextOverflow.ellipsis, style: AppText.label)),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.muted),
                      ],
                    ),
                  ),
                ),
                if (i != rows.length - 1) const Divider(indent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
