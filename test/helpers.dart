import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/app/app.dart';
import 'package:freelance_os/core/update/app_update.dart';
import 'package:freelance_os/features/auth/auth_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class _SignedInAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(loggedIn: true, onboarded: true);
}

/// Pumps the app on a phone-sized surface (default 390x844), signed in by default.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  bool signedIn = true,
  Size size = const Size(390, 844),
  List<Override> overrides = const [],

  /// What the update check finds. Defaults to nothing, so no test touches the network or meets an update prompt.
  UpdateChecker? updateCheck,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.physicalSize = Size(size.width * 3, size.height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      if (signedIn) authProvider.overrideWith(_SignedInAuth.new),
      updateCheckerProvider.overrideWithValue(updateCheck ?? () async => null),
      installedVersionProvider.overrideWith((ref) async => '1.0.0'),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const AdvioApp()));
  // Splash holds for ~2.2s before routing on.
  await tester.pump(const Duration(milliseconds: 2400));
  await tester.pump(const Duration(milliseconds: 600));
  return container;
}

/// Navigate with GoRouter from anywhere in the widget tree.
Future<void> goTo(WidgetTester tester, String route) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).go(route);
  await tester.pumpAndSettle();
}

/// Same as [goTo] but pushes (keeps a back stack, like in-app taps do).
Future<void> pushTo(WidgetTester tester, String route) async {
  GoRouter.of(tester.element(find.byType(Scaffold).first)).push(route);
  await tester.pumpAndSettle();
}

void expectNoFlutterErrors(WidgetTester tester) {
  final exception = tester.takeException();
  expect(exception, isNull, reason: 'Unexpected exception: $exception');
}
