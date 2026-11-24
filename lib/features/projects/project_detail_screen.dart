import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/project.dart';
import '../checklists/checklist_providers.dart';
import '../checklists/widgets/checklist_summary_card.dart';
import '../checklists/widgets/new_checklist_sheet.dart';
import '../clients/client_providers.dart';
import '../invoices/invoice_providers.dart';
import '../tasks/task_providers.dart';
import '../tasks/widgets/task_tile.dart';
import '../team/widgets/assignee_widgets.dart';
import 'project_providers.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final project = ref.watch(projectProvider(id));
    if (project == null) return const MissingRecord(what: 'Project', fallback: Routes.projects);
    final client = ref.watch(clientProvider(project.clientId));
    final progress = ref.watch(projectProgressProvider(id));
    final notifier = ref.read(projectsProvider.notifier);
    final invoiced = ref
        .watch(invoicesProvider)
        .where((i) => i.projectId == id && i.status != InvoiceStatus.draft && i.status != InvoiceStatus.voided)
        .fold<double>(0, (s, i) => s + i.total);

    return PageScaffold(
      title: 'Project details',
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.projectEdit(id)),
          deleteTitle: 'Delete project?',
          deleteMessage: '"${project.name}" will be removed. Its tasks are kept but unlinked.',
          onDelete: () {
            notifier.remove(id);
            context.popOr(Routes.projects);
            AppSnack.success(context, 'Project deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(project.name, style: AppText.sectionTitle),
              const SizedBox(height: 4),
              InkWell(
                onTap: client == null ? null : () => context.push(Routes.client(client.id)),
                child: Text(client?.displayName ?? 'Unknown client', style: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              AssigneeRow(label: 'Project owner', memberId: project.ownerId, onChanged: (id) => notifier.upsert(project.copyWith(ownerId: id))),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () async {
                  final s = await pickOption<ProjectStatus>(
                    context,
                    title: 'Project status',
                    options: ProjectStatus.values,
                    labelOf: (s) => s.label,
                    selected: project.status,
                    colorOf: (s) => s.color,
                  );
                  if (s != null) {
                    notifier.setStatus(id, s);
                    if (context.mounted) AppSnack.success(context, 'Marked as ${s.label}');
                  }
                },
                child: Row(mainAxisSize: MainAxisSize.min, children: [project.status.badge, const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted)]),
              ),
              const SizedBox(height: 16),
              Text('Progress', style: AppText.label),
              const SizedBox(height: 8),
              AppProgressBar(value: progress, showLabel: true, color: project.status.color, height: 10),
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(label: 'Budget', value: ref.money(project.budget, compact: true)),
                  _Stat(label: 'Start', value: Fmt.dateShort(project.startDate)),
                  _Stat(label: 'Deadline', value: Fmt.dateShort(project.endDate)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TabbedSection(
          tabs: {
            'Overview': (_) => _Overview(project: project, invoiced: invoiced),
            'Tasks': (_) => _Tasks(project: project),
            'Checklist': (_) => _Checklists(project: project),
            'Files': (_) => _Files(project: project),
            'Activity': (_) => project.history.isEmpty
                ? const EmptyState(icon: Icons.history_rounded, title: 'No activity yet', compact: true)
                : AppCard(child: Timeline(entries: [for (final a in project.history) TimelineEntry(title: a.title, subtitle: a.detail, time: Fmt.dateTime(a.at), color: a.kind.color)])),
          },
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(label, style: AppText.caption), const SizedBox(height: 2), Text(value, style: AppText.bodyStrong)],
        ),
      );
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.project, required this.invoiced});
  final Project project;
  final double invoiced;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = project.milestones.where((m) => m.done).length;
    final billedShare = project.budget == 0 ? 0.0 : invoiced / project.budget;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (project.description.isNotEmpty)
          AppCard(margin: const EdgeInsets.only(bottom: 12), child: Text(project.description, style: AppText.body)),
        AppCard(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text('Budget invoiced', style: AppText.cardTitle)),
                Text('${ref.money(invoiced, compact: true)} / ${ref.money(project.budget, compact: true)}', style: AppText.labelStrong),
              ]),
              const SizedBox(height: 10),
              AppProgressBar(value: billedShare, color: AppColors.success),
            ],
          ),
        ),
        SectionHeader(
          title: 'Milestones ($done/${project.milestones.length})',
          padding: const EdgeInsets.only(top: 12, bottom: 12),
          actionLabel: 'Add',
          onAction: () => _addMilestone(context, ref),
        ),
        if (project.milestones.isEmpty)
          const EmptyState(icon: Icons.flag_outlined, title: 'No milestones', message: 'Break the project into deliverables.', compact: true)
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                for (final m in project.milestones)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: TaskCheck(done: m.done, onTap: () => ref.read(projectsProvider.notifier).toggleMilestone(project.id, m.id)),
                    title: Text(m.title, style: AppText.bodyStrong.copyWith(decoration: m.done ? TextDecoration.lineThrough : null, color: m.done ? AppColors.muted : AppColors.ink)),
                    subtitle: Text('Due ${Fmt.date(m.dueDate)}${m.amount > 0 ? ' · ${ref.money(m.amount, compact: true)}' : ''}', style: AppText.caption.copyWith(color: !m.done && daysUntil(m.dueDate) < 0 ? AppColors.danger : AppColors.muted)),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _addMilestone(BuildContext context, WidgetRef ref) {
    final title = TextEditingController();
    final amount = TextEditingController();
    DateTime? due = DateTime.now().add(const Duration(days: 7));
    final key = GlobalKey<FormState>();
    showAppSheet<void>(
      context,
      title: 'Add milestone',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Form(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: title, label: 'Title', hint: 'e.g. Beta release', required: true, validator: (v) => Validators.required(v, 'Title')),
              const SizedBox(height: 16),
              AppDateField(label: 'Due date', value: due, required: true, onChanged: (d) => setState(() => due = d)),
              const SizedBox(height: 16),
              AppAmountField(controller: amount, label: 'Payment amount (optional)', validator: (v) => (v == null || v.isEmpty) ? null : Validators.amount(v, allowZero: true)),
              const SizedBox(height: 24),
              AppButton(
                label: 'Add milestone',
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  ref.read(projectsProvider.notifier).addMilestone(project.id, Milestone(id: newId('ms'), title: title.text.trim(), dueDate: due!, amount: parseAmount(amount.text)));
                  Navigator.pop(ctx);
                  AppSnack.success(context, 'Milestone added');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tasks extends ConsumerWidget {
  const _Tasks({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = [...ref.watch(projectTasksProvider(project.id))]..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.secondary(label: 'Add task', icon: Icons.add_task_rounded, onPressed: () => context.push(Routes.taskNew(projectId: project.id))),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          const EmptyState(icon: Icons.checklist_rounded, title: 'No tasks yet', message: 'Add tasks to track the work for this project.', compact: true)
        else
          for (final t in tasks) TaskTile(task: t, showProject: false),
      ],
    );
  }
}

/// Delivery checklists started for this project.
class _Checklists extends ConsumerWidget {
  const _Checklists({required this.project});
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lists = ref.watch(projectChecklistsProvider(project.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.secondary(label: 'Start a checklist', icon: Icons.add_rounded, onPressed: () => showNewChecklistSheet(context, projectId: project.id)),
        const SizedBox(height: 16),
        if (lists.isEmpty)
          const EmptyState(icon: Icons.fact_check_outlined, title: 'No delivery checklist yet', message: 'Start one from a service template to track every stage of delivery.', compact: true)
        else
          for (final c in lists) ChecklistSummaryCard(checklist: c, showProject: false),
      ],
    );
  }
}

class _Files extends ConsumerWidget {
  const _Files({required this.project});
  final Project project;

  static const _samples = [
    ('Signed-contract.pdf', 420),
    ('Requirements-v2.docx', 180),
    ('Homepage-mockup.png', 2350),
    ('Brand-assets.zip', 18400),
    ('Meeting-notes.txt', 12),
  ];

  IconData _icon(String ext) => switch (ext) {
        'pdf' => Icons.picture_as_pdf_rounded,
        'png' || 'jpg' || 'jpeg' => Icons.image_rounded,
        'zip' => Icons.folder_zip_rounded,
        'fig' => Icons.design_services_rounded,
        _ => Icons.description_rounded,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.secondary(
          label: 'Upload file',
          icon: Icons.upload_file_rounded,
          onPressed: () async {
            // Phase 1: pick from sample files instead of the device file system.
            final pick = await pickOption<(String, int)>(context, title: 'Choose a file to attach', options: _samples, labelOf: (f) => '${f.$1}  ·  ${Fmt.fileSize(f.$2)}');
            if (pick == null || !context.mounted) return;
            ref.read(projectsProvider.notifier).addFile(project.id, ProjectFile(id: newId('file'), name: pick.$1, sizeKb: pick.$2, addedAt: DateTime.now()));
            AppSnack.success(context, '${pick.$1} uploaded');
          },
        ),
        const SizedBox(height: 16),
        if (project.files.isEmpty)
          const EmptyState(icon: Icons.folder_open_rounded, title: 'No files', message: 'Contracts, designs and assets live here.', compact: true)
        else
          for (final f in project.files)
            AppListTile(
              leading: IconChip(icon: _icon(f.extension), color: AppColors.primary),
              title: f.name,
              subtitle: '${Fmt.fileSize(f.sizeKb)} · ${Fmt.date(f.addedAt)}',
              trailing: IconButton(
                tooltip: 'Remove file',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.muted),
                onPressed: () async {
                  final ok = await confirmDialog(context, title: 'Remove file?', message: f.name, confirmLabel: 'Remove', destructive: true);
                  if (ok) ref.read(projectsProvider.notifier).removeFile(project.id, f.id);
                },
              ),
            ),
      ],
    );
  }
}
