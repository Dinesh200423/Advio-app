import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/checklist.dart';
import 'checklist_providers.dart';
import 'widgets/template_card.dart';

/// Library of service templates. Templates are blueprints: projects get their own copy.
class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({super.key});

  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  String _query = '';
  ServiceCategory? _category;

  Future<void> _delete(ChecklistTemplate t) async {
    final used = ref.read(templateUsageProvider(t.id));
    final ok = await confirmDialog(
      context,
      title: 'Delete "${t.name}"?',
      message: used == 0
          ? 'This template will be removed from the library.'
          : 'This template will be removed from the library. The $used project checklist${used == 1 ? '' : 's'} already started from it keep their own copy.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!ok || !mounted) return;
    ref.read(templatesProvider.notifier).remove(t.id);
    AppSnack.success(context, 'Template deleted');
  }

  void _duplicate(ChecklistTemplate t) {
    final copy = ref.read(templatesProvider.notifier).duplicate(t.id);
    if (copy == null) return;
    AppSnack.success(context, 'Duplicated as "${copy.name}"');
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(templatesProvider);
    final q = _query.trim().toLowerCase();
    final list = all.where((t) {
      if (_category != null && t.category != _category) return false;
      return q.isEmpty || t.name.toLowerCase().contains(q) || t.description.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final filtering = q.isNotEmpty || _category != null;

    return PageScaffold(
      title: 'Checklist templates',
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.templateNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New template'),
      ),
      children: [
        AppCard(
          shadow: false,
          color: AppColors.tint(AppColors.primary, 0.06),
          child: Text(
            'Each project gets its own copy of a template when its checklist is started. Editing a template here only affects checklists you start afterwards.',
            style: AppText.body.copyWith(fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 20),
        AppSearchBar(hint: 'Search templates', onChanged: (v) => setState(() => _query = v)),
        const SizedBox(height: 12),
        FilterChipRow<ServiceCategory>(
          options: ServiceCategory.values,
          selected: _category,
          labelOf: (c) => c.label,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          EmptyState(
            icon: Icons.checklist_rounded,
            title: filtering ? 'No templates match' : 'No templates yet',
            message: filtering ? 'Try another search or category.' : 'Create a template for a service you deliver repeatedly.',
            actionLabel: filtering ? 'Clear filters' : 'New template',
            onAction: filtering
                ? () => setState(() {
                      _query = '';
                      _category = null;
                    })
                : () => context.push(Routes.templateNew),
          )
        else
          for (final t in list)
            TemplateCard(
              template: t,
              onEdit: () => context.push(Routes.template(t.id)),
              onDuplicate: () => _duplicate(t),
              onDelete: () => _delete(t),
            ),
      ],
    );
  }
}
