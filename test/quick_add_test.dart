import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/backend/row_codecs.dart';
import 'package:freelance_os/data/models/client.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/data/models/lead.dart';
import 'package:freelance_os/features/leads/lead_duplicates.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/features/tasks/task_providers.dart';

import 'helpers.dart';

Lead lead({String name = 'Saravana Dental Clinic', String phone = '', String website = '', String location = ''}) => Lead(
      id: 'l1',
      name: name,
      company: '',
      email: '',
      phone: phone,
      source: LeadSource.googleMaps,
      status: LeadStatus.newLead,
      createdAt: DateTime(2026, 11, 24),
      website: website,
      location: location,
    );

DuplicateMatch? check({String name = 'New Place', String phone = '', String website = '', String location = '', List<Lead> leads = const [], List<Client> clients = const []}) =>
    findDuplicate(name: name, phone: phone, website: website, location: location, leads: leads, clients: clients);

void main() {
  group('duplicate detection', () {
    test('phone numbers match however they are written', () {
      final leads = [lead(phone: '+91 98765 43210')];
      expect(check(phone: '9876543210', leads: leads)?.reason, 'same phone number');
      expect(check(phone: '098765-43210', leads: leads), isNotNull);
      expect(check(phone: '98765 43211', leads: leads), isNull);
    });

    test('websites match with or without scheme, www and path', () {
      final leads = [lead(website: 'https://www.Example.com/contact')];
      expect(check(website: 'example.com', leads: leads)?.reason, 'same website');
      expect(check(website: 'http://example.org', leads: leads), isNull);
    });

    test('the same name matches only in the same area', () {
      final leads = [lead(location: 'Velachery')];
      expect(check(name: 'saravana dental clinic', location: 'velachery', leads: leads)?.reason, 'same name in the same area');
      expect(check(name: 'Saravana Dental Clinic', location: 'Anna Nagar', leads: leads), isNull, reason: 'a different branch');
      expect(check(name: 'Saravana Dental Clinic', location: '', leads: leads), isNull, reason: 'no area, so no guess');
    });

    test('too-short phone numbers and empty websites never match each other', () {
      expect(check(phone: '12', website: '', leads: [lead(phone: '12')]), isNull);
      expect(check(website: '', leads: [lead(website: '')]), isNull);
    });

    test('an existing client is reported as a client', () {
      final client = Client(id: 'c1', name: 'Dr Rao', company: 'Rao Clinic', email: '', phone: '98765 43210', createdAt: DateTime(2026));
      final match = check(phone: '9876543210', clients: [client]);
      expect(match?.isClient, isTrue);
      expect(match?.name, 'Rao Clinic');
    });
  });

  test('website and area survive a round trip through the database row', () {
    final back = Codecs.lead.fromRow(Codecs.lead.toRow(lead(website: 'a.com', location: 'Adyar', phone: '98765 43210')));
    expect(back.website, 'a.com');
    expect(back.location, 'Adyar');
  });

  group('quick add screen', () {
    testWidgets('saves a lead, clears the business fields, keeps the area, and creates a follow-up task', (tester) async {
      final container = await pumpApp(tester);
      final leadsBefore = container.read(leadsProvider).length;
      final tasksBefore = container.read(tasksProvider).length;
      await pushTo(tester, '/leads/quick');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Test Bakery');
      await tester.enterText(fields.at(1), '90000 11111');
      await tester.enterText(fields.at(2), 'Adyar');
      await tester.tap(find.text('No website found'));
      await tester.pump();
      await tester.tap(find.text('Save and add next'));
      await tester.pump(const Duration(milliseconds: 300));

      final leads = container.read(leadsProvider);
      expect(leads.length, leadsBefore + 1);
      final saved = leads.firstWhere((l) => l.name == 'Test Bakery');
      expect(saved.source, LeadSource.googleMaps);
      expect(saved.location, 'Adyar');
      expect(saved.website, '');
      expect(saved.service, ServiceInterest.website);
      expect(saved.ownerId, isNotNull);
      expect(saved.notes.single.text, contains('No website found'));
      expect(container.read(tasksProvider).length, tasksBefore + 1, reason: 'the follow-up automation ran');

      expect(find.text('Done (1 added)'), findsOneWidget);
      expect(tester.widget<TextFormField>(fields.at(0)).controller!.text, '');
      expect(tester.widget<TextFormField>(fields.at(2)).controller!.text, 'Adyar', reason: 'area is kept for the next one');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expectNoFlutterErrors(tester);
    });

    testWidgets('warns about a duplicate and only saves it after "Add anyway"', (tester) async {
      final container = await pumpApp(tester);
      final existing = container.read(leadsProvider).firstWhere((l) => l.phone.isNotEmpty);
      final before = container.read(leadsProvider).length;
      await pushTo(tester, '/leads/quick');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Some Other Name');
      await tester.enterText(fields.at(1), existing.phone);
      await tester.tap(find.text('Save and add next'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Already in your leads'), findsOneWidget);
      expect(container.read(leadsProvider).length, before, reason: 'nothing saved yet');

      await tester.tap(find.text('Add anyway'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(leadsProvider).length, before + 1);
      await tester.pumpAndSettle(const Duration(seconds: 5));
    });

    testWidgets('needs a name and a phone number', (tester) async {
      final container = await pumpApp(tester);
      final before = container.read(leadsProvider).length;
      await pushTo(tester, '/leads/quick');
      await tester.tap(find.text('Save and add next'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Business name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
      expect(container.read(leadsProvider).length, before);
    });

    testWidgets('is reachable from the Leads screen, and fits a small phone', (tester) async {
      await pumpApp(tester, size: const Size(320, 640));
      await goTo(tester, '/leads');
      await tester.tap(find.text('Quick add'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Business name'), findsWidgets);
      expectNoFlutterErrors(tester);
    });
  });
}
