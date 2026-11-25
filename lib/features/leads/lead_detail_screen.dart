import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/common.dart';
import '../../data/models/enums.dart';
import '../../data/models/lead.dart';
import '../../shared/contact_links.dart';
import '../../shared/widgets/contact_actions.dart';
import '../../shared/widgets/notes_section.dart';
import '../clients/client_providers.dart';
import '../projects/project_providers.dart';
import '../team/team_providers.dart';
import '../../data/models/modules.dart';
import '../team/module_access.dart';
import '../team/widgets/assignee_widgets.dart';
import 'lead_providers.dart';

class LeadDetailScreen extends ConsumerWidget {
  const LeadDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lead = ref.watch(leadProvider(id));
    if (lead == null) return const MissingRecord(what: 'Lead', fallback: Routes.leads);
    final notifier = ref.read(leadsProvider.notifier);
    final canEdit = ref.watch(canUseProvider(AppModule.leads));

    return PageScaffold(
      title: 'Lead details',
      actions: [
        if (canEdit)
          DetailMenu(
            onEdit: () => context.push(Routes.leadEdit(id)),
            deleteTitle: 'Delete lead?',
            deleteMessage: '${lead.name} and all their follow-ups and notes will be removed.',
            onDelete: () {
              notifier.remove(id);
              context.popOr(Routes.leads);
              AppSnack.success(context, 'Lead deleted');
            },
          ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  InitialsAvatar(name: lead.name, size: 56),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lead.name, style: AppText.sectionTitle),
                        if (lead.company.isNotEmpty || lead.location.isNotEmpty)
                          Text(lead.company.isNotEmpty ? lead.company : lead.location, style: AppText.label),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      final s = await pickOption<LeadStatus>(
                        context,
                        title: 'Change status',
                        options: LeadStatus.values,
                        labelOf: (s) => s.label,
                        selected: lead.status,
                        colorOf: (s) => s.color,
                      );
                      if (s != null) {
                        notifier.changeStatus(id, s);
                        if (context.mounted) AppSnack.success(context, 'Status updated to ${s.label}');
                      }
                    },
                    child: Row(
                      children: [
                        lead.status.badge,
                        const SizedBox(width: 2),
                        const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(ref.money(lead.estimatedValue), style: AppText.cardTitle),
                ],
              ),
              const SizedBox(height: 16),
              ContactActions(phone: lead.phone, email: lead.email),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (canEdit && lead.status != LeadStatus.lost) _ConvertBanner(lead: lead),
        const SizedBox(height: 12),
        TabbedSection(
          tabs: {
            'Overview': (_) => _Overview(lead: lead),
            'Follow-ups': (_) => _FollowUps(lead: lead),
            'Notes': (_) => NotesSection(notes: lead.notes, onAdd: (t) => notifier.addNote(id, t)),
            'Activity': (_) => _History(lead: lead),
          },
        ),
      ],
    );
  }
}

class _ConvertBanner extends ConsumerStatefulWidget {
  const _ConvertBanner({required this.lead});
  final Lead lead;

  @override
  ConsumerState<_ConvertBanner> createState() => _ConvertBannerState();
}

class _ConvertBannerState extends ConsumerState<_ConvertBanner> {
  bool _converting = false;

  Future<void> _convert() async {
    final lead = widget.lead;
    final ok = await confirmDialog(
      context,
      title: 'Convert to client?',
      message: '${lead.displayCompany} will be added to your clients, with a planned project holding their requirements, and this lead will be marked as Won.',
      confirmLabel: 'Convert',
      icon: Icons.swap_horiz_rounded,
    );
    if (!ok || !mounted) return;

    setState(() => _converting = true);
    final result = await ref.read(leadsProvider.notifier).convertToClient(lead.id);
    if (!mounted) return;
    setState(() => _converting = false);

    if (result == null) {
      AppSnack.error(context, 'The client could not be saved, so nothing was converted. Check your connection and try again.');
      return;
    }
    AppSnack.success(context, result.projectId == null ? '${lead.displayCompany} added to clients (the project could not be created)' : '${lead.displayCompany} is now a client');
    context.push(Routes.client(result.clientId));
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final client = ref.watch(clientProvider(lead.convertedClientId));

    // Already converted: say so, and link to what was made.
    if (client != null) {
      final project = ref.watch(projectProvider(lead.convertedProjectId));
      return AppCard(
        shadow: false,
        color: AppColors.tint(AppColors.success, 0.08),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Converted to client', style: AppText.bodyStrong),
            const SizedBox(height: 2),
            Text(client.displayName, style: AppText.caption),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: AppButton.secondary(label: 'View client', compact: true, onPressed: () => context.push(Routes.client(client.id)))),
                if (project != null) ...[
                  const SizedBox(width: 8),
                  Expanded(child: AppButton.secondary(label: 'View project', compact: true, onPressed: () => context.push(Routes.project(project.id)))),
                ],
              ],
            ),
          ],
        ),
      );
    }

    return AppCard(
      shadow: false,
      color: AppColors.tint(AppColors.secondary, 0.06),
      child: Row(
        children: [
          Expanded(
            child: Text(lead.status == LeadStatus.won
                ? 'Marked Won, but no client has been created yet.'
                : 'Ready to work together? Convert this lead into a client.'),
          ),
          const SizedBox(width: 8),
          AppButton(label: 'Convert', expand: false, compact: true, loading: _converting, onPressed: _converting ? null : _convert),
        ],
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = lead.status.isOpen ? lead.nextFollowUp : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next != null)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            shadow: false,
            color: AppColors.tint(AppColors.warning, 0.08),
            child: Row(
              children: [
                Icon(next.type.icon, color: AppColors.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Next: ${next.type.label} · ${Fmt.relativeDay(next.at)}', style: AppText.bodyStrong),
                      Text('${Fmt.time(next.at)}${next.note.isEmpty ? '' : ' · ${next.note}'}', style: AppText.caption),
                    ],
                  ),
                ),
              ],
            ),
          ),
        InfoCard(
          children: [
            if (lead.email.isNotEmpty) InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: lead.email),
            InfoRow(icon: Icons.call_outlined, label: 'Phone', value: lead.phone),
            if (lead.location.isNotEmpty) InfoRow(icon: Icons.place_outlined, label: 'Area', value: lead.location),
            InfoRow(
              icon: Icons.language_rounded,
              label: 'Website',
              value: lead.website.isEmpty ? 'None found' : lead.website,
              onTap: webLink(lead.website) == null
                  ? null
                  : () async {
                      final opened = await ref.read(urlOpenerProvider)(webLink(lead.website)!);
                      if (!opened && context.mounted) AppSnack.error(context, 'Could not open the website.');
                    },
            ),
            InfoRow(
              label: 'Owner',
              value: ref.watch(memberNameProvider(lead.ownerId)),
              onTap: () async {
                final pick = await showAssigneePicker(context, currentId: lead.ownerId, title: 'Lead owner');
                if (pick != null) ref.read(leadsProvider.notifier).upsert(lead.copyWith(ownerId: pick.id));
              },
            ),
            InfoRow(label: 'Service', value: lead.service.label),
            InfoRow(label: 'Budget', value: lead.budget?.label ?? ''),
            InfoRow(icon: lead.source.icon, label: 'Source', value: lead.source.label),
            InfoRow(icon: Icons.calendar_today_rounded, label: 'Created', value: Fmt.date(lead.createdAt)),
            InfoRow(icon: Icons.lightbulb_outline_rounded, label: 'Project overview', value: lead.interest),
          ],
        ),
      ],
    );
  }
}

class _FollowUps extends ConsumerWidget {
  const _FollowUps({required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [...lead.followUps]..sort((a, b) => a.at.compareTo(b.at));
    final notifier = ref.read(leadsProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppButton.secondary(label: 'Schedule follow-up', icon: Icons.event_rounded, onPressed: () => _schedule(context, ref)),
        const SizedBox(height: 20),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'No follow-ups scheduled',
            message: 'Schedule one so no lead goes cold.',
            compact: true,
          )
        else
          Timeline(
            entries: [
              for (final f in items)
                TimelineEntry(
                  title: '${f.type.label}${f.note.isEmpty ? '' : ': ${f.note}'}',
                  subtitle: Fmt.dateTime(f.at),
                  time: f.done ? 'Completed' : Fmt.relativeDay(f.at),
                  color: f.done ? AppColors.success : (daysUntil(f.at) < 0 ? AppColors.danger : AppColors.primary),
                  trailing: Checkbox(value: f.done, shape: const CircleBorder(), onChanged: (_) => notifier.toggleFollowUp(lead.id, f.id)),
                ),
            ],
          ),
      ],
    );
  }

  void _schedule(BuildContext context, WidgetRef ref) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    var type = FollowUpType.call;
    DateTime? when = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11);
    final note = TextEditingController();
    final key = GlobalKey<FormState>();

    showAppSheet<void>(
      context,
      title: 'Schedule follow-up',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Form(
          key: key,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('Type'),
              FilterChipRow<FollowUpType>(
                options: FollowUpType.values,
                selected: type,
                allLabel: null,
                labelOf: (t) => t.label,
                onSelected: (t) => setState(() => type = t ?? type),
              ),
              const SizedBox(height: 20),
              AppDateField(
                label: 'Date & time',
                value: when,
                withTime: true,
                required: true,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                onChanged: (d) => setState(() => when = d),
              ),
              const SizedBox(height: 20),
              AppTextField(controller: note, label: 'Note', hint: 'What will you discuss?', maxLines: 2),
              const SizedBox(height: 24),
              AppButton(
                label: 'Schedule',
                onPressed: () {
                  if (!key.currentState!.validate()) return;
                  ref.read(leadsProvider.notifier).addFollowUp(lead.id, FollowUp(id: newId('fu'), at: when!, type: type, note: note.text.trim()));
                  Navigator.pop(ctx);
                  AppSnack.success(context, 'Follow-up scheduled');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _History extends StatelessWidget {
  const _History({required this.lead});
  final Lead lead;

  @override
  Widget build(BuildContext context) {
    if (lead.history.isEmpty) {
      return const EmptyState(icon: Icons.history_rounded, title: 'No activity yet', compact: true);
    }
    return Timeline(
      entries: [for (final a in lead.history) TimelineEntry(title: a.title, subtitle: a.detail, time: Fmt.dateTime(a.at), color: a.kind.color)],
    );
  }
}
