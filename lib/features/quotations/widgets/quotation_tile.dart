import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_text.dart';
import '../../../core/components/components.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/quotation.dart';
import '../../clients/client_providers.dart';

class QuotationTile extends ConsumerWidget {
  const QuotationTile({super.key, required this.quotation, this.showClient = true, this.margin = const EdgeInsets.only(bottom: 12)});
  final Quotation quotation;
  final bool showClient;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = showClient ? ref.watch(clientNameProvider(quotation.clientId)) : null;
    return AppListTile(
      margin: margin,
      onTap: () => context.push(Routes.quotation(quotation.id)),
      title: quotation.title,
      subtitle: '${quotation.number}${client == null ? '' : '  ·  $client'}',
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(ref.money(quotation.totals.total), style: AppText.bodyStrong),
          const SizedBox(height: 6),
          quotation.displayStatus.badge,
        ],
      ),
    );
  }
}
