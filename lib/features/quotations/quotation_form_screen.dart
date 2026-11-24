import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/quotation.dart';
import '../../shared/widgets/document_widgets.dart';
import '../../shared/widgets/line_items_editor.dart';
import '../clients/client_providers.dart';
import '../settings/settings_providers.dart';
import 'quotation_providers.dart';

const defaultTerms = '50% advance to begin work. Balance on delivery. Payment within 14 days of invoice date.';

class QuotationFormScreen extends ConsumerStatefulWidget {
  const QuotationFormScreen({super.key, this.id, this.clientId});
  final String? id;
  final String? clientId;

  @override
  ConsumerState<QuotationFormScreen> createState() => _QuotationFormScreenState();
}

class _QuotationFormScreenState extends ConsumerState<QuotationFormScreen> {
  late final Quotation? _existing = widget.id == null ? null : ref.read(quotationsProvider.notifier).byId(widget.id);
  late final _title = TextEditingController(text: _existing?.title);
  late final _discount = TextEditingController(text: _existing == null || _existing.discountPercent == 0 ? '' : _existing.discountPercent.toString());
  late final _tax = TextEditingController(text: (_existing?.taxPercent ?? ref.read(settingsProvider).defaultTaxPercent).toString());
  late final _notes = TextEditingController(text: _existing?.notes);
  late final _terms = TextEditingController(text: _existing?.terms ?? defaultTerms);
  late String? _clientId = _existing?.clientId ?? widget.clientId;
  late DateTime? _issued = _existing?.issueDate ?? DateTime.now();
  late DateTime? _validUntil = _existing?.validUntil ?? DateTime.now().add(const Duration(days: 14));
  late List<LineItem> _items = _existing?.items ?? const [];

  @override
  void dispose() {
    for (final c in [_title, _discount, _tax, _notes, _terms]) {
      c.dispose();
    }
    super.dispose();
  }

  Quotation _build(String id, String number, QuotationStatus status) => Quotation(
        id: id,
        number: number,
        clientId: _clientId!,
        title: _title.text.trim(),
        items: _items,
        issueDate: _issued!,
        validUntil: _validUntil!,
        status: status,
        discountPercent: parseAmount(_discount.text),
        taxPercent: parseAmount(_tax.text),
        notes: _notes.text.trim(),
        terms: _terms.text.trim(),
      );

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Quotation', fallback: Routes.quotations);
    final editing = _existing != null;
    final clients = ref.watch(clientsProvider);

    return FormPage(
      title: editing ? 'Edit quotation' : 'New quotation',
      submitLabel: editing ? 'Save changes' : 'Save quotation',
      successMessage: editing ? 'Quotation updated' : 'Quotation saved as draft',
      onSubmit: () {
        final notifier = ref.read(quotationsProvider.notifier);
        if (editing) {
          notifier.upsert(_build(_existing.id, _existing.number, _existing.status));
        } else {
          notifier.create(_build(newId('quote'), notifier.nextNumber(), QuotationStatus.draft));
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
        AppTextField(controller: _title, label: 'Title', required: true, hint: 'e.g. Website redesign', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Title')),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppDateField(label: 'Issue date', value: _issued, required: true, onChanged: (d) => setState(() => _issued = d))),
            const SizedBox(width: 12),
            Expanded(
              child: AppDateField(
                label: 'Valid until',
                value: _validUntil,
                required: true,
                onChanged: (d) => setState(() => _validUntil = d),
                validator: (v) => v == null ? 'Required' : (_issued != null && v.isBefore(_issued!) ? 'Before issue date' : null),
              ),
            ),
          ],
        ),
        const FormGap(height: 28),
        const FormSectionTitle('Line items'),
        LineItemsEditor(initial: _items, onChanged: (items) => setState(() => _items = items)),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppAmountField(controller: _discount, label: 'Discount %', validator: Validators.percent, onChanged: (_) => setState(() {}))),
            const SizedBox(width: 12),
            Expanded(child: AppAmountField(controller: _tax, label: 'Tax %', validator: Validators.percent, onChanged: (_) => setState(() {}))),
          ],
        ),
        const FormGap(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Summary', style: AppText.cardTitle),
              const SizedBox(height: 12),
              TotalsSummary(items: _items, discountPercent: parseAmount(_discount.text), taxPercent: parseAmount(_tax.text)),
            ],
          ),
        ),
        const FormGap(),
        AppTextField(controller: _notes, label: 'Notes', hint: 'Shown to the client', maxLines: 3),
        const FormGap(),
        AppTextField(controller: _terms, label: 'Terms & conditions', maxLines: 4),
      ],
    );
  }
}
