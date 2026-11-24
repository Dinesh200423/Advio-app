import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/project.dart';
import '../clients/client_providers.dart';
import '../team/team_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'project_providers.dart';

class ProjectFormScreen extends ConsumerStatefulWidget {
  const ProjectFormScreen({super.key, this.id, this.clientId});
  final String? id;
  final String? clientId;

  @override
  ConsumerState<ProjectFormScreen> createState() => _ProjectFormScreenState();
}

class _ProjectFormScreenState extends ConsumerState<ProjectFormScreen> {
  late final Project? _existing = widget.id == null ? null : ref.read(projectsProvider.notifier).byId(widget.id);
  late final _name = TextEditingController(text: _existing?.name);
  late final _budget = TextEditingController(text: _existing == null ? '' : _existing.budget.toStringAsFixed(0));
  late final _description = TextEditingController(text: _existing?.description);
  late String? _clientId = _existing?.clientId ?? widget.clientId;
  late ProjectStatus _status = _existing?.status ?? ProjectStatus.planned;
  late String? _ownerId = _existing == null ? ref.read(currentMemberIdProvider) : _existing.ownerId;
  late DateTime? _start = _existing?.startDate ?? DateTime.now();
  late DateTime? _end = _existing?.endDate ?? DateTime.now().add(const Duration(days: 30));

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Project', fallback: Routes.projects);
    final editing = _existing != null;
    final clients = ref.watch(clientsProvider);

    return FormPage(
      title: editing ? 'Edit project' : 'Create project',
      submitLabel: editing ? 'Save changes' : 'Create project',
      successMessage: editing ? 'Project updated' : 'Project created',
      onSubmit: () {
        final notifier = ref.read(projectsProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(
            name: _name.text.trim(),
            clientId: _clientId,
            status: _status,
            budget: parseAmount(_budget.text),
            startDate: _start,
            endDate: _end,
            description: _description.text.trim(),
            ownerId: _ownerId,
          ));
        } else {
          notifier.create(Project(
            id: newId('project'),
            name: _name.text.trim(),
            clientId: _clientId!,
            status: _status,
            budget: parseAmount(_budget.text),
            startDate: _start!,
            endDate: _end!,
            description: _description.text.trim(),
            ownerId: _ownerId,
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Project name', required: true, hint: 'e.g. Website redesign', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Project name')),
        const FormGap(),
        AppDropdown<String>(
          label: 'Client',
          required: true,
          hint: 'Select a client',
          items: [for (final c in clients) c.id],
          value: _clientId,
          labelOf: (id) => clients.firstWhere((c) => c.id == id).displayName,
          validator: (v) => v == null ? 'Please choose a client' : null,
          onChanged: (v) => setState(() => _clientId = v),
        ),
        const FormGap(),
        AppDropdown<ProjectStatus>(label: 'Status', items: ProjectStatus.values, value: _status, labelOf: (s) => s.label, onChanged: (v) => setState(() => _status = v ?? _status)),
        const FormGap(),
        AssigneeDropdown(label: 'Project owner', value: _ownerId, onChanged: (v) => setState(() => _ownerId = v)),
        const FormGap(),
        AppAmountField(controller: _budget, label: 'Budget', required: true, validator: (v) => Validators.amount(v, label: 'Budget')),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppDateField(label: 'Start date', value: _start, required: true, onChanged: (d) => setState(() => _start = d))),
            const SizedBox(width: 12),
            Expanded(
              child: AppDateField(
                label: 'End date',
                value: _end,
                required: true,
                onChanged: (d) => setState(() => _end = d),
                validator: (v) => v != null && _start != null && v.isBefore(_start!) ? 'Must be after start' : (v == null ? 'End date is required' : null),
              ),
            ),
          ],
        ),
        const FormGap(),
        AppTextField(controller: _description, label: 'Description', hint: 'Scope, deliverables, notes…', maxLines: 4),
      ],
    );
  }
}
