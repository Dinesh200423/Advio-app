import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/observability/app_log.dart';
import '../repositories/save_failures.dart';

/// The few database operations the app needs, as plain rows. Keeping this small means the rest of the
/// data layer can be tested without a network, and only [SupabaseGateway] knows Supabase exists.
abstract interface class RowGateway {
  Future<List<Map<String, dynamic>>> select(String table, {String orderBy = 'updated_at', bool ascending = false, int? limit});
  Future<void> upsert(String table, Map<String, Object?> row);
  Future<void> delete(String table, String id);
}

/// How long to wait for one request before treating it as a dropped connection.
const _requestTimeout = Duration(seconds: 15);

class SupabaseGateway implements RowGateway {
  SupabaseGateway(this._client);
  final SupabaseClient _client;

  @override
  Future<List<Map<String, dynamic>>> select(String table, {String orderBy = 'updated_at', bool ascending = false, int? limit}) {
    return _run('select $table', () async {
      var query = _client.from(table).select().order(orderBy, ascending: ascending);
      if (limit != null) query = query.limit(limit);
      final rows = await query.timeout(_requestTimeout);
      return [for (final r in rows) Map<String, dynamic>.from(r)];
    });
  }

  @override
  Future<void> upsert(String table, Map<String, Object?> row) {
    return _run('save $table', () => _client.from(table).upsert(row).timeout(_requestTimeout));
  }

  @override
  Future<void> delete(String table, String id) {
    return _run('delete $table', () => _client.from(table).delete().eq('id', id).timeout(_requestTimeout));
  }

  /// Runs [call], turning whatever goes wrong into a [RepositoryException] that says whether trying again could help.
  Future<R> _run<R>(String what, Future<R> Function() call) async {
    try {
      return await call();
    } catch (error) {
      throw mapSupabaseError(error, what: what);
    }
  }
}

/// Translate a Supabase/network error into something the app can act on and show to a person.
RepositoryException mapSupabaseError(Object error, {String what = 'request'}) {
  if (error is RepositoryException) return error;

  if (error is PostgrestException) {
    final code = error.code ?? '';
    // 42501: row level security or missing privilege. PGRST301/401/403: bad or expired session.
    if (code == '42501' || code == '403') {
      return const RepositoryException('You are not allowed to do that.');
    }
    if (code == 'PGRST301' || code == '401' || (error.message.toLowerCase().contains('jwt') && error.message.toLowerCase().contains('expired'))) {
      return const RepositoryException('Your session has expired. Please sign in again.');
    }
    if (code == '23505') return const RepositoryException('That number or email is already in use.');
    if (code.startsWith('23')) return const RepositoryException('That change breaks a rule in the database.');
    if (code.startsWith('22')) return const RepositoryException('Some of the information is not valid.');
    // Server-side trouble may pass: connection or resource errors (SQLSTATE 08, 53, 57) and HTTP 5xx.
    // Postgres codes are 5 characters (e.g. 42703) and HTTP statuses are 3 digits (e.g. 503): only the latter are statuses.
    final status = code.length == 3 ? int.tryParse(code) : null;
    if (code.startsWith('08') || code.startsWith('53') || code.startsWith('57') || (status != null && status >= 500)) {
      return const RepositoryException('The server is busy. Please try again.', retryable: true);
    }
    AppLog.warning('Unmapped database error', error: error, data: {'op': what, 'code': code});
    return const RepositoryException('The database rejected that change.');
  }

  if (error is AuthException) {
    return const RepositoryException('Your session has expired. Please sign in again.');
  }

  if (error is TimeoutException) {
    return const RepositoryException('The connection timed out.', retryable: true);
  }

  // Anything else (no network, DNS failure, connection reset) is treated as being offline.
  AppLog.warning('Network error', error: error, data: {'op': what});
  return const RepositoryException('You appear to be offline.', retryable: true);
}
