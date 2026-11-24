import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/project.dart';
import '../../data/repositories/repositories.dart';
import '../../data/repositories/repository.dart';
import '../dashboard/activity_providers.dart';
import '../tasks/task_providers.dart';

class ProjectsNotifier extends CrudNotifier<Project> {
  @override
  Repository<Project> get repository => ref.read(projectRepositoryProvider);
  @override
  String idOf(Project item) => item.id;

  ActivityEntry _entry(String title, [String? detail]) =>
      ActivityEntry.now(title, detail: detail, kind: ActivityKind.project);

  void create(Project p) {
    upsert(p.copyWith(history: [_entry('Project created')]));
    ref.read(activityProvider.notifier).log('Project created', detail: p.name, kind: ActivityKind.project);
  }

  void setStatus(String id, ProjectStatus status) {
    final p = byId(id);
    if (p == null || p.status == status) return;
    upsert(p.copyWith(status: status, history: [_entry('Status changed to ${status.label}'), ...p.history]));
  }

  void toggleMilestone(String id, String milestoneId) => modify(id, (p) {
        final m = p.milestones.firstWhere((m) => m.id == milestoneId);
        return p.copyWith(
          milestones: [for (final x in p.milestones) x.id == milestoneId ? x.copyWith(done: !x.done) : x],
          history: m.done ? p.history : [_entry('Milestone "${m.title}" completed'), ...p.history],
        );
      });

  void addMilestone(String id, Milestone m) => modify(
        id,
        (p) => p.copyWith(
          milestones: [...p.milestones, m]..sort((a, b) => a.dueDate.compareTo(b.dueDate)),
          history: [_entry('Milestone added', m.title), ...p.history],
        ),
      );

  void addFile(String id, ProjectFile f) => modify(
        id,
        (p) => p.copyWith(files: [f, ...p.files], history: [_entry('File uploaded', f.name), ...p.history]),
      );

  void removeFile(String id, String fileId) =>
      modify(id, (p) => p.copyWith(files: p.files.where((f) => f.id != fileId).toList()));
}

final projectsProvider = NotifierProvider<ProjectsNotifier, List<Project>>(ProjectsNotifier.new);

final projectProvider = Provider.family<Project?, String>((ref, id) {
  for (final p in ref.watch(projectsProvider)) {
    if (p.id == id) return p;
  }
  return null;
});

final projectNameProvider = Provider.family<String?, String?>((ref, id) {
  if (id == null) return null;
  return ref.watch(projectProvider(id))?.name;
});

/// 0..1 progress of a project (milestones + tasks).
final projectProgressProvider = Provider.family<double, String>((ref, id) {
  final p = ref.watch(projectProvider(id));
  if (p == null) return 0;
  return p.progress(ref.watch(projectTasksProvider(id)));
});

final clientProjectsProvider = Provider.family<List<Project>, String>(
  (ref, clientId) => ref.watch(projectsProvider).where((p) => p.clientId == clientId).toList(),
);

/// Upcoming project/milestone deadlines within the next [days], soonest first.
class Deadline {
  const Deadline({required this.title, required this.subtitle, required this.date, required this.route, required this.isMilestone});
  final String title;
  final String subtitle;
  final DateTime date;
  final String route;
  final bool isMilestone;
}

final upcomingDeadlinesProvider = Provider<List<Deadline>>((ref) {
  final out = <Deadline>[];
  for (final p in ref.watch(projectsProvider)) {
    if (p.status != ProjectStatus.active && p.status != ProjectStatus.planned) continue;
    for (final m in p.milestones.where((m) => !m.done)) {
      final d = daysUntil(m.dueDate);
      if (d >= 0 && d <= 14) {
        out.add(Deadline(title: m.title, subtitle: p.name, date: m.dueDate, route: '/projects/${p.id}', isMilestone: true));
      }
    }
    final d = daysUntil(p.endDate);
    if (d >= 0 && d <= 14) {
      out.add(Deadline(title: '${p.name} delivery', subtitle: 'Project deadline', date: p.endDate, route: '/projects/${p.id}', isMilestone: false));
    }
  }
  out.sort((a, b) => a.date.compareTo(b.date));
  return out;
});
