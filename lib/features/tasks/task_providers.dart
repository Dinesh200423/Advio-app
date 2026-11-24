import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/task.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';
import '../team/team_providers.dart';

class TasksNotifier extends CrudNotifier<Task> {
  @override
  Repository<Task> get repository => ref.read(taskRepositoryProvider);
  @override
  String idOf(Task item) => item.id;

  @override
  void upsert(Task item) {
    final before = byId(item.id);
    super.upsert(item);
    logAssignment(ref, what: 'Task', title: item.title, kind: ActivityKind.task, from: before?.assigneeId, to: item.assigneeId);
  }

  void create(Task task) {
    upsert(task);
    ref.read(activityProvider.notifier).log('Task created', detail: task.title, kind: ActivityKind.task);
  }

  void setStatus(String id, TaskStatus status) {
    final t = byId(id);
    if (t == null || t.status == status) return;
    upsert(t.copyWith(status: status));
    if (status == TaskStatus.completed) {
      ref.read(activityProvider.notifier).log('Task completed', detail: t.title, kind: ActivityKind.task);
    }
  }

  /// Checkbox interaction: complete, or reopen as "To Do".
  void toggle(String id) {
    final t = byId(id);
    if (t == null) return;
    setStatus(id, t.isDone ? TaskStatus.todo : TaskStatus.completed);
  }
}

final tasksProvider = NotifierProvider<TasksNotifier, List<Task>>(TasksNotifier.new);

final taskProvider = Provider.family<Task?, String>((ref, id) {
  for (final t in ref.watch(tasksProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

bool isTaskOverdue(Task t) => !t.isDone && daysUntil(t.dueDate) < 0;

/// Open tasks due today.
final todaysTasksProvider = Provider<List<Task>>((ref) =>
    ref.watch(tasksProvider).where((t) => !t.isDone && daysUntil(t.dueDate) == 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate)));

final overdueTasksProvider = Provider<List<Task>>((ref) =>
    ref.watch(tasksProvider).where(isTaskOverdue).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate)));

final upcomingTasksProvider = Provider<List<Task>>((ref) =>
    ref.watch(tasksProvider).where((t) => !t.isDone && daysUntil(t.dueDate) > 0).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate)));

/// Every task that still needs doing (overdue + today + upcoming).
final pendingTasksProvider = Provider<List<Task>>((ref) => ref.watch(tasksProvider).where((t) => !t.isDone).toList());

final projectTasksProvider = Provider.family<List<Task>, String>(
  (ref, projectId) => ref.watch(tasksProvider).where((t) => t.projectId == projectId).toList(),
);
