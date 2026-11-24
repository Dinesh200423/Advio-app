import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import 'settings_providers.dart';

class ProfileFormScreen extends ConsumerStatefulWidget {
  const ProfileFormScreen({super.key});

  @override
  ConsumerState<ProfileFormScreen> createState() => _ProfileFormScreenState();
}

class _ProfileFormScreenState extends ConsumerState<ProfileFormScreen> {
  late final _s = ref.read(settingsProvider);
  late final _name = TextEditingController(text: _s.name);
  late final _email = TextEditingController(text: _s.email);
  late final _phone = TextEditingController(text: _s.phone);
  late final _headline = TextEditingController(text: _s.headline);

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _headline]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Profile',
      successMessage: 'Profile updated',
      onSubmit: () {
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(
              name: _name.text.trim(),
              email: _email.text.trim(),
              phone: _phone.text.trim(),
              headline: _headline.text.trim(),
            ));
        return true;
      },
      children: [
        Center(child: InitialsAvatar(name: _name.text.isEmpty ? _s.name : _name.text, size: 80)),
        const FormGap(height: 24),
        AppTextField(controller: _name, label: 'Full name', required: true, textCapitalization: TextCapitalization.words, onChanged: (_) => setState(() {}), validator: (v) => Validators.required(v, 'Name')),
        const FormGap(),
        AppTextField(controller: _email, label: 'Email', required: true, keyboardType: TextInputType.emailAddress, validator: Validators.email),
        const FormGap(),
        AppTextField(controller: _phone, label: 'Phone', keyboardType: TextInputType.phone, validator: Validators.phone),
        const FormGap(),
        AppTextField(controller: _headline, label: 'Headline', hint: 'e.g. Founder'),
      ],
    );
  }
}

class BusinessFormScreen extends ConsumerStatefulWidget {
  const BusinessFormScreen({super.key});

  @override
  ConsumerState<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends ConsumerState<BusinessFormScreen> {
  late final _s = ref.read(settingsProvider);
  late final _name = TextEditingController(text: _s.businessName);
  late final _address = TextEditingController(text: _s.businessAddress);
  late final _taxId = TextEditingController(text: _s.taxId);
  late final _website = TextEditingController(text: _s.website);

  @override
  void dispose() {
    for (final c in [_name, _address, _taxId, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Business information',
      successMessage: 'Business details updated',
      onSubmit: () {
        ref.read(settingsProvider.notifier).update((s) => s.copyWith(
              businessName: _name.text.trim(),
              businessAddress: _address.text.trim(),
              taxId: _taxId.text.trim(),
              website: _website.text.trim(),
            ));
        return true;
      },
      children: [
        AppTextField(controller: _name, label: 'Business name', required: true, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Business name')),
        const FormGap(),
        AppTextField(controller: _address, label: 'Address', maxLines: 3),
        const FormGap(),
        AppTextField(controller: _taxId, label: 'Tax ID (GSTIN / VAT)', textCapitalization: TextCapitalization.characters),
        const FormGap(),
        AppTextField(controller: _website, label: 'Website', keyboardType: TextInputType.url),
      ],
    );
  }
}
