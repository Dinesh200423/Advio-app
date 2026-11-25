import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/modules.dart';
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
  late Set<AppModule> _modules = {...(_existing?.modules ?? AppModule.defaultsFor(_role))};

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
          notifier.upsert(_existing.copyWith(name: _name.text.trim(), role: _role, email: _email.text.trim(), phone: _phone.text.trim(), modules: _modules));
        } else {
          notifier.add(TeamMember(
            id: newId('tm'),
            name: _name.text.trim(),
            role: _role,
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            joinedAt: DateTime.now(),
            modules: _modules,
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Name', required: true, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Name')),
        const FormGap(),
        AppDropdown<TeamRole>(label: 'Role', items: TeamRole.values, value: _role, labelOf: (r) => r.label, onChanged: (v) => setState(() {
          final next = v ?? _role;
          // Follow the new role's usual access, unless the switches were already changed by hand.
          if (_modules.length == AppModule.defaultsFor(_role).length && _modules.containsAll(AppModule.defaultsFor(_role))) {
            _modules = {...AppModule.defaultsFor(next)};
          }
          _role = next;
        })),
        const FormGap(),
        AppTextField(controller: _email, label: 'Email', hint: 'Optional', keyboardType: TextInputType.emailAddress, validator: (v) => Validators.email(v, requiredField: false)),
        const FormGap(),
        AppTextField(controller: _phone, label: 'Phone', hint: 'Optional', keyboardType: TextInputType.phone, validator: Validators.phone),
        const FormGap(height: 28),
        const FormSectionTitle('What they can use'),
        Text(
          _role == TeamRole.founder
              ? 'The founder can use everything.'
              : 'Switched-off areas are hidden from them. They can still see items assigned to them in Leads, Tasks and Support, but cannot change them.',
          style: AppText.caption,
        ),
        const SizedBox(height: 8),
        for (final module in AppModule.values)
          SwitchListTile(
            key: ValueKey('module-${module.name}'),
            contentPadding: EdgeInsets.zero,
            title: Text(module.label),
            subtitle: Text(module.description),
            value: _role == TeamRole.founder || _modules.contains(module),
            onChanged: _role == TeamRole.founder
                ? null
                : (on) => setState(() => on ? _modules.add(module) : _modules.remove(module)),
          ),
      ],
    );
  }
}
