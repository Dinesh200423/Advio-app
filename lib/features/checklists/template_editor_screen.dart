import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/validators.dart';
import '../../data/models/checklist.dart';
import '../../data/models/common.dart';
import 'checklist_providers.dart';
import 'widgets/template_item_sheet.dart';

/// Create or edit a template. Works on a local draft; nothing changes until Save.
class TemplateEditorScreen extends ConsumerStatefulWidget {
  const TemplateEditorScreen({super.key, this.id});
  final String? id;

  @override
  ConsumerState<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends ConsumerState<TemplateEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final ChecklistTemplate? _existing = widget.id == null ? null : ref.read(templatesProvider.notifier).byId(widget.id);
  late final _name = TextEditingController(text: _existing?.name);
  late final _description = TextEditingController(text: _existing?.description);
  late ServiceCategory _category = _existing?.category ?? ServiceCategory.staticWebsite;
  late List<TemplateStage> _stages = List.of(_existing?.stages ?? const []);
  final Set<String> _open = {};
  bool _dirty = false;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _change(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  // ------------------------------------------------------------------ stages

  Future<void> _addStage() async {
    final stage = await showStageSheet(context);
    if (stage == null) return;
    _change(() {
      _stages = [..._stages, stage];
      _open.add(stage.id);
    });
  }

  Future<void> _editStage(int i) async {
    final stage = await showStageSheet(context, existing: _stages[i]);
    if (stage != null) _change(() => _stages = [..._stages]..[i] = stage);
  }

  Future<void> _deleteStage(int i) async {
    final s = _stages[i];
    final ok = await confirmDialog(
      context,
      title: 'Delete stage?',
      message: '"${s.name}"${s.items.isEmpty ? '' : ' and its ${s.items.length} item${s.items.length == 1 ? '' : 's'}'} will be removed from this template.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok) _change(() => _stages = [..._stages]..removeAt(i));
  }

  void _moveStage(int from, int to) {
    if (to < 0 || to >= _stages.length) return;
    _change(() {
      final list = [..._stages];
      list.insert(to, list.removeAt(from));
      _stages = list;
    });
  }

  // ------------------------------------------------------------------- items

  int _nextOffset() {
    var max = 0;
    for (final s in _stages) {
      for (final i in s.items) {
        if ((i.dueOffsetDays ?? 0) > max) max = i.dueOffsetDays!;
      }
    }
    return max + 2;
  }

  Future<void> _editItem(int stageIndex, {int? itemIndex}) async {
    final stage = _stages[stageIndex];
    final result = await showTemplateItemSheet(
      context,
      existing: itemIndex == null ? null : stage.items[itemIndex],
      suggestedOffset: itemIndex == null ? _nextOffset() : null,
    );
    if (result == null) return;
    _change(() {
      final items = [...stage.items];
      if (result.remove) {
        items.removeAt(itemIndex!);
      } else if (itemIndex == null) {
        items.add(result.item!);
      } else {
        items[itemIndex] = result.item!;
      }
      _stages = [..._stages]..[stageIndex] = stage.copyWith(items: items);
    });
  }

  // -------------------------------------------------------------------- save

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_stages.isEmpty) {
      AppSnack.error(context, 'Add at least one stage');
      return;
    }
    final empty = _stages.indexWhere((s) => s.items.isEmpty);
    if (empty >= 0) {
      setState(() => _open.add(_stages[empty].id));
      AppSnack.error(context, '"${_stages[empty].name}" has no items yet');
      return;
    }

    setState(() => _saving = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    final template = ChecklistTemplate(
      id: _existing?.id ?? newId('tpl'),
      name: _name.text.trim(),
      category: _category,
      description: _description.text.trim(),
      stages: _stages,
      updatedAt: DateTime.now(),
    );
    ref.read(templatesProvider.notifier).save(template);
    _dirty = false;
    AppSnack.success(context, _existing == null ? 'Template created' : 'Template updated. Existing project checklists are unchanged');
    context.popOr(Routes.templates);
  }

  Future<void> _confirmLeave() async {
    final leave = await confirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your edits to this template have not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (leave && mounted) {
      setState(() => _dirty = false);
      context.popOr(Routes.templates);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.id != null && _existing == null) return const MissingRecord(what: 'Template', fallback: Routes.templates);
    final editing = _existing != null;
    final usedBy = editing ? ref.watch(templateUsageProvider(_existing.id)) : 0;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Close', onPressed: () => _dirty ? _confirmLeave() : context.popOr(Routes.templates)),
          title: Text(editing ? 'Edit template' : 'New template'),
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
                      key: _form,
                      child: ListView(
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.fromLTRB(AppSpacing.page, 8, AppSpacing.page, 24),
                        children: [
                          if (usedBy > 0)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: AppCard(
                                shadow: false,
                                color: AppColors.tint(AppColors.primary, 0.06),
                                child: Text(
                                  '$usedBy project checklist${usedBy == 1 ? ' was' : 's were'} started from this template. They keep their own copy, so your changes only apply to checklists started from now on.',
                                  style: AppText.body.copyWith(fontSize: 13.5),
                                ),
                              ),
                            ),
                          AppTextField(controller: _name, label: 'Template name', required: true, hint: 'e.g. Static Website Development', textCapitalization: TextCapitalization.words, onChanged: (_) => _dirty = true, validator: (v) => Validators.required(v, 'Template name')),
                          const FormGap(),
                          AppDropdown<ServiceCategory>(label: 'Service category', items: ServiceCategory.values, value: _category, labelOf: (c) => c.label, onChanged: (v) => _change(() => _category = v ?? _category)),
                          if (_category == ServiceCategory.maintenance)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Support templates repeat every month, so project checklists show a service period.', style: AppText.caption),
                            ),
                          const FormGap(),
                          AppTextField(controller: _description, label: 'Description', hint: 'What this service covers', maxLines: 3, onChanged: (_) => _dirty = true),
                          const FormGap(height: 28),
                          Row(
                            children: [
                              Expanded(child: Text('Stages (${_stages.length})', style: AppText.sectionTitle)),
                              AppButton.secondary(label: 'Add stage', icon: Icons.add_rounded, compact: true, expand: false, onPressed: _addStage),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Drag the handle, or use the menu, to change the order.', style: AppText.caption),
                          const SizedBox(height: 14),
                          if (_stages.isEmpty)
                            const EmptyState(icon: Icons.view_list_outlined, title: 'No stages yet', message: 'A template is made of stages, and each stage of checklist items.', compact: true)
                          else
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: _stages.length,
                              onReorderItem: _moveStage,
                              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, elevation: 6, borderRadius: BorderRadius.circular(16), child: child),
                              itemBuilder: (context, i) => _StageEditor(
                                key: ValueKey(_stages[i].id),
                                stage: _stages[i],
                                index: i,
                                count: _stages.length,
                                open: _open.contains(_stages[i].id),
                                onToggle: () => setState(() => _open.contains(_stages[i].id) ? _open.remove(_stages[i].id) : _open.add(_stages[i].id)),
                                onEdit: () => _editStage(i),
                                onDelete: () => _deleteStage(i),
                                onMove: (dir) => _moveStage(i, i + dir),
                                onAddItem: () => _editItem(i),
                                onEditItem: (n) => _editItem(i, itemIndex: n),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.page, 12, AppSpacing.page, 12),
                    decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.border))),
                    child: AppButton(label: editing ? 'Save changes' : 'Create template', onPressed: _save, loading: _saving),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageEditor extends StatelessWidget {
  const _StageEditor({
    super.key,
    required this.stage,
    required this.index,
    required this.count,
    required this.open,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
    required this.onAddItem,
    required this.onEditItem,
  });

  final TemplateStage stage;
  final int index;
  final int count;
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<int> onMove;
  final VoidCallback onAddItem;
  final ValueChanged<int> onEditItem;

  @override
  Widget build(BuildContext context) {
    final required = stage.items.where((i) => i.isRequired).length;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ReorderableDragStartListener(
                index: index,
                child: const Tooltip(message: 'Drag to reorder', child: SizedBox(width: 48, height: 56, child: Icon(Icons.drag_indicator_rounded, color: AppColors.muted))),
              ),
              Expanded(
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${index + 1}. ${stage.name}', style: AppText.cardTitle.copyWith(fontSize: 15)),
                        Text('${stage.items.length} item${stage.items.length == 1 ? '' : 's'}  ·  $required required', style: AppText.caption),
                      ],
                    ),
                  ),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Stage options',
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onSelected: (v) {
                  switch (v) {
                    case 'edit':
                      onEdit();
                    case 'up':
                      onMove(-1);
                    case 'down':
                      onMove(1);
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit stage')),
                  if (index > 0) const PopupMenuItem(value: 'up', child: Text('Move up')),
                  if (index < count - 1) const PopupMenuItem(value: 'down', child: Text('Move down')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete stage', style: TextStyle(color: AppColors.danger))),
                ],
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        if (stage.description.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text(stage.description, style: AppText.caption.copyWith(fontSize: 12.5))),
                        for (var n = 0; n < stage.items.length; n++) _ItemRow(item: stage.items[n], onTap: () => onEditItem(n)),
                        const SizedBox(height: 4),
                        AppButton.secondary(label: 'Add item', icon: Icons.add_rounded, compact: true, onPressed: onAddItem),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.onTap});
  final TemplateItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tags = [
      item.isRequired ? 'Required' : 'Optional',
      if (item.evidenceType != EvidenceType.none) 'Evidence: ${item.evidenceType.label}',
      if (item.clientDependent) 'Client',
      if (item.dueOffsetDays != null) 'Due +${item.dueOffsetDays}d',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: AppText.bodyStrong.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Text(tags.join('  ·  '), style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
