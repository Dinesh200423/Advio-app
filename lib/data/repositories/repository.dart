import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/observability/app_log.dart';
import 'save_failures.dart';

/// Storage contract for a collection of records.
///
/// [MockRepository] keeps everything in memory. A Supabase-backed class implements this same
/// interface and is swapped in by overriding the provider in `repositories.dart`, so no
/// feature or screen code changes.
///
/// Implementations report problems by throwing [RepositoryException]: `retryable: true` for
/// things that may work a moment later (network drop, timeout), false for things that never
/// will (permission denied, invalid data).
abstract interface class Repository<T> {
  /// Current in-memory snapshot used to seed UI state synchronously.
  List<T> getAll();

  Future<void> upsert(T item);

  Future<void> delete(String id);
}

/// In-memory implementation backed by a plain list (session-only data).
class MockRepository<T> implements Repository<T> {
  MockRepository(Iterable<T> seed, this._idOf) : _items = List.of(seed);

  final List<T> _items;
  final String Function(T) _idOf;

  @override
  List<T> getAll() => List.unmodifiable(_items);

  @override
  Future<void> upsert(T item) async {
    final i = _items.indexWhere((e) => _idOf(e) == _idOf(item));
    if (i < 0) {
      _items.insert(0, item);
    } else {
      _items[i] = item;
    }
  }

  @override
  Future<void> delete(String id) async => _items.removeWhere((e) => _idOf(e) == id);
}

/// Base Riverpod notifier for a list of records persisted through a [Repository].
///
/// Changes show on screen immediately, then are saved in the background. If saving fails:
///  * a brief network problem is retried automatically (see [retryPolicy]);
///  * otherwise the change is undone, so the screen never shows something that was not stored,
///    and the person is told, with a Retry button.
///
/// Saves run one at a time, in the order they were made, so an older save can never overwrite a newer one.
abstract class CrudNotifier<T> extends Notifier<List<T>> {
  Repository<T> get repository;
  String idOf(T item);

  /// Whether a failed save is shown to the person. Turn off for background records
  /// (activity feed, notifications) where an error message would only be noise.
  bool get reportFailures => true;

  RetryPolicy get retryPolicy => ref.read(retryPolicyProvider);

  Future<void> _writes = Future.value();

  /// Completes when every save started so far has finished (stored, or undone after failing).
  Future<void> flush() => _writes;

  @override
  List<T> build() => repository.getAll();

  T? byId(String? id) {
    if (id == null) return null;
    for (final e in state) {
      if (idOf(e) == id) return e;
    }
    return null;
  }

  /// Insert (at the top) or replace by id.
  void upsert(T item) {
    final id = idOf(item);
    final index = state.indexWhere((e) => idOf(e) == id);
    final before = index < 0 ? null : state[index];

    state = index < 0 ? [item, ...state] : ([...state]..[index] = item);

    _persist(
      write: () => repository.upsert(item),
      undo: () {
        // If a newer version replaced this one meanwhile, that version carries these changes too: leave it.
        if (!identical(byId(id), item)) return;
        state = before == null ? state.where((e) => idOf(e) != id).toList() : [for (final e in state) idOf(e) == id ? before : e];
      },
      retry: () => upsert(item),
    );
  }

  void remove(String id) {
    final index = state.indexWhere((e) => idOf(e) == id);
    if (index < 0) return;
    final removed = state[index];

    state = [...state]..removeAt(index);

    _persist(
      write: () => repository.delete(id),
      undo: () {
        if (byId(id) != null) return;
        final list = [...state];
        list.insert(index.clamp(0, list.length), removed);
        state = list;
      },
      retry: () => remove(id),
    );
  }

  /// Apply [update] to the record with [id], if it exists.
  void modify(String id, T Function(T current) update) {
    final current = byId(id);
    if (current != null) upsert(update(current));
  }

  void _persist({required Future<void> Function() write, required void Function() undo, required void Function() retry}) {
    _writes = _writes.then((_) async {
      try {
        await _withRetry(write);
      } catch (error, stack) {
        if (!ref.mounted) return;
        undo();
        final data = {'record': '$T', 'retryable': error is RepositoryException && error.retryable};
        if (error is RepositoryException || error is TimeoutException) {
          AppLog.warning('Save failed and was undone', error: error, data: data);
        } else {
          AppLog.error('Save failed unexpectedly and was undone', error: error, stack: stack, data: data);
        }
        if (reportFailures) ref.read(saveFailureProvider.notifier).report(SaveFailure.from(error, retry: retry));
      }
    });
  }

  Future<void> _withRetry(Future<void> Function() write) async {
    final delays = retryPolicy.delays;
    for (var attempt = 0;; attempt++) {
      try {
        await write();
        return;
      } catch (error) {
        final transient = error is TimeoutException || (error is RepositoryException && error.retryable);
        if (!transient || attempt >= delays.length) rethrow;
        AppLog.warning('Save failed, trying again', data: {'record': '$T', 'attempt': attempt + 1});
        await Future<void>.delayed(delays[attempt]);
      }
    }
  }
}
