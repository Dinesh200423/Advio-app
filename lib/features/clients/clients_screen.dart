import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_text.dart';
import '../../core/components/components.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/client.dart';
import '../../data/models/enums.dart';
import '../projects/project_providers.dart';
import 'client_providers.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  const ClientsScreen({super.key});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  String _query = '';
  ClientStatus? _status;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(clientsProvider);
    final q = _query.trim().toLowerCase();
    final clients = all.where((Client c) {
      if (_status != null && c.status != _status) return false;
      return q.isEmpty || c.name.toLowerCase().contains(q) || c.company.toLowerCase().contains(q) || c.email.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final filtering = q.isNotEmpty || _status != null;

    return PageScaffold(
      title: 'Clients',
      onRefresh: () => mockRefresh(context),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.clientNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add client'),
      ),
      header: Column(
        children: [
          AppSearchBar(hint: 'Search clients', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 12),
          FilterChipRow<ClientStatus>(
            options: ClientStatus.values,
            selected: _status,
            labelOf: (s) => s.label,
            countOf: (s) => s == null ? all.length : all.where((c) => c.status == s).length,
            onSelected: (s) => setState(() => _status = s),
          ),
        ],
      ),
      children: [
        if (clients.isEmpty)
          EmptyState(
            icon: filtering ? Icons.search_off_rounded : Icons.business_rounded,
            title: filtering ? 'No clients match' : 'No clients yet',
            message: filtering ? 'Try a different search.' : 'Add a client or convert a won lead.',
            actionLabel: filtering ? null : 'Add client',
            onAction: () => context.push(Routes.clientNew),
          )
        else
          for (final c in clients) _ClientTile(client: c),
      ],
    );
  }
}

class _ClientTile extends ConsumerWidget {
  const _ClientTile({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(clientProjectsProvider(client.id));
    final active = projects.where((p) => p.status == ProjectStatus.active).length;
    final value = ref.watch(clientLifetimeValueProvider(client.id));
    return AppListTile(
      onTap: () => context.push(Routes.client(client.id)),
      leading: InitialsAvatar(name: client.displayName),
      title: client.displayName,
      subtitle: client.company.isNotEmpty ? client.name : client.email,
      meta: Wrap(
        spacing: 8,
        children: [
          client.status.badge,
          if (active > 0) StatusBadge(label: '$active active project${active == 1 ? '' : 's'}', color: ProjectStatus.active.color, dot: false),
        ],
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.money(value, compact: true), style: AppText.bodyStrong),
          Text('lifetime', style: AppText.caption),
        ],
      ),
    );
  }
}
