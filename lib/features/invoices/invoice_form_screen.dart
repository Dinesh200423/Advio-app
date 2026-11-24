import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/invoice.dart';
import '../../shared/widgets/document_widgets.dart';
import '../../shared/widgets/line_items_editor.dart';
import '../clients/client_providers.dart';
import '../projects/project_providers.dart';
import '../settings/settings_providers.dart';
import 'invoice_providers.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({super.key, this.id, this.clientId, this.projectId});
  final String? id;
  final String? clientId;
  final String? projectId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  final _key = GlobalKey<FormState>();
  late final Invoice? _existing = widget.id == null ? null : ref.read(invoicesProvider.notifier).byId(widget.id);
  late final _discount = TextEditingController(text: _existing == null || _existing.discountPercent == 0 ? '' : _existing.discountPercent.toString());
  late final _tax = TextEditingController(text: (_existing?.taxPercent ?? ref.read(settingsProvider).defaultTaxPercent).toString());
  late final _notes = TextEditingController(text: _existing?.notes);
  late String? _clientId = _existing?.clientId ?? widget.clientId ?? _clientOfProject(widget.projectId);
  late String? _projectId = _existing?.projectId ?? widget.projectId;
  late DateTime? _issued = _existing?.issueDate ?? DateTime.now();
  late DateTime? _due = _existing?.dueDate ?? DateTime.now().add(const Duration(days: 14));
  late List<LineItem> _items = _existing?.items ?? const [];

  String? _clientOfProject(String? projectId) => projectId == null ? null : ref.read(projectsProvider.notifier).byId(projectId)?.clientId;

  @override
  void dispose() {
    for (final c in [_discount, _tax, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Invoice _build({required String id, required String number, required InvoiceStatus status, List<Payment> payments = const []}) => Invoice(
        id: id,
        number: number,
        clientId: _clientId!,
        projectId: _projectId,
        items: _items,
        issueDate: _issued!,
        dueDate: _due!,
        status: status,
        discountPercent: parseAmount(_discount.text),
        taxPercent: parseAmount(_tax.text),
        notes: _notes.text.trim(),
        payments: payments,
      );

  void _saveDraft() {
    if (!(_key.currentState?.validate() ?? false)) return;
    final notifier = ref.read(invoicesProvider.notifier);
    notifier.create(_build(id: newId('inv'), number: notifier.nextNumber(), status: InvoiceStatus.draft));
    AppSnack.success(context, 'Invoice saved as draft');
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Invoice', fallback: Routes.invoices);
    final editing = _existing != null;
    final clients = ref.watch(clientsProvider);
    final projects = ref.watch(projectsProvider).where((p) => _clientId == null || p.clientId == _clientId).toList();

    return FormPage(
      formKey: _key,
      title: editing ? 'Edit invoice' : 'New invoice',
      submitLabel: editing ? 'Save changes' : 'Create & send',
      successMessage: editing ? 'Invoice updated' : 'Invoice created and sent',
      extraAction: editing ? null : AppButton.secondary(label: 'Save draft', onPressed: _saveDraft),
      onSubmit: () {
        final notifier = ref.read(invoicesProvider.notifier);
        if (editing) {
          notifier.upsert(_build(id: _existing.id, number: _existing.number, status: _existing.status, payments: _existing.payments));
        } else {
          notifier.create(_build(id: newId('inv'), number: notifier.nextNumber(), status: InvoiceStatus.sent));
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
          onChanged: (v) => setState(() {
            _clientId = v;
            // A project belongs to one client; drop it if it no longer matches.
            if (_projectId != null && ref.read(projectsProvider.notifier).byId(_projectId)?.clientId != v) _projectId = null;
          }),
        ),
        const FormGap(),
        AppDropdown<String?>(
          label: 'Project (optional)',
          hint: 'No project',
          items: [null, for (final p in projects) p.id],
          value: _projectId,
          labelOf: (id) => id == null ? 'No project' : projects.firstWhere((p) => p.id == id).name,
          onChanged: (v) => setState(() => _projectId = v),
        ),
        const FormGap(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AppDateField(label: 'Issue date', value: _issued, required: true, onChanged: (d) => setState(() => _issued = d))),
            const SizedBox(width: 12),
            Expanded(
              child: AppDateField(
                label: 'Due date',
                value: _due,
                required: true,
                onChanged: (d) => setState(() => _due = d),
                validator: (v) => v == null ? 'Required' : (_issued != null && v.isBefore(DateTime(_issued!.year, _issued!.month, _issued!.day)) ? 'Before issue date' : null),
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
        AppTextField(controller: _notes, label: 'Notes', hint: 'Payment instructions, thank-you note…', maxLines: 3),
      ],
    );
  }
}
