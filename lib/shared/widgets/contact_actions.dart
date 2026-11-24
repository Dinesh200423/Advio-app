import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/components/components.dart';
import '../contact_links.dart';

/// Call / Email / WhatsApp buttons. Each opens the matching app on the phone.
class ContactActions extends ConsumerWidget {
  const ContactActions({super.key, required this.phone, required this.email});
  final String phone;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> open(Uri? uri, String missing, String failed) async {
      if (uri == null) {
        AppSnack.info(context, missing);
        return;
      }
      final opened = await ref.read(urlOpenerProvider)(uri);
      if (!opened && context.mounted) AppSnack.error(context, failed);
    }

    Widget button(IconData icon, String label, Uri? uri, String missing, String failed) => Expanded(
          child: AppButton.secondary(
            label: label,
            icon: icon,
            compact: true,
            // Stays tappable even with nothing to open, so the person is told why instead of facing a dead button.
            onPressed: () => open(uri, missing, failed),
          ),
        );

    return Row(
      children: [
        button(Icons.call_rounded, 'Call', telLink(phone), 'No phone number saved.', 'Could not open the dialer.'),
        const SizedBox(width: 8),
        button(Icons.mail_rounded, 'Email', mailLink(email), 'No email address saved.', 'No email app found.'),
        const SizedBox(width: 8),
        button(Icons.chat_bubble_rounded, 'WhatsApp', whatsappLink(phone), 'No phone number saved.', 'Could not open WhatsApp.'),
      ],
    );
  }
}
