import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_log.dart';
import 'error_reporter.dart';

/// Settings for error reporting, supplied at build time (see env.example.json).
abstract final class ObservabilityConfig {
  /// Sentry project address. Leave empty to keep everything on the device.
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// "development" or "production": lets reports be filtered by where they came from.
  static const environment = String.fromEnvironment('APP_ENV', defaultValue: 'development');

  static bool get reportingEnabled => sentryDsn.isNotEmpty;
}

/// Starts error reporting and then runs the app, so nothing that goes wrong is lost:
/// framework errors, uncaught async errors, and anything the app logs as an error.
Future<void> runObserved(Future<void> Function() runApp) async {
  if (ObservabilityConfig.reportingEnabled) {
    AppLog.reporter = const SentryReporter();
    await SentryFlutter.init(
      (options) {
        options.dsn = ObservabilityConfig.sentryDsn;
        options.environment = ObservabilityConfig.environment;
        options.sendDefaultPii = false; // no IP address, no user details
        options.tracesSampleRate = 0; // errors only; no performance tracing
        options.attachScreenshot = false; // screens contain client and money data
      },
      appRunner: runApp,
    );
    return;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLog.error('Flutter framework error', error: details.exception, stack: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLog.error('Uncaught error', error: error, stack: stack);
    return true;
  };
  await runApp();
}

/// Logs any provider that fails, so a broken data source is visible instead of silently showing empty screens.
base class AppProviderObserver extends ProviderObserver {
  @override
  void providerDidFail(ProviderObserverContext context, Object error, StackTrace stackTrace) {
    AppLog.error('Provider failed', error: error, stack: stackTrace, data: {'provider': context.provider.name ?? '${context.provider.runtimeType}'});
  }
}
