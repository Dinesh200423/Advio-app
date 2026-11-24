import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/support.dart';
import '../clients/client_providers.dart';
import '../team/team_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'support_providers.dart';

class TicketFormScreen extends ConsumerStatefulWidget {
  const TicketFormScreen({super.key, this.id, this.clientId});
  final String? id;
  final String? clientId;

  @override
  ConsumerState<TicketFormScreen> createState() => _TicketFormScreenState();
}

class _TicketFormScreenState extends ConsumerState<TicketFormScreen> {
  late final Ticket? _existing = widget.id == null ? null : ref.read(ticketsProvider.notifier).byId(widget.id);
  late final _title = TextEditingController(text: _existing?.title);
  late final _description = TextEditingController(text: _existing?.description);
  late String? _clientId = _existing?.clientId ?? widget.clientId;
  late Priority _priority = _existing?.priority ?? Priority.medium;
  late TicketStatus _status = _existing?.status ?? TicketStatus.open;
  late String? _assigneeId = _existing == null ? ref.read(currentMemberIdProvider) : _existing.assigneeId;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Ticket', fallback: Routes.support);
    final editing = _existing != null;
    final clients = ref.watch(clientsProvider);

    return FormPage(
      title: editing ? 'Edit ticket' : 'New ticket',
      submitLabel: editing ? 'Save changes' : 'Create ticket',
      successMessage: editing ? 'Ticket updated' : 'Ticket created',
      onSubmit: () {
        final notifier = ref.read(ticketsProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(
            title: _title.text.trim(),
            description: _description.text.trim(),
            clientId: _clientId,
            priority: _priority,
            assigneeId: _assigneeId,
          ));
          notifier.setStatus(_existing.id, _status);
        } else {
          notifier.create(Ticket(
            id: newId('ticket'),
            number: notifier.nextNumber(),
            title: _title.text.trim(),
            description: _description.text.trim(),
            clientId: _clientId!,
            priority: _priority,
            assigneeId: _assigneeId,
            createdAt: DateTime.now(),
          ));
        }
        return true;
      },
      children: [
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
        AppTextField(controller: _title, label: 'Issue', required: true, hint: 'Short summary of the problem', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Issue')),
        const FormGap(),
        AppTextField(controller: _description, label: 'Details', hint: 'What happened, steps to reproduce…', maxLines: 4),
        const FormGap(),
        const FieldLabel('Priority'),
        FilterChipRow<Priority>(options: Priority.values, selected: _priority, allLabel: null, labelOf: (p) => p.label, onSelected: (p) => setState(() => _priority = p ?? _priority)),
        const FormGap(),
        AssigneeDropdown(value: _assigneeId, onChanged: (v) => setState(() => _assigneeId = v)),
        if (editing) ...[
          const FormGap(),
          AppDropdown<TicketStatus>(label: 'Status', items: TicketStatus.values, value: _status, labelOf: (s) => s.label, onChanged: (v) => setState(() => _status = v ?? _status)),
        ],
      ],
    );
  }
}
