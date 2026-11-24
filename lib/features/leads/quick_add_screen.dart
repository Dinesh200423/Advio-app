import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lead.dart';
import '../clients/client_providers.dart';
import '../team/team_providers.dart';
import 'lead_duplicates.dart';
import 'lead_providers.dart';

/// Fast entry for businesses found by searching Google Maps or a directory by hand.
///
/// Built to be used many times in a row: saving clears the form but keeps the source and the area,
/// because a search session usually covers one area at a time.
class QuickAddScreen extends ConsumerStatefulWidget {
  const QuickAddScreen({super.key});

  @override
  ConsumerState<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends ConsumerState<QuickAddScreen> {
  static const _sources = [LeadSource.googleMaps, LeadSource.directory, LeadSource.coldOutreach];

  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _area = TextEditingController();
  final _website = TextEditingController();
  final _category = TextEditingController();
  final _nameFocus = FocusNode();

  LeadSource _source = LeadSource.googleMaps;
  bool _noWebsite = false;
  int _added = 0;

  /// Set when the last save attempt found a likely duplicate. Saving again confirms "add anyway".
  DuplicateMatch? _duplicate;

  @override
  void dispose() {
    for (final c in [_name, _phone, _area, _website, _category]) {
      c.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final website = _noWebsite ? '' : _website.text.trim();
    if (_duplicate == null) {
      final match = findDuplicate(
        name: _name.text,
        phone: _phone.text,
        website: website,
        location: _area.text,
        leads: ref.read(leadsProvider),
        clients: ref.read(clientsProvider),
      );
      if (match != null) {
        setState(() => _duplicate = match);
        return;
      }
    }

    final notes = <String>[
      if (_category.text.trim().isNotEmpty) 'Type of business: ${_category.text.trim()}.',
      if (_noWebsite) 'No website found when searching.',
    ];
    final now = DateTime.now();
    ref
        .read(leadsProvider.notifier)
        .create(
          Lead(
            id: newId('lead'),
            name: _name.text.trim(),
            company: '',
            email: '',
            phone: _phone.text.trim(),
            source: _source,
            status: LeadStatus.newLead,
            service: _noWebsite ? ServiceInterest.website : ServiceInterest.other,
            ownerId: ref.read(currentMemberIdProvider),
            website: website,
            location: _area.text.trim(),
            notes: [if (notes.isNotEmpty) Note(id: newId('note'), text: notes.join(' '), at: now)],
            createdAt: now,
          ),
        );

    // Ready for the next one: clear what belongs to this business, keep the source and the area.
    _name.clear();
    _phone.clear();
    _website.clear();
    _category.clear();
    setState(() {
      _noWebsite = false;
      _duplicate = null;
      _added++;
    });
    AppSnack.success(context, 'Saved. Add the next one.');
    _nameFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final dup = _duplicate;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => context.popOr(Routes.leads)),
        title: const Text('Quick add'),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: Column(
              children: [
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 24),
                      children: [
                        Text(
                          'For businesses you find on Google Maps or in a directory. Saving keeps the area, so you can add the next one straight away.',
                          style: AppText.caption,
                        ),
                        const SizedBox(height: 16),
                        if (dup != null) ...[
                          AppCard(
                            shadow: false,
                            color: AppColors.tint(AppColors.warning, 0.1),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dup.isClient ? 'Already a client' : 'Already in your leads', style: AppText.bodyStrong),
                                const SizedBox(height: 4),
                                Text('${dup.name} has the ${dup.reason}.', style: AppText.body),
                                if (dup.leadId != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton(onPressed: () => context.push(Routes.lead(dup.leadId!)), child: const Text('Open that lead')),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in _sources)
                              ChoiceChip(label: Text(s.label), selected: _source == s, onSelected: (_) => setState(() => _source = s)),
                          ],
                        ),
                        const FormGap(),
                        AppTextField(
                          controller: _name,
                          focusNode: _nameFocus,
                          label: 'Business name',
                          hint: 'e.g. Saravana Dental Clinic',
                          required: true,
                          autofocus: true,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearDuplicate(),
                          validator: (v) => Validators.required(v, 'Business name'),
                        ),
                        const FormGap(),
                        AppTextField(
                          controller: _phone,
                          label: 'Phone',
                          hint: '98765 43210',
                          required: true,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearDuplicate(),
                          validator: (v) => Validators.phone(v, requiredField: true),
                        ),
                        const FormGap(),
                        AppTextField(
                          controller: _area,
                          label: 'Area',
                          hint: 'e.g. Velachery, Chennai',
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _clearDuplicate(),
                        ),
                        const FormGap(),
                        AppTextField(
                          controller: _category,
                          label: 'Type of business',
                          hint: 'e.g. Dental clinic',
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                        ),
                        const FormGap(),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('No website found'),
                          subtitle: const Text('A business without a website is your best prospect for a website project.'),
                          value: _noWebsite,
                          onChanged: (v) => setState(() {
                            _noWebsite = v;
                            _duplicate = null;
                          }),
                        ),
                        if (!_noWebsite) ...[
                          const SizedBox(height: 8),
                          AppTextField(
                            controller: _website,
                            label: 'Website',
                            hint: 'example.com',
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => _clearDuplicate(),
                            onSubmitted: (_) => _save(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AppButton.secondary(
                          label: _added == 0 ? 'Cancel' : 'Done ($_added added)',
                          onPressed: () => context.popOr(Routes.leads),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppButton(label: dup != null ? 'Add anyway' : 'Save and add next', onPressed: _save),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearDuplicate() {
    if (_duplicate != null) setState(() => _duplicate = null);
  }
}
