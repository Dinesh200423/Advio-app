import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lead.dart';
import '../team/team_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'lead_providers.dart';

/// Add / edit lead. Pass [id] to edit.
class LeadFormScreen extends ConsumerStatefulWidget {
  const LeadFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<LeadFormScreen> createState() => _LeadFormScreenState();
}

class _LeadFormScreenState extends ConsumerState<LeadFormScreen> {
  late final Lead? _existing = widget.id == null ? null : ref.read(leadsProvider.notifier).byId(widget.id);
  late final _name = TextEditingController(text: _existing?.name);
  late final _company = TextEditingController(text: _existing?.company);
  late final _email = TextEditingController(text: _existing?.email);
  late final _phone = TextEditingController(text: _existing?.phone);
  late final _value = TextEditingController(text: _existing == null || _existing.estimatedValue == 0 ? '' : _existing.estimatedValue.toStringAsFixed(0));
  late final _interest = TextEditingController(text: _existing?.interest);
  late LeadSource _source = _existing?.source ?? LeadSource.website;
  late LeadStatus _status = _existing?.status ?? LeadStatus.newLead;
  late ServiceInterest _service = _existing?.service ?? ServiceInterest.website;
  late BudgetBand? _budget = _existing?.budget;
  // New leads start owned by whoever adds them.
  late String? _ownerId = _existing == null ? ref.read(currentMemberIdProvider) : _existing.ownerId;

  @override
  void dispose() {
    for (final c in [_name, _company, _email, _phone, _value, _interest]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Lead', fallback: Routes.leads);
    final editing = _existing != null;

    return FormPage(
      title: editing ? 'Edit lead' : 'Add lead',
      submitLabel: editing ? 'Save changes' : 'Add lead',
      successMessage: editing ? 'Lead updated' : 'Lead added',
      onSubmit: () {
        final notifier = ref.read(leadsProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            source: _source,
            estimatedValue: parseAmount(_value.text),
            service: _service,
            budget: _budget,
            ownerId: _ownerId,
            interest: _interest.text.trim(),
          ));
          notifier.changeStatus(_existing.id, _status);
        } else {
          notifier.create(Lead(
            id: newId('lead'),
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            source: _source,
            status: _status,
            estimatedValue: parseAmount(_value.text),
            service: _service,
            budget: _budget,
            ownerId: _ownerId,
            interest: _interest.text.trim(),
            createdAt: DateTime.now(),
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Contact name', hint: 'e.g. Neha Verma', required: true, icon: Icons.person_outline_rounded, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Name')),
        const FormGap(),
        AppTextField(controller: _company, label: 'Company', hint: 'e.g. Craftly Marketplace', icon: Icons.business_outlined, textCapitalization: TextCapitalization.words),
        const FormGap(),
        AppTextField(controller: _email, label: 'Email', hint: 'name@company.com', required: true, icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: Validators.email),
        const FormGap(),
        AppTextField(controller: _phone, label: 'Phone', hint: '+91 98765 43210', icon: Icons.call_outlined, keyboardType: TextInputType.phone, validator: Validators.phone),
        const FormGap(),
        AppDropdown<ServiceInterest>(label: 'Service', items: ServiceInterest.values, value: _service, labelOf: (s) => s.label, onChanged: (v) => setState(() => _service = v ?? _service)),
        const FormGap(),
        AppDropdown<BudgetBand?>(
          label: 'Budget',
          hint: 'Not given',
          items: [null, ...BudgetBand.values],
          value: _budget,
          labelOf: (b) => b?.label ?? 'Not given',
          onChanged: (b) => setState(() {
            _budget = b;
            // Give the deal value a sensible starting point, but never overwrite what was typed.
            if (b != null && b.typicalValue > 0 && _value.text.trim().isEmpty) _value.text = b.typicalValue.toStringAsFixed(0);
          }),
        ),
        const FormGap(),
        AppDropdown<LeadSource>(label: 'Source', items: LeadSource.values, value: _source, labelOf: (s) => s.label, onChanged: (v) => setState(() => _source = v ?? _source)),
        const FormGap(),
        AppDropdown<LeadStatus>(label: 'Status', items: LeadStatus.values, value: _status, labelOf: (s) => s.label, onChanged: (v) => setState(() => _status = v ?? _status)),
        const FormGap(),
        AssigneeDropdown(label: 'Owner', value: _ownerId, onChanged: (v) => setState(() => _ownerId = v)),
        const FormGap(),
        AppAmountField(controller: _value, label: 'Estimated value', hint: '0', validator: (v) => (v == null || v.isEmpty) ? null : Validators.amount(v, label: 'Value', allowZero: true)),
        const FormGap(),
        AppTextField(controller: _interest, label: 'Project overview', hint: 'What do they want to build?', maxLines: 3),
      ],
    );
  }
}
