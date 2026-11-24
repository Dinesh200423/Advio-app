import 'package:flutter/material.dart';
import '../../app/router/routes.dart';
import '../constants/app_colors.dart';
import 'dialogs.dart';
import 'states.dart';

/// Shown when a detail/edit route points at a record that no longer exists.
class MissingRecord extends StatelessWidget {
  const MissingRecord({super.key, required this.what, this.fallback = Routes.home});
  final String what;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ErrorState(
        title: '$what not found',
        message: 'It may have been deleted.',
        retryLabel: 'Go back',
        onRetry: () => context.popOr(fallback),
      ),
    );
  }
}

/// Overflow menu with Edit / Delete used by detail pages.
class DetailMenu extends StatelessWidget {
  const DetailMenu({
    super.key,
    required this.onEdit,
    required this.onDelete,
    required this.deleteTitle,
    required this.deleteMessage,
    this.extra = const [],
    this.onExtra,
  });

  /// Called with the value of any entry in [extra] that gets picked.
  final ValueChanged<String>? onExtra;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final String deleteTitle;
  final String deleteMessage;
  final List<PopupMenuEntry<String>> extra;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) async {
        if (v == 'edit') {
          onEdit();
        } else if (v == 'delete') {
          final ok = await confirmDialog(
            context,
            title: deleteTitle,
            message: deleteMessage,
            confirmLabel: 'Delete',
            destructive: true,
            icon: Icons.delete_outline_rounded,
          );
          if (ok) onDelete();
        } else {
          onExtra?.call(v);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'), contentPadding: EdgeInsets.zero)),
        ...extra,
        const PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded, color: AppColors.danger),
            title: Text('Delete', style: TextStyle(color: AppColors.danger)),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
