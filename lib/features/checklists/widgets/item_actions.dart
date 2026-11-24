import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/checklist.dart';
import '../../../data/models/common.dart';
import '../checklist_providers.dart';
import 'checklist_style.dart';

/// Pick a new status, collecting whatever the rules need first:
/// a reason for Skipped, evidence for Done when the item asks for it.
Future<void> changeItemStatus(BuildContext context, WidgetRef ref, String checklistId, ChecklistItem item) async {
  final picked = await showAppSheet<ChecklistItemStatus>(
    context,
    title: 'Update status',
    builder: (ctx) => Column(
      children: [
        for (final s in ChecklistItemStatus.values)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pop(ctx, s),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label, style: AppText.bodyStrong),
                        Text(s.hint, style: AppText.caption),
                      ],
                    ),
                  ),
                  if (s == item.status) const Icon(Icons.check_rounded, color: AppColors.primary),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  if (picked == null || picked == item.status || !context.mounted) return;
  await applyItemStatus(context, ref, checklistId, item, picked);
}

/// Applies [status] to [item], asking for a skip reason or evidence when required.
Future<void> applyItemStatus(BuildContext context, WidgetRef ref, String checklistId, ChecklistItem item, ChecklistItemStatus status) async {
  final notifier = ref.read(checklistsProvider.notifier);
  String? reason;

  if (status == ChecklistItemStatus.skipped) {
    reason = await showAppSheet<String>(context, title: 'Skip "${item.title}"', builder: (_) => _SkipReasonForm(item: item));
    if (reason == null || !context.mounted) return;
  }

  if (status == ChecklistItemStatus.done && item.needsEvidence) {
    final evidence = await showEvidenceSheet(context, item, completing: true);
    if (evidence == null || !context.mounted) return;
    notifier.addEvidence(checklistId, item.id, evidence);
  }

  final error = notifier.setStatus(checklistId, item.id, status, skipReason: reason);
  if (!context.mounted) return;
  if (error == null) {
    AppSnack.success(context, 'Marked as ${status.label}');
  } else {
    AppSnack.error(context, error);
  }
}

/// Add evidence of the type the item asks for. Resolves to the new [Evidence], or null if cancelled.
Future<Evidence?> showEvidenceSheet(BuildContext context, ChecklistItem item, {bool completing = false}) {
  return showAppSheet<Evidence>(
    context,
    title: completing ? 'Add evidence to finish' : 'Add evidence',
    builder: (_) => _EvidenceForm(item: item, completing: completing),
  );
}

// ------------------------------------------------------------------ sheets

class _SkipReasonForm extends StatefulWidget {
  const _SkipReasonForm({required this.item});
  final ChecklistItem item;

  @override
  State<_SkipReasonForm> createState() => _SkipReasonFormState();
}

class _SkipReasonFormState extends State<_SkipReasonForm> {
  final _key = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.item.isRequired
                ? 'This is a required item. Skipping it counts as done for progress, so note why it is safe to leave out.'
                : 'Say why this is being skipped. It is kept in the item history.',
            style: AppText.label,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _reason,
            label: 'Reason',
            required: true,
            hint: 'e.g. Client already has a Google Business Profile',
            maxLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'A reason is required to skip an item' : null,
          ),
          const SizedBox(height: 20),
          AppButton(
            label: 'Skip item',
            onPressed: () {
              if (_key.currentState!.validate()) Navigator.pop(context, _reason.text.trim());
            },
          ),
        ],
      ),
    );
  }
}

class _EvidenceForm extends StatefulWidget {
  const _EvidenceForm({required this.item, required this.completing});
  final ChecklistItem item;
  final bool completing;

  @override
  State<_EvidenceForm> createState() => _EvidenceFormState();
}

class _EvidenceFormState extends State<_EvidenceForm> {
  final _key = GlobalKey<FormState>();
  final _text = TextEditingController();
  String? _file;
  bool _fileMissing = false;

  EvidenceType get _type => widget.item.evidenceType;

  List<String> get _sampleFiles {
    final slug = (widget.item.evidenceHint.isEmpty ? widget.item.title : widget.item.evidenceHint).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    return ['$slug.pdf', 'screenshot-${DateTime.now().day}.png', 'client-email.pdf'];
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _submit() {
    final formOk = _key.currentState?.validate() ?? true;
    if (_type == EvidenceType.file && _file == null) {
      setState(() => _fileMissing = true);
      return;
    }
    if (!formOk) return;
    Navigator.pop(
      context,
      Evidence(
        id: newId('ev'),
        type: _type,
        value: _type == EvidenceType.file ? _file! : _text.text.trim(),
        label: widget.item.evidenceHint,
        addedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Needed: ${_type.requirement(widget.item.evidenceHint)}', style: AppText.label),
          const SizedBox(height: 16),
          switch (_type) {
            EvidenceType.url => AppTextField(
                controller: _text,
                label: 'Link',
                required: true,
                hint: 'https://',
                keyboardType: TextInputType.url,
                autofocus: true,
                validator: (v) => RegExp(r'^https?://[^\s/$.?#][^\s]*\.[^\s]+$').hasMatch((v ?? '').trim()) ? null : 'Enter a full link starting with http:// or https://',
              ),
            EvidenceType.note => AppTextField(
                controller: _text,
                label: 'Note',
                required: true,
                hint: 'What was done or confirmed?',
                maxLines: 4,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().length < 3) ? 'Write a short note' : null,
              ),
            EvidenceType.file => _FilePicker(
                file: _file,
                missing: _fileMissing,
                onPick: () async {
                  final f = await pickOption<String>(context, title: 'Choose a file', options: _sampleFiles, labelOf: (s) => s);
                  if (f == null) return;
                  setState(() {
                    _file = f;
                    _fileMissing = false;
                  });
                },
              ),
            EvidenceType.none => const SizedBox.shrink(),
          },
          const SizedBox(height: 20),
          AppButton(label: widget.completing ? 'Save & mark done' : 'Add evidence', onPressed: _submit),
        ],
      ),
    );
  }
}

/// Simulated file chooser: phase 1 has no file access, so it offers sample files.
class _FilePicker extends StatelessWidget {
  const _FilePicker({required this.file, required this.missing, required this.onPick});
  final String? file;
  final bool missing;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('File', required: true),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onPick,
          child: Container(
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: missing ? AppColors.danger : AppColors.border, width: 1.5),
            ),
            child: Text(file ?? 'Choose file', style: AppText.labelStrong.copyWith(color: file == null ? AppColors.primary : AppColors.ink)),
          ),
        ),
        if (missing) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Choose a file to continue', style: AppText.caption.copyWith(color: AppColors.danger))),
        const SizedBox(height: 6),
        Text('Prototype: files are simulated, nothing is uploaded.', style: AppText.caption),
      ],
    );
  }
}

/// Card for a piece of evidence already attached to an item.
class EvidenceCard extends StatelessWidget {
  const EvidenceCard({super.key, required this.evidence, required this.onRemove});
  final Evidence evidence;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isUrl = evidence.type == EvidenceType.url;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      shadow: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  StatusBadge(label: evidence.type.label, color: AppColors.primary, dot: false),
                  const SizedBox(width: 8),
                  Expanded(child: Text(Fmt.dateTime(evidence.addedAt), style: AppText.caption)),
                ]),
                const SizedBox(height: 8),
                if (evidence.label.isNotEmpty) Text(evidence.label, style: AppText.caption),
                GestureDetector(
                  onTap: isUrl ? () => AppSnack.info(context, 'Prototype: would open ${evidence.value}') : null,
                  child: Text(
                    evidence.value,
                    style: AppText.body.copyWith(fontSize: 13.5, color: isUrl ? AppColors.primary : AppColors.body, decoration: isUrl ? TextDecoration.underline : null),
                  ),
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Remove evidence', onPressed: onRemove, icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.muted)),
        ],
      ),
    );
  }
}
