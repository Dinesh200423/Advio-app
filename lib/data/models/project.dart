import 'common.dart';
import 'enums.dart';
import 'task.dart';

class Milestone {
  const Milestone({
    required this.id,
    required this.title,
    required this.dueDate,
    this.amount = 0,
    this.done = false,
  });

  final String id;
  final String title;
  final DateTime dueDate;
  final double amount;
  final bool done;

  Milestone copyWith({bool? done}) =>
      Milestone(id: id, title: title, dueDate: dueDate, amount: amount, done: done ?? this.done);
}

class ProjectFile {
  const ProjectFile({required this.id, required this.name, required this.sizeKb, required this.addedAt});
  final String id;
  final String name;
  final int sizeKb;
  final DateTime addedAt;

  String get extension => name.contains('.') ? name.split('.').last.toLowerCase() : '';
}

class Project {
  const Project({
    required this.id,
    required this.name,
    required this.clientId,
    required this.status,
    required this.budget,
    required this.startDate,
    required this.endDate,
    this.description = '',
    this.ownerId,
    this.milestones = const [],
    this.files = const [],
    this.history = const [],
  });

  final String id;
  final String name;
  final String clientId;
  final ProjectStatus status;
  final double budget;
  final DateTime startDate;
  final DateTime endDate;
  final String description;

  /// Team member running the project; null means unassigned.
  final String? ownerId;
  final List<Milestone> milestones;
  final List<ProjectFile> files;
  final List<ActivityEntry> history;

  /// 0..1 completion based on milestones and tasks together.
  double progress(Iterable<Task> projectTasks) {
    if (status == ProjectStatus.completed) return 1;
    final tasks = projectTasks.toList();
    final total = milestones.length + tasks.length;
    if (total == 0) return 0;
    final done = milestones.where((m) => m.done).length + tasks.where((t) => t.status == TaskStatus.completed).length;
    return done / total;
  }

  Project copyWith({
    String? name,
    String? clientId,
    ProjectStatus? status,
    double? budget,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    Object? ownerId = _unset,
    List<Milestone>? milestones,
    List<ProjectFile>? files,
    List<ActivityEntry>? history,
  }) =>
      Project(
        id: id,
        name: name ?? this.name,
        clientId: clientId ?? this.clientId,
        status: status ?? this.status,
        budget: budget ?? this.budget,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        description: description ?? this.description,
        ownerId: identical(ownerId, _unset) ? this.ownerId : ownerId as String?,
        milestones: milestones ?? this.milestones,
        files: files ?? this.files,
        history: history ?? this.history,
      );
}

const _unset = Object();
