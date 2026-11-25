import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/app/router/routes.dart';
import 'package:freelance_os/data/backend/row_codecs.dart';
import 'package:freelance_os/data/models/modules.dart';
import 'package:freelance_os/data/models/team.dart';
import 'package:freelance_os/features/team/module_access.dart';
import 'package:freelance_os/features/team/team_providers.dart';

import 'helpers.dart';

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

bool allowed(String path, Set<AppModule> has, {bool founder = false}) =>
    pathAllowed(path, canUse: has.contains, isFounder: founder);

void main() {
  group('defaults', () {
    test('the founder gets everything, and developers do not get money or leads', () {
      expect(AppModule.defaultsFor(TeamRole.founder), AppModule.values.toSet());
      final dev = AppModule.defaultsFor(TeamRole.developer);
      expect(dev, containsAll([AppModule.tasks, AppModule.projects, AppModule.clients]));
      expect(dev, isNot(contains(AppModule.invoices)));
      expect(dev, isNot(contains(AppModule.expenses)));
      expect(dev, isNot(contains(AppModule.leads)));
      expect(AppModule.defaultsFor(TeamRole.sales), containsAll([AppModule.leads, AppModule.quotations, AppModule.invoices]));
      expect(AppModule.defaultsFor(TeamRole.sales), isNot(contains(AppModule.expenses)));
    });

    test('a new member starts with their role\'s modules, and the founder can use anything regardless', () {
      final dev = TeamMember(id: 'a', name: 'A', role: TeamRole.designer, joinedAt: DateTime(2026));
      expect(dev.modules, AppModule.defaultsFor(TeamRole.designer));
      final founder = TeamMember(id: 'f', name: 'F', role: TeamRole.founder, joinedAt: DateTime(2026), modules: {});
      expect(AppModule.values.every(founder.canUse), isTrue);
    });
  });

  group('stored in the database', () {
    test('modules round-trip, unknown names are ignored, and a linked login is detected', () {
      final member = TeamMember(id: 'a', name: 'A', role: TeamRole.sales, joinedAt: DateTime(2026), modules: {AppModule.leads, AppModule.reports});
      final row = Codecs.team.toRow(member);
      expect(row['modules'], unorderedEquals(['leads', 'reports']));
      expect(row.containsKey('user_id'), isFalse, reason: 'the app must never write the login link');

      final back = Codecs.team.fromRow({...row, 'modules': ['leads', 'flying'], 'user_id': 'u1'});
      expect(back.modules, {AppModule.leads});
      expect(back.hasLogin, isTrue);
      expect(Codecs.team.fromRow({...row, 'user_id': null}).hasLogin, isFalse);
      expect(Codecs.team.fromRow({...row, 'modules': null}).modules, isEmpty);
    });
  });

  group('which pages may be opened', () {
    final developer = AppModule.defaultsFor(TeamRole.developer);

    test('everyone can open home, more and settings', () {
      for (final p in [Routes.home, Routes.more, Routes.settings, Routes.notifications, Routes.settingsAbout]) {
        expect(allowed(p, {}), isTrue, reason: p);
      }
    });

    test('a switched-off module is closed', () {
      expect(allowed(Routes.expenses, developer), isFalse);
      expect(allowed('/expenses/e1', developer), isFalse);
      expect(allowed(Routes.invoices, developer), isFalse);
      expect(allowed(Routes.payments, developer), isFalse);
      expect(allowed(Routes.quotations, developer), isFalse);
      expect(allowed(Routes.automation, {...developer}..remove(AppModule.automation)), isFalse);
      expect(allowed(Routes.clients, developer), isTrue);
      expect(allowed(Routes.projects, developer), isTrue);
    });

    test('where work is assigned, an off module can still be looked at but not changed', () {
      expect(allowed(Routes.leads, developer), isTrue);
      expect(allowed('/leads/l1', developer), isTrue);
      expect(allowed(Routes.leadNew, developer), isFalse);
      expect(allowed(Routes.leadQuickAdd, developer), isFalse);
      expect(allowed(Routes.leadEdit('l1'), developer), isFalse);
      final noTasks = {...developer}..remove(AppModule.tasks);
      expect(allowed(Routes.tasks, noTasks), isTrue);
      expect(allowed(Routes.taskNew(), noTasks), isFalse);
      expect(allowed(Routes.taskEdit('t1'), noTasks), isFalse);
      expect(allowed(Routes.ticketNew(), {}), isFalse);
    });

    test('Finance opens for anyone with a money module', () {
      expect(allowed(Routes.finance, developer), isFalse);
      expect(allowed(Routes.finance, {AppModule.expenses}), isTrue);
      expect(allowed(Routes.finance, {AppModule.quotations}), isTrue);
    });

    test('adding or editing people is for the founder only', () {
      expect(allowed(Routes.teamNew, developer), isFalse);
      expect(allowed(Routes.memberEdit('tm2'), developer), isFalse);
      expect(allowed(Routes.teamNew, developer, founder: true), isTrue);
      expect(allowed(Routes.team, developer), isTrue);
      expect(allowed(Routes.member('tm2'), developer), isTrue);
    });
  });

  group('in the app, as a developer (Leads, Finance and money modules off)', () {
    Future<void> signInAs(WidgetTester tester, String memberId) async {
      final container = await pumpApp(tester, size: const Size(390, 2000));
      container.read(currentMemberIdProvider.notifier).switchTo(memberId);
      await settle(tester);
    }

    testWidgets('the bottom tabs and quick actions only show what they have', (tester) async {
      await signInAs(tester, 'tm2'); // Priya, developer
      final nav = find.byType(NavigationBar);
      expect(find.descendant(of: nav, matching: find.text('Home')), findsOneWidget);
      expect(find.descendant(of: nav, matching: find.text('Projects')), findsOneWidget);
      expect(find.descendant(of: nav, matching: find.text('More')), findsOneWidget);
      expect(find.descendant(of: nav, matching: find.text('Leads')), findsNothing);
      expect(find.descendant(of: nav, matching: find.text('Finance')), findsNothing);

      expect(find.text('+ Task'), findsOneWidget);
      expect(find.text('+ Project'), findsOneWidget);
      expect(find.text('+ Lead'), findsNothing);
      expect(find.text('+ Invoice'), findsNothing);
      expect(find.text('Monthly revenue'), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('the More menu hides the modules they do not have', (tester) async {
      await signInAs(tester, 'tm2');
      await goTo(tester, Routes.more);
      for (final shown in ['Tasks', 'Clients', 'Team', 'Settings']) {
        expect(find.text(shown), findsWidgets, reason: shown);
      }
      for (final hidden in ['Quotations', 'Expenses', 'Automation']) {
        expect(find.text(hidden), findsNothing, reason: hidden);
      }
    });

    testWidgets('closed pages send them home, but an assigned lead stays readable without edit controls', (tester) async {
      await signInAs(tester, 'tm2');
      await goTo(tester, Routes.expenses);
      expect(find.text('Expenses'), findsNothing);
      expect(find.textContaining('Good '), findsOneWidget, reason: 'sent back to the dashboard');

      await goTo(tester, Routes.leadNew);
      expect(find.textContaining('Good '), findsOneWidget);

      await goTo(tester, Routes.leads);
      expect(find.text('Quick add'), findsNothing);
      expect(find.byTooltip('Add lead'), findsNothing);
      expectNoFlutterErrors(tester);
    });

    testWidgets('the founder still sees everything', (tester) async {
      await pumpApp(tester, size: const Size(390, 2000));
      final nav = find.byType(NavigationBar);
      for (final tab in ['Home', 'Leads', 'Projects', 'Finance', 'More']) {
        expect(find.descendant(of: nav, matching: find.text(tab)), findsOneWidget, reason: tab);
      }
      expect(find.text('+ Invoice'), findsOneWidget);
    });

    testWidgets('changing someone\'s access takes effect straight away', (tester) async {
      final container = await pumpApp(tester, size: const Size(390, 2000));
      container.read(currentMemberIdProvider.notifier).switchTo('tm2');
      await settle(tester);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Finance')), findsNothing);

      final priya = container.read(teamProvider.notifier).byId('tm2')!;
      container.read(teamProvider.notifier).upsert(priya.copyWith(modules: {...priya.modules, AppModule.expenses}));
      await settle(tester);
      expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Finance')), findsOneWidget);
    });
  });

  group('the team member form', () {
    Finder module(AppModule m) => find.byKey(ValueKey('module-${m.name}'));
    bool isOn(WidgetTester tester, AppModule m) => tester.widget<SwitchListTile>(module(m)).value;

    testWidgets('shows a switch per module, starts from the role, and saves what was chosen', (tester) async {
      final container = await pumpApp(tester, size: const Size(390, 3200));
      await pushTo(tester, Routes.teamNew);

      for (final m in AppModule.values) {
        expect(module(m), findsOneWidget, reason: m.name);
      }
      expect(isOn(tester, AppModule.tasks), isTrue);
      expect(isOn(tester, AppModule.invoices), isFalse, reason: 'developer by default');

      await tester.enterText(find.byType(TextFormField).first, 'Ravi');
      await tester.ensureVisible(module(AppModule.invoices));
      await tester.tap(module(AppModule.invoices));
      await tester.pump();
      await tester.ensureVisible(module(AppModule.tasks));
      await tester.tap(module(AppModule.tasks));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Add member'));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      final ravi = container.read(teamProvider).firstWhere((m) => m.name == 'Ravi');
      expect(ravi.modules, contains(AppModule.invoices));
      expect(ravi.modules, isNot(contains(AppModule.tasks)));
    });

    testWidgets('changing the role changes the switches, unless they were set by hand', (tester) async {
      await pumpApp(tester, size: const Size(390, 3200));
      await pushTo(tester, Routes.teamNew);
      expect(isOn(tester, AppModule.quotations), isFalse);

      await tester.tap(find.text('Developer').first);
      await settle(tester);
      await tester.tap(find.text('Sales').last);
      await settle(tester);
      expect(isOn(tester, AppModule.quotations), isTrue, reason: 'Sales default');
      expect(isOn(tester, AppModule.leads), isTrue);
    });

    testWidgets('the founder\'s switches are all on and cannot be changed', (tester) async {
      await pumpApp(tester, size: const Size(390, 3200));
      await pushTo(tester, Routes.memberEdit('tm1'));
      expect(find.text('The founder can use everything.'), findsOneWidget);
      for (final m in AppModule.values) {
        final tile = tester.widget<SwitchListTile>(module(m));
        expect(tile.value, isTrue, reason: m.name);
        expect(tile.onChanged, isNull, reason: m.name);
      }
    });
  });
}
