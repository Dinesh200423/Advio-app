import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/shared/contact_links.dart';
import 'package:freelance_os/shared/widgets/contact_actions.dart';

import 'helpers.dart';

Finder button(String label) => find.descendant(of: find.byType(ContactActions), matching: find.text(label));

void main() {
  group('links', () {
    test('tel keeps a leading plus and drops spaces and dashes', () {
      expect(telLink('+91 98765-43210').toString(), 'tel:+919876543210');
      expect(telLink('98765 43210').toString(), 'tel:9876543210');
      expect(telLink('12'), isNull);
      expect(telLink(''), isNull);
    });

    test('WhatsApp gets the Indian country code only when it is missing', () {
      expect(whatsappLink('98765 43210').toString(), 'https://wa.me/919876543210');
      expect(whatsappLink('098765 43210').toString(), 'https://wa.me/919876543210');
      expect(whatsappLink('+91 98765 43210').toString(), 'https://wa.me/919876543210');
      expect(whatsappLink('+1 415 555 0100').toString(), 'https://wa.me/14155550100', reason: 'other countries are left alone');
      expect(whatsappLink('abc'), isNull);
    });

    test('email and website', () {
      expect(mailLink('a@b.com').toString(), 'mailto:a@b.com');
      expect(mailLink('not an email'), isNull);
      expect(webLink('example.com').toString(), 'https://example.com');
      expect(webLink('http://example.com/x').toString(), 'http://example.com/x');
      expect(webLink(''), isNull);
      expect(webLink('nodots'), isNull);
    });
  });

  group('buttons on a lead', () {
    testWidgets('open the dialer, WhatsApp and mail with the lead\'s details', (tester) async {
      final opened = <Uri>[];
      final container = await pumpApp(tester, overrides: [
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ]);
      final lead = container.read(leadsProvider).firstWhere((l) => l.phone.isNotEmpty && l.email.isNotEmpty);
      await goTo(tester, '/leads/${lead.id}');

      await tester.tap(button('Call'));
      await tester.pump();
      await tester.tap(button('WhatsApp'));
      await tester.pump();
      await tester.tap(button('Email'));
      await tester.pump();

      expect(opened.map((u) => u.scheme), ['tel', 'https', 'mailto']);
      expect(opened[2].path, lead.email);
      expectNoFlutterErrors(tester);
    });

    testWidgets('say so when the app cannot open the link, or when nothing is saved', (tester) async {
      final container = await pumpApp(tester, overrides: [urlOpenerProvider.overrideWithValue((_) async => false)]);
      final lead = container.read(leadsProvider).firstWhere((l) => l.phone.isNotEmpty);
      await goTo(tester, '/leads/${lead.id}');
      await tester.tap(button('Call'));
      await tester.pump();
      expect(find.text('Could not open the dialer.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8)); // let the first message go, or the next one queues behind it
      await tester.pumpAndSettle();

      // A lead added by quick add has no email.
      container.read(leadsProvider.notifier).upsert(lead.copyWith(email: ''));
      await tester.pump();
      await tester.tap(button('Email'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('No email address saved.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
    });
  });
}
