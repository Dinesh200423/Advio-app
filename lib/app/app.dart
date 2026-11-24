import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../core/observability/observability.dart';
import '../data/repositories/save_failures.dart';
import '../features/auth/auth_providers.dart';
import '../features/settings/settings_providers.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// Lets non-widget code (save failures) show messages on whichever screen is open.
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// The root of the app. Signing out changes the session number, which replaces the whole provider scope,
/// so every loaded record is dropped and the next person starts clean.
class AdvioRoot extends StatelessWidget {
  const AdvioRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: sessionReset,
      builder: (context, session, _) => ProviderScope(
        key: ValueKey(session),
        observers: [AppProviderObserver()],
        child: const AdvioApp(),
      ),
    );
  }
}

class AdvioApp extends ConsumerWidget {
  const AdvioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final textScale = ref.watch(settingsProvider.select((s) => s.textScale));

    // A change that could not be saved was undone: say so, and offer to try again.
    ref.listen(saveFailureProvider, (_, failure) {
      if (failure == null) return;
      appMessengerKey.currentState
        ?..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(failure.message),
            duration: const Duration(seconds: 7),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            action: failure.retry == null ? null : SnackBarAction(label: 'Retry', textColor: AppColors.accent, onPressed: failure.retry!),
          ),
        );
    });

    return MaterialApp.router(
      scaffoldMessengerKey: appMessengerKey,
      title: 'ADVIO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
