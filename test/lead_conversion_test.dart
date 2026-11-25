import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/models/client.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/data/models/lead.dart';
import 'package:freelance_os/data/repositories/repositories.dart';
import 'package:freelance_os/data/repositories/repository.dart';
import 'package:freelance_os/data/repositories/save_failures.dart';
import 'package:freelance_os/features/clients/client_providers.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/features/projects/project_providers.dart';

import 'helpers.dart';

Lead enquiry({String id = 'lead_web_1'}) => Lead(
      id: id,
      name: 'Neha Verma',
      company: 'Craftly',
      email: 'neha@craftly.in',
      phone: '98765 43210',
      source: LeadSource.website,
      status: LeadStatus.newLead,
      createdAt: DateTime(2026, 11, 25),
      service: ServiceInterest.website,
      budget: BudgetBand.from25kTo60k,
      estimatedValue: 42500,
      interest: 'A marketplace website for handmade goods with seller accounts and online payments.',
      ownerId: 'tm1',
      location: 'Adyar, Chennai',
      website: 'craftly.in',
    );

/// A client table that refuses every save.
class _BrokenClients extends MockRepository<Client> {
  _BrokenClients() : super(const [], (c) => c.id);
  @override
  Future<void> upsert(Client item) => throw const RepositoryException('The database rejected that change.');
}

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer(overrides: [retryPolicyProvider.overrideWithValue(RetryPolicy.immediate)]));
  tearDown(() => container.dispose());

  group('converting a lead', () {
    test('makes the client and a planned project that carry what the enquiry asked for', () async {
      final lead = enquiry();
      container.read(leadsProvider.notifier).upsert(lead);

      final result = await container.read(leadsProvider.notifier).convertToClient(lead.id);

      expect(result, isNotNull);
      final client = container.read(clientsProvider.notifier).byId(result!.clientId)!;
      expect(client.company, 'Craftly');
      expect(client.email, 'neha@craftly.in');
      expect(client.phone, '98765 43210');
      expect(client.address, 'Adyar, Chennai');
      expect(client.website, 'craftly.in');
      expect(client.notes.first.text, contains('marketplace website for handmade goods'), reason: 'requirements reach the client');

      final project = container.read(projectsProvider.notifier).byId(result.projectId!)!;
      expect(project.name, 'Craftly · Website');
      expect(project.clientId, client.id);
      expect(project.status, ProjectStatus.planned);
      expect(project.budget, 42500);
      expect(project.ownerId, 'tm1');
      expect(project.description, contains('marketplace website for handmade goods'), reason: 'requirements show in the project');
      expect(project.description, contains('Service: Website Development'));
      expect(project.description, contains('Budget range: ₹25,000 – ₹60,000'));
      expect(project.description, contains('Source: Website enquiry'));

      final after = container.read(leadsProvider.notifier).byId(lead.id)!;
      expect(after.status, LeadStatus.won);
      expect(after.history.map((h) => h.title), contains('Converted to client'));
    });

    test('converting again does not add a second client or project', () async {
      final lead = enquiry();
      container.read(leadsProvider.notifier).upsert(lead);
      final clientsBefore = container.read(clientsProvider).length;
      final projectsBefore = container.read(projectsProvider).length;

      await container.read(leadsProvider.notifier).convertToClient(lead.id);
      await container.read(leadsProvider.notifier).convertToClient(lead.id);

      expect(container.read(clientsProvider).length, clientsBefore + 1);
      expect(container.read(projectsProvider).length, projectsBefore + 1);
    });

    test('if the client cannot be saved, nothing is converted and the lead is left as it was', () async {
      container.dispose();
      container = ProviderContainer(overrides: [
        retryPolicyProvider.overrideWithValue(RetryPolicy.immediate),
        clientRepositoryProvider.overrideWithValue(_BrokenClients()),
      ]);
      final lead = enquiry();
      container.read(leadsProvider.notifier).upsert(lead);
      final projectsBefore = container.read(projectsProvider).length;

      final result = await container.read(leadsProvider.notifier).convertToClient(lead.id);

      expect(result, isNull);
      expect(container.read(clientsProvider), isEmpty);
      expect(container.read(projectsProvider).length, projectsBefore, reason: 'no project without a client');
      expect(container.read(leadsProvider.notifier).byId(lead.id)!.status, LeadStatus.newLead, reason: 'not marked Won');
    });

    test('a quick-added shop with no email or requirements still converts', () async {
      final shop = Lead(
        id: 'lead_shop',
        name: 'Saravana Dental Clinic',
        company: '',
        email: '',
        phone: '90000 11111',
        source: LeadSource.googleMaps,
        status: LeadStatus.newLead,
        createdAt: DateTime(2026, 11, 25),
        location: 'Velachery',
      );
      container.read(leadsProvider.notifier).upsert(shop);
      final result = await container.read(leadsProvider.notifier).convertToClient(shop.id);
      final project = container.read(projectsProvider.notifier).byId(result!.projectId!)!;
      expect(project.name, startsWith('Saravana Dental Clinic'));
      expect(project.description, contains('Source: Google Maps'));
    });
  });

  group('on the lead page', () {
    testWidgets('Convert makes the client, then shows Converted with links, and the project shows the requirements', (tester) async {
      final lead = enquiry();
      final c = await pumpApp(tester, size: const Size(390, 1800));
      c.read(leadsProvider.notifier).upsert(lead);
      await goTo(tester, '/leads/${lead.id}');

      expect(find.text('Convert'), findsOneWidget);
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Convert').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Lands on the new client.
      expect(find.text('Craftly'), findsWidgets);
      expect(c.read(clientsProvider.notifier).byId(lead.convertedClientId), isNotNull);

      await goTo(tester, '/leads/${lead.id}');
      expect(find.text('Converted to client'), findsOneWidget);
      expect(find.text('View client'), findsOneWidget);
      expect(find.text('View project'), findsOneWidget);
      expect(find.text('Convert'), findsNothing);

      await tester.tap(find.text('View project'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.textContaining('marketplace website for handmade goods'), findsWidgets);
      expectNoFlutterErrors(tester);
    });

    testWidgets('the Leads list marks a converted lead as Converted', (tester) async {
      final lead = enquiry();
      final c = await pumpApp(tester, size: const Size(390, 2000));
      c.read(leadsProvider.notifier).upsert(lead);
      await c.read(leadsProvider.notifier).convertToClient(lead.id);
      await goTo(tester, '/leads');
      await tester.enterText(find.byType(TextField).first, 'Craftly');
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Converted'), findsOneWidget);
    });

    testWidgets('a lead marked Won with no client offers to finish converting it', (tester) async {
      final lead = enquiry().copyWith(status: LeadStatus.won);
      final c = await pumpApp(tester, size: const Size(390, 1800));
      c.read(leadsProvider.notifier).upsert(lead);
      await goTo(tester, '/leads/${lead.id}');
      expect(find.text('Marked Won, but no client has been created yet.'), findsOneWidget);
    });
  });
}
