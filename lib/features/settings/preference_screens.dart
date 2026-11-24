import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/update/app_update.dart';
import '../../core/update/update_prompt.dart';
import '../../core/utils/formatters.dart';
import '../../data/backend/backend_config.dart';
import 'settings_providers.dart';

class CurrencyScreen extends ConsumerWidget {
  const CurrencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return PageScaffold(
      title: 'Currency',
      children: [
        Text('Amounts across the app are shown in this currency. Values are formatted, not converted.', style: AppText.label),
        const SizedBox(height: 16),
        AppCard(
          padding: EdgeInsets.zero,
          child: RadioGroup<String>(
            groupValue: s.currency,
            onChanged: (v) {
              if (v != null) notifier.update((x) => x.copyWith(currency: v));
            },
            child: Column(
              children: [
                for (var i = 0; i < supportedCurrencies.length; i++) ...[
                  RadioListTile<String>(
                    value: supportedCurrencies[i].code,
                    title: Text(supportedCurrencies[i].name, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                    subtitle: Text('${supportedCurrencies[i].code}  ·  ${formatMoney(125000, supportedCurrencies[i].code)}', style: AppText.caption),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                  if (i != supportedCurrencies.length - 1) const Divider(indent: 16),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Default tax rate', style: AppText.sectionTitle),
        const SizedBox(height: 4),
        Text('Applied to new quotations and invoices. You can change it per document.', style: AppText.label),
        const SizedBox(height: 12),
        FilterChipRow<double>(
          options: const [0, 5, 12, 18, 28],
          allLabel: null,
          selected: s.defaultTaxPercent,
          labelOf: (v) => '${v.toStringAsFixed(0)}%',
          onSelected: (v) {
            if (v != null) notifier.update((x) => x.copyWith(defaultTaxPercent: v));
          },
        ),
      ],
    );
  }
}

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    Widget tile(String title, String subtitle, bool value, void Function(bool) onChanged) => SwitchListTile(
          value: value,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle, style: AppText.caption),
        );

    return PageScaffold(
      title: 'Notifications',
      children: [
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              tile('Push notifications', 'Alerts on this device', s.pushNotifications, (v) => notifier.update((x) => x.copyWith(pushNotifications: v))),
              const Divider(indent: 16),
              tile('Weekly email digest', 'Monday summary of your business', s.emailDigest, (v) => notifier.update((x) => x.copyWith(emailDigest: v))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 8), child: Text('ALERT ME ABOUT', style: AppText.caption.copyWith(letterSpacing: 0.8, fontWeight: FontWeight.w600))),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              tile('Lead follow-ups', 'When a follow-up is due', s.followUpReminders, (v) => notifier.update((x) => x.copyWith(followUpReminders: v))),
              const Divider(indent: 16),
              tile('Invoices', 'Payments received and invoices going overdue', s.invoiceAlerts, (v) => notifier.update((x) => x.copyWith(invoiceAlerts: v))),
              const Divider(indent: 16),
              tile('Task deadlines', 'The day before a task is due', s.taskDeadlines, (v) => notifier.update((x) => x.copyWith(taskDeadlines: v))),
            ],
          ),
        ),
      ],
    );
  }
}

class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  static const _sizes = [('Small', 0.9), ('Default', 1.0), ('Large', 1.15)];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(settingsProvider.select((s) => s.textScale));
    final index = _sizes.indexWhere((e) => e.$2 == scale).clamp(0, _sizes.length - 1);

    Widget theme(String name, bool selected, {String? note}) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
              color: AppColors.surface,
            ),
            child: Opacity(
              opacity: selected ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.bodyStrong),
                  const SizedBox(height: 2),
                  Text(note ?? 'Selected', style: AppText.caption),
                ],
              ),
            ),
          ),
        );

    return PageScaffold(
      title: 'Appearance',
      children: [
        Text('Theme', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        Row(
          children: [
            theme('Light', true),
            const SizedBox(width: 10),
            theme('Dark', false, note: 'Coming soon'),
            const SizedBox(width: 10),
            theme('System', false, note: 'Coming soon'),
          ],
        ),
        const SizedBox(height: 28),
        Text('Text size', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        SegmentedTabs(
          labels: [for (final s in _sizes) s.$1],
          index: index,
          onChanged: (i) => ref.read(settingsProvider.notifier).update((x) => x.copyWith(textScale: _sizes[i].$2)),
        ),
        const SizedBox(height: 20),
        AppCard(
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preview', style: AppText.caption),
              const SizedBox(height: 8),
              Text('Invoice INV-2026-014', style: AppText.cardTitle),
              const SizedBox(height: 4),
              Text('Nova Retail Pvt Ltd  ·  due in 5 days', style: AppText.body),
            ],
          ),
        ),
      ],
    );
  }
}

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  bool _checking = false;

  Future<void> _checkForUpdates() async {
    setState(() => _checking = true);
    final installed = await ref.read(installedVersionProvider.future);
    final latest = await ref.read(updateCheckerProvider)();
    if (!mounted) return;
    setState(() => _checking = false);
    if (latest == null) {
      AppSnack.info(context, 'Could not check for updates right now.');
    } else if (!isNewerVersion(latest.version, installed)) {
      AppSnack.success(context, 'You are on the latest version.');
    } else {
      await showUpdateDialog(context, ref, latest, installed: installed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(installedVersionProvider).asData?.value ?? '';
    return PageScaffold(
      title: 'App information',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADVIO', style: AppText.pageTitle),
              const SizedBox(height: 4),
              Text('Websites, Software & Automation for Growing Businesses', style: AppText.body.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InfoCard(children: [
          InfoRow(label: 'Version', value: version),
          InfoRow(label: 'Data', value: BackendConfig.isConfigured ? 'Saved to the ADVIO database' : 'Sample data, kept in memory'),
        ]),
        const SizedBox(height: 16),
        AppButton.secondary(label: 'Check for updates', onPressed: _checking ? null : _checkForUpdates, loading: _checking),
        if (!BackendConfig.isConfigured) ...[
          const SizedBox(height: 16),
          Text(
            'This copy is running on sample data. Everything you add or change lasts until the app is closed, and nothing is sent anywhere.',
            style: AppText.caption.copyWith(height: 1.5),
          ),
        ],
      ],
    );
  }
}
