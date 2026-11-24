import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import 'project_providers.dart';
import 'widgets/project_tile.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  String _query = '';
  ProjectStatus? _status;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(projectsProvider);
    final q = _query.trim().toLowerCase();
    final projects = all.where((p) {
      if (_status != null && p.status != _status) return false;
      return q.isEmpty || p.name.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        // Active first, then by nearest end date.
        final ra = a.status == ProjectStatus.active ? 0 : 1;
        final rb = b.status == ProjectStatus.active ? 0 : 1;
        return ra != rb ? ra.compareTo(rb) : a.endDate.compareTo(b.endDate);
      });

    final active = all.where((p) => p.status == ProjectStatus.active);
    final activeBudget = active.fold<double>(0, (s, p) => s + p.budget);
    final dueSoon = active.where((p) => daysUntil(p.endDate) >= 0 && daysUntil(p.endDate) <= 14).length;
    final filtering = q.isNotEmpty || _status != null;

    return PageScaffold(
      title: 'Projects',
      subtitle: '${active.length} active · ${ref.money(activeBudget, compact: true)} in progress',
      large: true,
      onRefresh: () => mockRefresh(context),
      actions: [
        IconButton.filled(
          tooltip: 'Create project',
          onPressed: () => context.push(Routes.projectNew()),
          icon: const Icon(Icons.add_rounded),
          style: IconButton.styleFrom(backgroundColor: AppColors.primary, minimumSize: const Size(48, 48)),
        ),
      ],
      children: [
        MetricGrid(
          children: [
            MetricCard(label: 'Active', value: '${active.length}', caption: '$dueSoon due within 2 weeks', captionColor: dueSoon > 0 ? AppColors.warning : null),
            MetricCard(label: 'Active budget', value: ref.money(activeBudget, compact: true), color: AppColors.secondary),
            MetricCard(label: 'Completed', value: '${all.where((p) => p.status == ProjectStatus.completed).length}', color: AppColors.success),
            MetricCard(label: 'On hold', value: '${all.where((p) => p.status == ProjectStatus.onHold).length}', color: AppColors.warning),
          ],
        ),
        const SizedBox(height: 24),
        AppSearchBar(hint: 'Search projects', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<ProjectStatus>(
          options: ProjectStatus.values,
          selected: _status,
          labelOf: (s) => s.label,
          countOf: (s) => s == null ? all.length : all.where((p) => p.status == s).length,
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 16),
        if (projects.isEmpty)
          EmptyState(
            icon: filtering ? Icons.search_off_rounded : Icons.folder_open_rounded,
            title: filtering ? 'No projects match' : 'No projects yet',
            message: filtering ? 'Try another status or search term.' : 'Create a project to start tracking work.',
            actionLabel: filtering ? 'Clear filters' : 'Create project',
            onAction: filtering ? () => setState(() {
                  _query = '';
                  _status = null;
                }) : () => context.push(Routes.projectNew()),
          )
        else
          for (final p in projects) ProjectTile(project: p),
      ],
    );
  }
}
