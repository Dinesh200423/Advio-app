import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/client.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import 'client_providers.dart';

class ClientFormScreen extends ConsumerStatefulWidget {
  const ClientFormScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  late final Client? _existing = widget.id == null ? null : ref.read(clientsProvider.notifier).byId(widget.id);
  late final _name = TextEditingController(text: _existing?.name);
  late final _company = TextEditingController(text: _existing?.company);
  late final _email = TextEditingController(text: _existing?.email);
  late final _phone = TextEditingController(text: _existing?.phone);
  late final _address = TextEditingController(text: _existing?.address);
  late final _website = TextEditingController(text: _existing?.website);
  late ClientStatus _status = _existing?.status ?? ClientStatus.active;

  @override
  void dispose() {
    for (final c in [_name, _company, _email, _phone, _address, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Client', fallback: Routes.clients);
    final editing = _existing != null;

    return FormPage(
      title: editing ? 'Edit client' : 'Add client',
      submitLabel: editing ? 'Save changes' : 'Add client',
      successMessage: editing ? 'Client updated' : 'Client added',
      onSubmit: () {
        final notifier = ref.read(clientsProvider.notifier);
        if (editing) {
          notifier.upsert(_existing.copyWith(
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            website: _website.text.trim(),
            status: _status,
          ));
        } else {
          notifier.create(Client(
            id: newId('client'),
            name: _name.text.trim(),
            company: _company.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            address: _address.text.trim(),
            website: _website.text.trim(),
            status: _status,
            createdAt: DateTime.now(),
          ));
        }
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Contact name', required: true, hint: 'e.g. Aarav Mehta', icon: Icons.person_outline_rounded, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Name')),
        const FormGap(),
        AppTextField(controller: _company, label: 'Company', hint: 'e.g. Nova Retail Pvt Ltd', icon: Icons.business_outlined, textCapitalization: TextCapitalization.words),
        const FormGap(),
        AppTextField(controller: _email, label: 'Email', required: true, hint: 'name@company.com', icon: Icons.mail_outline_rounded, keyboardType: TextInputType.emailAddress, validator: Validators.email),
        const FormGap(),
        AppTextField(controller: _phone, label: 'Phone', hint: '+91 98765 43210', icon: Icons.call_outlined, keyboardType: TextInputType.phone, validator: Validators.phone),
        const FormGap(),
        AppTextField(controller: _website, label: 'Website', hint: 'example.com', icon: Icons.language_rounded, keyboardType: TextInputType.url),
        const FormGap(),
        AppTextField(controller: _address, label: 'Address', hint: 'Street, city, postcode', maxLines: 3),
        const FormGap(),
        AppDropdown<ClientStatus>(label: 'Status', items: ClientStatus.values, value: _status, labelOf: (s) => s.label, onChanged: (v) => setState(() => _status = v ?? _status)),
      ],
    );
  }
}
