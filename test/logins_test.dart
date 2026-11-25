import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/app/router/routes.dart';
import 'package:freelance_os/data/models/team.dart';
import 'package:freelance_os/features/auth/auth_providers.dart';
import 'package:freelance_os/features/team/login_service.dart';
import 'package:freelance_os/features/team/widgets/login_sheet.dart';

import 'helpers.dart';

Future<void> settle(WidgetTester tester) => tester.pumpAndSettle(const Duration(milliseconds: 100));

class _MustChange extends AuthNotifier {
  @override
  AuthState build() => const AuthState(loggedIn: true, onboarded: true, mustChangePassword: true);
}

void main() {
  group('generated passwords', () {
    test('are 12 characters, readable, and always mix capitals, small letters and digits', () {
      final random = Random(7);
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final p = generatePassword(random: random);
        seen.add(p);
        expect(p.length, 12);
        expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(p), isTrue, reason: p);
        expect(RegExp(r'[0O1lI]').hasMatch(p), isFalse, reason: 'no look-alike characters: $p');
        expect(RegExp(r'[A-Z]').hasMatch(p) && RegExp(r'[a-z]').hasMatch(p) && RegExp(r'\d').hasMatch(p), isTrue, reason: p);
      }
      expect(seen.length, greaterThan(190), reason: 'they should not repeat');
    });
  });

  group('the create-login sheet', () {
    final person = TeamMember(id: 'tm9', name: 'Ravi', role: TeamRole.developer, email: 'ravi@advio.test', joinedAt: DateTime(2026));
    final existing = TeamMember(id: 'tm8', name: 'Asha', role: TeamRole.sales, email: 'asha@advio.test', joinedAt: DateTime(2026), hasLogin: true);

    Future<List<({String memberId, String password})>> open(WidgetTester tester, TeamMember member, {Object? failWith}) async {
      final calls = <({String memberId, String password})>[];
      await pumpApp(tester, size: const Size(390, 1400), overrides: [
        loginCreatorProvider.overrideWithValue(({required memberId, required password}) async {
          calls.add((memberId: memberId, password: password));
          if (failWith != null) throw failWith;
          return !member.hasLogin;
        }),
      ]);
      showLoginSheet(tester.element(find.byType(Scaffold).first), member);
      await settle(tester);
      return calls;
    }

    testWidgets('creates the login with a suggested password, then shows what to pass on', (tester) async {
      final calls = await open(tester, person);
      expect(find.text('Create login'), findsWidgets);
      expect(find.textContaining('ravi@advio.test'), findsOneWidget);
      final suggested = tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text;
      expect(suggested.length, 12);

      await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);

      expect(calls.single, (memberId: 'tm9', password: suggested));
      expect(find.text('Ravi can now sign in.'), findsOneWidget);
      expect(find.textContaining('Password: $suggested'), findsOneWidget);
      expect(find.textContaining('only time the password is shown'), findsOneWidget);
    });

    testWidgets('the person can type their own temporary password, and Copy puts the details on the clipboard', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

      final calls = await open(tester, person);
      await tester.enterText(find.byType(TextFormField), 'Chennai2026');
      await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(calls.single.password, 'Chennai2026');

      await tester.tap(find.text('Copy details'));
      await tester.pump();
      expect(copied, 'ADVIO login\nEmail: ravi@advio.test\nPassword: Chennai2026');
    });

    testWidgets('refuses a short password without calling the server', (tester) async {
      final calls = await open(tester, person);
      await tester.enterText(find.byType(TextFormField), 'abc');
      await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
      await tester.pump();
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(calls, isEmpty);
    });

    testWidgets('shows the server\'s reason when it refuses', (tester) async {
      await open(tester, person, failWith: const LoginFailure('Only the founder can create logins.'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create login'));
      await tester.pump(const Duration(milliseconds: 100));
      await settle(tester);
      expect(find.text('Only the founder can create logins.'), findsOneWidget);
      expect(find.text('Ravi can now sign in.'), findsNothing);
    });

    testWidgets('for someone who already has a login it is a password reset', (tester) async {
      await open(tester, existing);
      expect(find.text('Reset password'), findsWidgets);
      expect(find.textContaining('Their old password stops working'), findsOneWidget);
    });
  });

  group('choosing a new password after signing in with a temporary one', () {
    testWidgets('every page leads to the change-password screen, and saving it lets them in', (tester) async {
      await pumpApp(tester, signedIn: false, overrides: [authProvider.overrideWith(_MustChange.new)]);
      expect(find.text('Choose your password'), findsOneWidget);
      expect(find.textContaining('temporary password'), findsOneWidget);

      await goTo(tester, Routes.leads);
      expect(find.text('Choose your password'), findsOneWidget, reason: 'cannot go anywhere else yet');

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'short');
      await tester.enterText(fields.at(1), 'different');
      await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
      await tester.pump();
      expect(find.text('Use at least 8 characters'), findsOneWidget);
      expect(find.text('The two passwords do not match'), findsOneWidget);

      await tester.enterText(fields.at(0), 'MyOwnPass9');
      await tester.enterText(fields.at(1), 'MyOwnPass9');
      await tester.tap(find.widgetWithText(FilledButton, 'Save password'));
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester);

      expect(find.text('Choose your password'), findsNothing);
      expect(find.textContaining('Good '), findsOneWidget, reason: 'now on the dashboard');
    });
  });
}
