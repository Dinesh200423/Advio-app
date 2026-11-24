import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/team.dart';
import 'team_providers.dart';

class MemberFormScreen extends ConsumerStatefulWidget {
  const MemberFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends ConsumerState<MemberFormScreen> {
  late final TeamMember? _existing = widget.id == null ? null : ref.read(teamProvider.notifier).byId(widget.id);
  late final _name = TextEditingController(text: _existing?.name);
  late final _email = TextEditingController(text: _existing?.email);
  late final _phone = TextEditingController(text: _existing?.phone);
  late TeamRole _role = _existing?.role ?? TeamRole.developer;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Team member', fallback: Routes.team);
    final editing = _existing != null;

    return FormPage(
      title: editing ? 'Edit member' : 'Add team member',
      submitLabel: editing ? 'Save changes' : 'Add member',
      successMessage: editing ? 'Member updated' : 'Member added',
      onSubmit: () {
        final notifier = ref.read(teamProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(name: _name.text.trim(), role: _role, email: _email.text.trim(), phone: _phone.text.trim()));
        } else {
          notifier.add(TeamMember(
            id: newId('tm'),
            name: _name.text.trim(),
            role: _role,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            joinedAt: DateTime.now(),
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Name', required: true, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Name')),
        const FormGap(),
        AppDropdown<TeamRole>(label: 'Role', items: TeamRole.values, value: _role, labelOf: (r) => r.label, onChanged: (v) => setState(() => _role = v ?? _role)),
        const FormGap(),
        AppTextField(controller: _email, label: 'Email', hint: 'Optional', keyboardType: TextInputType.emailAddress, validator: (v) => Validators.email(v, requiredField: false)),
        const FormGap(),
        AppTextField(controller: _phone, label: 'Phone', hint: 'Optional', keyboardType: TextInputType.phone, validator: Validators.phone),
      ],
    );
  }
}
