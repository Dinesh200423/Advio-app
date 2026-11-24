import 'package:flutter/material.dart';

import '../../app/theme/app_text.dart';
import '../constants/app_colors.dart';
import 'app_button.dart';

/// Confirmation dialog. Resolves to `true` only if the user confirms.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: icon == null
          ? null
          : Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.tint(destructive ? AppColors.danger : AppColors.primary, 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: destructive ? AppColors.danger : AppColors.primary),
            ),
      title: Text(title, textAlign: icon == null ? TextAlign.start : TextAlign.center),
      content: Text(message, textAlign: icon == null ? TextAlign.start : TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Row(
          children: [
            Expanded(child: AppButton.secondary(label: cancelLabel, onPressed: () => Navigator.pop(ctx, false))),
            const SizedBox(width: 12),
            Expanded(
              child: destructive
                  ? AppButton.danger(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true))
                  : AppButton(label: confirmLabel, onPressed: () => Navigator.pop(ctx, true)),
            ),
          ],
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Modal bottom sheet with optional title; keyboard- and safe-area-aware.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(title, style: AppText.sectionTitle),
              const SizedBox(height: 16),
            ],
            builder(ctx),
          ],
        ),
      ),
    ),
  );
}

/// Pick one value from a list in a bottom sheet.
Future<T?> pickOption<T>(
  BuildContext context, {
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  T? selected,
  Color? Function(T)? colorOf,
}) {
  return showAppSheet<T>(
    context,
    title: title,
    builder: (ctx) => Column(
      children: [
        for (final o in options)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            minVerticalPadding: 12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: colorOf == null
                ? null
                : Container(width: 10, height: 10, decoration: BoxDecoration(color: colorOf(o), shape: BoxShape.circle)),
            title: Text(labelOf(o), style: AppText.bodyStrong),
            trailing: o == selected ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
            onTap: () => Navigator.pop(ctx, o),
          ),
      ],
    ),
  );
}
