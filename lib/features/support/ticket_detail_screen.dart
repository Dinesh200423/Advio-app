import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../shared/widgets/notes_section.dart';
import '../clients/client_providers.dart';
import '../team/widgets/assignee_widgets.dart';
import 'support_providers.dart';

class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(ticketProvider(id));
    if (t == null) return const MissingRecord(what: 'Ticket', fallback: Routes.support);
    final client = ref.watch(clientProvider(t.clientId));
    final notifier = ref.read(ticketsProvider.notifier);

    return PageScaffold(
      title: t.number,
      actions: [
        DetailMenu(
          onEdit: () => context.push(Routes.ticketEdit(id)),
          deleteTitle: 'Delete ticket?',
          deleteMessage: '${t.number} and its history will be permanently removed.',
          onDelete: () {
            notifier.remove(id);
            context.popOr(Routes.support);
            AppSnack.success(context, 'Ticket deleted');
          },
        ),
      ],
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.title, style: AppText.sectionTitle),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: client == null ? null : () => context.push(Routes.client(client.id)),
                child: Text(client?.displayName ?? 'Unknown client', style: AppText.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () async {
                      final s = await pickOption<TicketStatus>(context, title: 'Ticket status', options: TicketStatus.values, labelOf: (s) => s.label, selected: t.status, colorOf: (s) => s.color);
                      if (s != null) notifier.setStatus(id, s);
                    },
                    child: Row(mainAxisSize: MainAxisSize.min, children: [t.status.badge, const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.muted)]),
                  ),
                  t.priority.badge,
                ],
              ),
              if (t.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(t.description, style: AppText.body),
              ],
              const SizedBox(height: 8),
              AssigneeRow(label: 'Handled by', memberId: t.assigneeId, onChanged: (id) => notifier.upsert(t.copyWith(assigneeId: id))),
              const SizedBox(height: 4),
              Text('Opened ${Fmt.dateTime(t.createdAt)}', style: AppText.caption),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (t.status.isActive)
          AppButton(
            label: 'Mark as resolved',
            onPressed: () {
              notifier.setStatus(id, TicketStatus.resolved);
              AppSnack.success(context, 'Ticket resolved');
            },
          )
        else
          AppButton.secondary(
            label: 'Reopen ticket',
            onPressed: () {
              notifier.setStatus(id, TicketStatus.open);
              AppSnack.info(context, 'Ticket reopened');
            },
          ),
        const SizedBox(height: 24),
        Text('Notes & resolution history', style: AppText.sectionTitle),
        const SizedBox(height: 12),
        AppCard(
          child: t.notes.isEmpty
              ? const Text('No history yet.')
              : Timeline(entries: [for (final n in t.notes) TimelineEntry(title: n.text, time: Fmt.dateTime(n.at), color: AppColors.primary)]),
        ),
        const SizedBox(height: 20),
        // New notes are appended to the history above, so the list inside is left empty.
        NotesSection(notes: const [], hint: 'Add an update for this ticket…', onAdd: (text) => notifier.addNote(id, text)),
      ],
    );
  }
}
