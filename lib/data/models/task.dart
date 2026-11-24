import 'enums.dart';

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.dueDate,
    required this.createdAt,
    this.description = '',
    this.projectId,
    this.priority = Priority.medium,
    this.status = TaskStatus.todo,
    this.assigneeId,
  });

  final String id;
  final String title;
  final String description;
  final String? projectId;
  final Priority priority;
  final TaskStatus status;
  final DateTime dueDate;
  final DateTime createdAt;

  /// Team member this is assigned to; null means unassigned.
  final String? assigneeId;

  bool get isDone => status == TaskStatus.completed;

  Task copyWith({
    String? title,
    String? description,
    Object? projectId = _unset,
    Priority? priority,
    TaskStatus? status,
    DateTime? dueDate,
    Object? assigneeId = _unset,
  }) =>
      Task(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
        assigneeId: identical(assigneeId, _unset) ? this.assigneeId : assigneeId as String?,
      );
}

const _unset = Object();
