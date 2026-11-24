import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import 'activity_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [...ref.watch(notificationsProvider)]..sort((a, b) => b.at.compareTo(a.at));
    final unread = ref.watch(unreadNotificationsProvider);

    return PageScaffold(
      title: 'Notifications',
      actions: [
        if (unread > 0)
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).markAllRead();
              AppSnack.success(context, 'All notifications marked as read');
            },
            child: const Text('Mark all read'),
          ),
      ],
      children: [
        if (items.isEmpty)
          const EmptyState(icon: Icons.notifications_off_outlined, title: 'No notifications', message: 'Reminders and alerts will show up here.')
        else
          for (final n in items)
            AppListTile(
              onTap: () {
                ref.read(notificationsProvider.notifier).markRead(n.id);
                if (n.route != null) context.push(n.route!);
              },
              title: n.title,
              titleStyle: AppText.cardTitle.copyWith(fontSize: 15, fontWeight: n.read ? FontWeight.w500 : FontWeight.w600),
              subtitle: n.body,
              meta: Text(Fmt.timeAgo(n.at), style: AppText.caption),
              trailing: n.read ? null : Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
            ),
      ],
    );
  }
}
