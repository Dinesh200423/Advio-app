import 'package:flutter/foundation.dart';

import 'error_reporter.dart';

enum LogLevel { debug, info, warning, error }

/// The one place the app records what happened.
///
///  * debug / info: printed while developing, never sent anywhere.
///  * warning: printed, and kept as a breadcrumb so it shows up in the trail before a later error.
///  * error: printed and sent to the [reporter].
///
/// Log ids and event names, not people: no names, emails, phone numbers or money amounts.
abstract final class AppLog {
  /// Replaced at start-up when a crash-reporting service is configured.
  static ErrorReporter reporter = const NoopReporter();

  static void debug(String message, {Map<String, Object?>? data}) => _write(LogLevel.debug, message, data: data);
  static void info(String message, {Map<String, Object?>? data}) => _write(LogLevel.info, message, data: data);
  static void warning(String message, {Object? error, Map<String, Object?>? data}) =>
      _write(LogLevel.warning, message, error: error, data: data);
  static void error(String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) =>
      _write(LogLevel.error, message, error: error, stack: stack, data: data);

  static void _write(LogLevel level, String message, {Object? error, StackTrace? stack, Map<String, Object?>? data}) {
    // Quiet in release builds except for things that went wrong.
    if (!kReleaseMode || level.index >= LogLevel.warning.index) {
      final extra = [if (data != null && data.isNotEmpty) '$data', if (error != null) '$error'].join(' ');
      debugPrint('[${level.name}] $message${extra.isEmpty ? '' : ' $extra'}');
    }
    switch (level) {
      case LogLevel.warning:
        reporter.breadcrumb(message, data: data);
      case LogLevel.error:
        reporter.report(error ?? message, stack, message: message, data: data);
      case LogLevel.debug || LogLevel.info:
        break;
    }
  }
}
