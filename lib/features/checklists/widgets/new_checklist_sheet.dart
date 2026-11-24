import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../projects/project_providers.dart';
import '../checklist_providers.dart';

/// Start a checklist for a project from one of the templates.
/// Pass [projectId] to lock the project (when opened from a project page).
Future<void> showNewChecklistSheet(BuildContext context, {String? projectId}) {
  return showAppSheet<void>(context, title: 'Start a checklist', builder: (_) => _NewChecklistForm(projectId: projectId));
}

class _NewChecklistForm extends ConsumerStatefulWidget {
  const _NewChecklistForm({this.projectId});
  final String? projectId;

  @override
  ConsumerState<_NewChecklistForm> createState() => _NewChecklistFormState();
}

class _NewChecklistFormState extends ConsumerState<_NewChecklistForm> {
  final _key = GlobalKey<FormState>();
  late String? _projectId = widget.projectId;
  String? _templateId;
  int _monthOffset = 0;

  String _month(int offset) {
    final n = DateTime.now();
    return DateFormat('MMMM yyyy').format(DateTime(n.year, n.month + offset));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final templates = ref.watch(templatesProvider);
    final template = templates.where((t) => t.id == _templateId).firstOrNull;

    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.projectId == null) ...[
            AppDropdown<String>(
              label: 'Project',
              required: true,
              hint: 'Choose a project',
              items: [for (final p in projects) p.id],
              value: _projectId,
              labelOf: (id) => projects.firstWhere((p) => p.id == id).name,
              validator: (v) => v == null ? 'Choose a project' : null,
              onChanged: (v) => setState(() => _projectId = v),
            ),
            const SizedBox(height: 16),
          ],
          AppDropdown<String>(
            label: 'Template',
            required: true,
            hint: 'Choose a service template',
            items: [for (final t in templates) t.id],
            value: _templateId,
            labelOf: (id) => templates.firstWhere((t) => t.id == id).name,
            validator: (v) => v == null ? 'Choose a template' : null,
            onChanged: (v) => setState(() => _templateId = v),
          ),
          if (template != null) ...[
            const SizedBox(height: 8),
            Text('${template.stageCount} stages · ${template.itemCount} items', style: AppText.caption),
          ],
          if (template?.isRecurring ?? false) ...[
            const SizedBox(height: 16),
            const FieldLabel('Service period'),
            FilterChipRow<int>(
              options: const [0, 1],
              allLabel: null,
              selected: _monthOffset,
              labelOf: _month,
              onSelected: (v) => setState(() => _monthOffset = v ?? 0),
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'This makes a separate copy for the project. Changing the template later will not change it.',
            style: AppText.caption.copyWith(color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Create checklist',
            onPressed: () {
              if (!_key.currentState!.validate()) return;
              final created = ref.read(checklistsProvider.notifier).createFromTemplate(
                    template!,
                    projectId: _projectId!,
                    period: template.isRecurring ? _month(_monthOffset) : null,
                  );
              Navigator.pop(context);
              AppSnack.success(context, 'Checklist created');
              context.push(Routes.checklist(created.id));
            },
          ),
        ],
      ),
    );
  }
}
