import 'package:sentry_flutter/sentry_flutter.dart';

/// Where serious problems are sent so they can be seen later. The app only talks to this interface,
/// so the reporting service can change without touching the code that logs.
abstract interface class ErrorReporter {
  /// An error worth investigating. [data] must never contain personal details (names, emails, amounts).
  void report(Object error, StackTrace? stack, {String? message, Map<String, Object?>? data});

  /// A note that appears in the trail leading up to a later error.
  void breadcrumb(String message, {Map<String, Object?>? data});
}

/// Used when no crash-reporting service is configured: nothing leaves the device.
class NoopReporter implements ErrorReporter {
  const NoopReporter();

  @override
  void report(Object error, StackTrace? stack, {String? message, Map<String, Object?>? data}) {}

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {}
}

/// Sends errors to Sentry. Only active when a DSN is supplied (see [ObservabilityConfig]).
class SentryReporter implements ErrorReporter {
  const SentryReporter();

  @override
  void report(Object error, StackTrace? stack, {String? message, Map<String, Object?>? data}) {
    Sentry.captureException(
      error,
      stackTrace: stack,
      withScope: (scope) {
        if (message != null) scope.setTag('event', message);
        if (data != null && data.isNotEmpty) scope.setContexts('details', data);
      },
    );
  }

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) {
    Sentry.addBreadcrumb(Breadcrumb(message: message, data: data, level: SentryLevel.info));
  }
}
