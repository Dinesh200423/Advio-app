import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';

/// Business-wide activity feed shown on the dashboard.
class ActivityNotifier extends CrudNotifier<ActivityEntry> {
  @override
  bool get reportFailures => false;
  @override
  Repository<ActivityEntry> get repository => ref.read(activityRepositoryProvider);
  @override
  String idOf(ActivityEntry item) => item.id;

  /// Record something that just happened. Most recent first.
  void log(String title, {String? detail, ActivityKind kind = ActivityKind.note}) =>
      upsert(ActivityEntry.now(title, detail: detail, kind: kind));
}

final activityProvider = NotifierProvider<ActivityNotifier, List<ActivityEntry>>(ActivityNotifier.new);

class NotificationsNotifier extends CrudNotifier<AppNotification> {
  @override
  bool get reportFailures => false;
  @override
  Repository<AppNotification> get repository => ref.read(notificationRepositoryProvider);
  @override
  String idOf(AppNotification item) => item.id;

  void markRead(String id) => modify(id, (n) => n.copyWith(read: true));

  void markAllRead() {
    for (final n in state.where((n) => !n.read)) {
      upsert(n.copyWith(read: true));
    }
  }
}

final notificationsProvider =
    NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

final unreadNotificationsProvider =
    Provider<int>((ref) => ref.watch(notificationsProvider).where((n) => !n.read).length);
