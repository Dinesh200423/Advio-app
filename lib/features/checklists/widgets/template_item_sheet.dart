import 'package:flutter/material.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/checklist.dart';
import '../../../data/models/common.dart';

/// Result of the item editor: a saved item, or a request to remove it.
class TemplateItemResult {
  const TemplateItemResult.save(TemplateItem this.item) : remove = false;
  const TemplateItemResult.remove()
      : item = null,
        remove = true;
  final TemplateItem? item;
  final bool remove;
}

/// Add or edit one template item. [suggestedOffset] pre-fills the due offset for new items.
Future<TemplateItemResult?> showTemplateItemSheet(BuildContext context, {TemplateItem? existing, int? suggestedOffset}) {
  return showAppSheet<TemplateItemResult>(
    context,
    title: existing == null ? 'Add checklist item' : 'Edit checklist item',
    builder: (_) => _ItemForm(existing: existing, suggestedOffset: suggestedOffset),
  );
}

class _ItemForm extends StatefulWidget {
  const _ItemForm({this.existing, this.suggestedOffset});
  final TemplateItem? existing;
  final int? suggestedOffset;

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _key = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _hint = TextEditingController(text: widget.existing?.evidenceHint);
  late final _offset = TextEditingController(text: (widget.existing?.dueOffsetDays ?? widget.suggestedOffset)?.toString() ?? '');
  late bool _required = widget.existing?.isRequired ?? true;
  late bool _client = widget.existing?.clientDependent ?? false;
  late EvidenceType _evidence = widget.existing?.evidenceType ?? EvidenceType.none;

  @override
  void dispose() {
    for (final c in [_title, _description, _hint, _offset]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!_key.currentState!.validate()) return;
    final offsetText = _offset.text.trim();
    Navigator.pop(
      context,
      TemplateItemResult.save(TemplateItem(
        id: widget.existing?.id ?? newId('ti'),
        title: _title.text.trim(),
        description: _description.text.trim(),
        isRequired: _required,
        evidenceType: _evidence,
        evidenceHint: _evidence == EvidenceType.none ? '' : _hint.text.trim(),
        clientDependent: _client,
        dueOffsetDays: offsetText.isEmpty ? null : int.parse(offsetText),
      )),
    );
  }

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) => Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(title, style: AppText.bodyStrong), Text(subtitle, style: AppText.caption)],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(controller: _title, label: 'Title', required: true, hint: 'e.g. Get homepage design approval', textCapitalization: TextCapitalization.sentences, validator: (v) => Validators.required(v, 'Title')),
          const SizedBox(height: 16),
          AppTextField(controller: _description, label: 'Description', hint: 'Optional guidance for whoever does this', maxLines: 2, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 16),
          _toggle('Required', 'Required items decide progress and stage completion', _required, (v) => setState(() => _required = v)),
          const SizedBox(height: 8),
          _toggle('Depends on the client', 'Needs input or approval from them', _client, (v) => setState(() => _client = v)),
          const SizedBox(height: 16),
          const FieldLabel('Evidence needed'),
          FilterChipRow<EvidenceType>(options: EvidenceType.values, allLabel: null, selected: _evidence, labelOf: (e) => e == EvidenceType.none ? 'None' : e.label, onSelected: (e) => setState(() => _evidence = e ?? _evidence)),
          if (_evidence != EvidenceType.none) ...[
            const SizedBox(height: 16),
            AppTextField(
              controller: _hint,
              label: 'What should be provided?',
              required: true,
              hint: switch (_evidence) {
                EvidenceType.url => 'e.g. Live website URL',
                EvidenceType.file => 'e.g. Signed agreement',
                _ => 'e.g. Backup confirmation',
              },
              validator: (v) => Validators.required(v, 'This'),
            ),
          ],
          const SizedBox(height: 16),
          AppAmountField(
            controller: _offset,
            label: 'Default due date (days after start)',
            hint: 'Leave empty for no due date',
            allowDecimal: false,
            validator: (v) => (v == null || v.trim().isEmpty) || int.tryParse(v.trim()) != null ? null : 'Enter a whole number of days',
          ),
          const SizedBox(height: 24),
          AppButton(label: widget.existing == null ? 'Add item' : 'Save item', onPressed: _save),
          if (widget.existing != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Remove this item?', message: '"${widget.existing!.title}" will be removed from the template.', confirmLabel: 'Remove', destructive: true);
                if (ok && context.mounted) Navigator.pop(context, const TemplateItemResult.remove());
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Remove item'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Add or edit a stage's name and description.
Future<TemplateStage?> showStageSheet(BuildContext context, {TemplateStage? existing}) {
  return showAppSheet<TemplateStage>(context, title: existing == null ? 'Add stage' : 'Edit stage', builder: (_) => _StageForm(existing: existing));
}

class _StageForm extends StatefulWidget {
  const _StageForm({this.existing});
  final TemplateStage? existing;

  @override
  State<_StageForm> createState() => _StageFormState();
}

class _StageFormState extends State<_StageForm> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _description = TextEditingController(text: widget.existing?.description);

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(controller: _name, label: 'Stage name', required: true, hint: 'e.g. UI/UX Design', autofocus: true, textCapitalization: TextCapitalization.words, validator: (v) => Validators.required(v, 'Stage name')),
          const SizedBox(height: 16),
          AppTextField(controller: _description, label: 'Description', hint: 'What this stage covers', maxLines: 2, textCapitalization: TextCapitalization.sentences),
          const SizedBox(height: 24),
          AppButton(
            label: widget.existing == null ? 'Add stage' : 'Save stage',
            onPressed: () {
              if (!_key.currentState!.validate()) return;
              Navigator.pop(
                context,
                (widget.existing ?? TemplateStage(id: newId('ts'), name: '')).copyWith(name: _name.text.trim(), description: _description.text.trim()),
              );
            },
          ),
        ],
      ),
    );
  }
}

