import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/contact_links.dart';
import '../components/components.dart';
import 'app_update.dart';

/// Tells the person a newer version exists and, if they agree, opens the download.
/// Android then asks them to confirm the install: the app cannot install itself silently.
Future<void> showUpdateDialog(BuildContext context, WidgetRef ref, UpdateInfo update, {required String installed}) async {
  final accepted = await confirmDialog(
    context,
    title: 'Update available',
    message: [
      'ADVIO ${update.version} is ready. You are on $installed.',
      if (update.notes.isNotEmpty) update.notes,
    ].join('\n\n'),
    confirmLabel: 'Update',
    cancelLabel: 'Later',
    icon: Icons.system_update_rounded,
  );
  if (!accepted || !context.mounted) return;
  final opened = await ref.read(urlOpenerProvider)(Uri.parse(update.apkUrl));
  if (!context.mounted) return;
  if (opened) {
    AppSnack.info(context, 'Downloading. When it finishes, open the file to install.');
  } else {
    AppSnack.error(context, 'Could not open the download link.');
  }
}
