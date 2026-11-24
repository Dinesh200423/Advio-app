import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Thrown by a repository when saving or deleting did not work.
class RepositoryException implements Exception {
  const RepositoryException(this.message, {this.retryable = false});

  /// Safe to show to the person using the app.
  final String message;

  /// True when trying again might succeed (connection dropped, server busy). False when it never will
  /// (not allowed, invalid data), so retrying would only delay the error.
  final bool retryable;

  @override
  String toString() => 'RepositoryException($message, retryable: $retryable)';
}

/// How long to wait before each automatic retry of a save that failed for a temporary reason.
/// Three tries in total with the defaults.
class RetryPolicy {
  const RetryPolicy({this.delays = const [Duration(milliseconds: 400), Duration(milliseconds: 1500)]});
  final List<Duration> delays;

  /// For tests: retry straight away.
  static const none = RetryPolicy(delays: []);
  static const immediate = RetryPolicy(delays: [Duration.zero, Duration.zero]);
}

/// The retry policy saves use. Tests replace it so they do not wait on real timers.
final retryPolicyProvider = Provider<RetryPolicy>((ref) => const RetryPolicy());

/// A change that could not be saved and was undone.
class SaveFailure {
  const SaveFailure({required this.message, this.retry});

  /// Shown to the person.
  final String message;

  /// Repeats the change. Null when repeating makes no sense.
  final VoidCallback? retry;

  factory SaveFailure.from(Object error, {VoidCallback? retry}) {
    final reason = switch (error) {
      RepositoryException(:final message) => message,
      TimeoutException() => 'The connection timed out.',
      _ => 'Something went wrong.',
    };
    // Only offer Retry when it could help.
    final canRetry = error is! RepositoryException || error.retryable;
    return SaveFailure(message: 'Couldn\'t save your change. $reason It was undone.', retry: canRetry ? retry : null);
  }
}

/// The most recent save failure. The app shell listens and shows it once.
class SaveFailureNotifier extends Notifier<SaveFailure?> {
  @override
  SaveFailure? build() => null;

  void report(SaveFailure failure) => state = failure;
}

final saveFailureProvider = NotifierProvider<SaveFailureNotifier, SaveFailure?>(SaveFailureNotifier.new);
