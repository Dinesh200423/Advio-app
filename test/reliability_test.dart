import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/core/observability/app_log.dart';
import 'package:freelance_os/core/observability/error_reporter.dart';
import 'package:freelance_os/core/observability/observability.dart';
import 'package:freelance_os/data/models/common.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/data/models/lead.dart';
import 'package:freelance_os/data/models/task.dart';
import 'package:freelance_os/data/repositories/repositories.dart';
import 'package:freelance_os/data/repositories/repository.dart';
import 'package:freelance_os/data/repositories/save_failures.dart';
import 'package:freelance_os/features/clients/client_providers.dart';
import 'package:freelance_os/features/dashboard/activity_providers.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';
import 'package:freelance_os/features/tasks/task_providers.dart';

import 'helpers.dart';

/// Repository whose saves follow a script, and which remembers what it was asked to store.
class ScriptedRepository<T> implements Repository<T> {
  ScriptedRepository(Iterable<T> seed, this._idOf, {List<Object?> script = const []})
      : stored = List.of(seed),
        _script = List.of(script);

  final List<T> stored;
  final String Function(T) _idOf;

  /// One entry per upsert/delete call: null = succeed, otherwise the error to throw.
  final List<Object?> _script;

  /// Every upsert/delete attempted, in order, including the ones that failed.
  final List<String> calls = [];

  Object? _next() => _script.isEmpty ? null : _script.removeAt(0);

  @override
  List<T> getAll() => List.unmodifiable(stored);

  @override
  Future<void> upsert(T item) async {
    calls.add('upsert ${_idOf(item)}');
    final failure = _next();
    if (failure != null) throw failure;
    final i = stored.indexWhere((e) => _idOf(e) == _idOf(item));
    i < 0 ? stored.insert(0, item) : stored[i] = item;
  }

  @override
  Future<void> delete(String id) async {
    calls.add('delete $id');
    final failure = _next();
    if (failure != null) throw failure;
    stored.removeWhere((e) => _idOf(e) == id);
  }
}

class RecordingReporter implements ErrorReporter {
  final reports = <({Object error, String? message, Map<String, Object?>? data})>[];
  final breadcrumbs = <String>[];

  @override
  void report(Object error, StackTrace? stack, {String? message, Map<String, Object?>? data}) => reports.add((error: error, message: message, data: data));

  @override
  void breadcrumb(String message, {Map<String, Object?>? data}) => breadcrumbs.add(message);
}

const denied = RepositoryException('You are not allowed to change this.');
const offline = RepositoryException('You appear to be offline.', retryable: true);

Task task(String id, {String title = 'Original', Priority priority = Priority.medium}) =>
    Task(id: id, title: title, dueDate: DateTime(2030), createdAt: DateTime(2026), priority: priority);

void main() {
  ProviderContainer containerFor(ScriptedRepository<Task> repo) {
    final c = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(repo),
      retryPolicyProvider.overrideWithValue(RetryPolicy.immediate),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  group('saving', () {
    test('a change shows immediately and is stored', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a'));
      expect(c.read(tasksProvider).map((t) => t.id), ['a'], reason: 'on screen before the save finishes');
      await tasks.flush();
      expect(repo.stored.map((t) => t.id), ['a']);
      expect(c.read(saveFailureProvider), isNull);
    });

    test('a refused new record is removed again and the person is told, with no pointless Retry', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [denied]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a'));
      await tasks.flush();

      expect(c.read(tasksProvider), isEmpty);
      final failure = c.read(saveFailureProvider)!;
      expect(failure.message, contains('You are not allowed to change this.'));
      expect(failure.message, contains('It was undone'));
      expect(failure.retry, isNull, reason: 'retrying a refusal can never help');
      expect(repo.calls, ['upsert a'], reason: 'a refusal is not retried');
    });

    test('a refused edit puts the previous version back', () async {
      final repo = ScriptedRepository<Task>([task('a')], (t) => t.id, script: [denied]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a', title: 'Edited'));
      expect(c.read(tasksProvider).single.title, 'Edited');
      await tasks.flush();
      expect(c.read(tasksProvider).single.title, 'Original');
      expect(repo.stored.single.title, 'Original');
    });

    test('a dropped connection is retried automatically and the person never sees an error', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [offline, offline]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a'));
      await tasks.flush();

      expect(repo.calls, ['upsert a', 'upsert a', 'upsert a'], reason: 'third attempt succeeds');
      expect(repo.stored.map((t) => t.id), ['a']);
      expect(c.read(tasksProvider).map((t) => t.id), ['a']);
      expect(c.read(saveFailureProvider), isNull);
    });

    test('when the connection stays down the change is undone, and Retry saves it later', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [offline, offline, offline]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a'));
      await tasks.flush();
      expect(c.read(tasksProvider), isEmpty);
      final failure = c.read(saveFailureProvider)!;
      expect(failure.retry, isNotNull);

      failure.retry!(); // the connection is back
      await tasks.flush();
      expect(c.read(tasksProvider).map((t) => t.id), ['a']);
      expect(repo.stored.map((t) => t.id), ['a']);
    });

    test('a refused delete brings the record back in the same place', () async {
      final repo = ScriptedRepository<Task>([task('a'), task('b'), task('c')], (t) => t.id, script: [denied]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.remove('b');
      expect(c.read(tasksProvider).map((t) => t.id), ['a', 'c']);
      await tasks.flush();
      expect(c.read(tasksProvider).map((t) => t.id), ['a', 'b', 'c']);
    });

    test('saves are sent in the order they were made', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a', title: 'first'));
      tasks.upsert(task('a', title: 'second'));
      tasks.upsert(task('a', title: 'third'));
      await tasks.flush();

      expect(repo.calls, ['upsert a', 'upsert a', 'upsert a']);
      expect(repo.stored.single.title, 'third', reason: 'an older save never overwrites a newer one');
    });

    test('if an earlier edit fails but a later one (which contains it) succeeds, nothing is wrongly reverted', () async {
      final repo = ScriptedRepository<Task>([task('a')], (t) => t.id, script: [denied, null]);
      final c = containerFor(repo);
      final tasks = c.read(tasksProvider.notifier);

      tasks.modify('a', (t) => t.copyWith(title: 'Edited'));
      tasks.modify('a', (t) => t.copyWith(priority: Priority.urgent)); // built on top of the first edit
      await tasks.flush();

      final shown = c.read(tasksProvider).single;
      expect(shown.title, 'Edited');
      expect(shown.priority, Priority.urgent);
      expect(repo.stored.single.title, 'Edited', reason: 'the second save carried the first edit');
    });

    test('background records (the activity feed) fail quietly', () async {
      final repo = ScriptedRepository<ActivityEntry>([], (a) => a.id, script: [denied]);
      final c = ProviderContainer(overrides: [activityRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      final feed = c.read(activityProvider.notifier);

      feed.log('Something happened');
      await feed.flush();

      expect(c.read(activityProvider), isEmpty, reason: 'rolled back');
      expect(c.read(saveFailureProvider), isNull, reason: 'but no error shown');
    });

    testWidgets('the person sees a message with a Retry button when a save is refused after a drop', (tester) async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [offline, offline, offline]);
      final container = await pumpApp(tester, overrides: [
        taskRepositoryProvider.overrideWithValue(repo),
        retryPolicyProvider.overrideWithValue(RetryPolicy.immediate),
      ]);

      container.read(tasksProvider.notifier).upsert(task('zzz', title: 'Will not stick'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Couldn\'t save your change'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(container.read(tasksProvider).any((t) => t.id == 'zzz'), isTrue);
      expect(repo.stored.any((t) => t.id == 'zzz'), isTrue);
    });
  });

  group('actions that touch two records', () {
    test('repeating a lead creation does not duplicate its automation follow-up task', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final lead = Lead(
        id: 'lead_dup',
        name: 'Dup Test',
        company: 'Testco',
        email: 'd@t.co',
        phone: '',
        source: LeadSource.website,
        status: LeadStatus.newLead,
        createdAt: DateTime.now(),
        ownerId: 'tm4',
      );
      c.read(leadsProvider.notifier).create(lead);
      c.read(leadsProvider.notifier).create(lead);
      final followUps = c.read(tasksProvider).where((t) => t.title == 'Follow up with Dup Test');
      expect(followUps.length, 1);
      expect(followUps.single.assigneeId, 'tm4');
    });

    testWidgets('a converted lead cannot be converted again: one client, and the page says so', (tester) async {
      final container = await pumpApp(tester, size: const Size(390, 2400));
      final before = container.read(clientsProvider).length;

      await goTo(tester, '/leads');
      await pushTo(tester, '/leads/l7');
      await tester.tap(find.text('Convert'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.widgetWithText(FilledButton, 'Convert').last);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Back on the lead: there is nothing left to convert.
      await goTo(tester, '/leads');
      await pushTo(tester, '/leads/l7');
      expect(find.text('Converted to client'), findsOneWidget);
      expect(find.text('Convert'), findsNothing);

      expect(container.read(clientsProvider).length, before + 1);
      expect(container.read(clientsProvider.notifier).byId('client_from_l7'), isNotNull);
      // Converting again by any other route (a repeated tap, a retry) still finds the same client.
      await container.read(leadsProvider.notifier).convertToClient('l7');
      expect(container.read(clientsProvider).length, before + 1);
    });
  });

  group('observability', () {
    late RecordingReporter reporter;
    setUp(() {
      reporter = RecordingReporter();
      AppLog.reporter = reporter;
    });
    tearDown(() => AppLog.reporter = const NoopReporter());

    test('errors are reported, warnings only leave a breadcrumb, debug and info stay local', () {
      AppLog.debug('d');
      AppLog.info('i');
      AppLog.warning('w');
      AppLog.error('e', error: StateError('boom'));
      expect(reporter.reports.length, 1);
      expect(reporter.reports.single.error, isA<StateError>());
      expect(reporter.breadcrumbs, ['w']);
    });

    test('a failed save is logged with the kind of record and nothing personal', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [denied]);
      final c = ProviderContainer(overrides: [taskRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a', title: 'Call Mr Sharma about ₹50,000 invoice'));
      await tasks.flush();

      expect(reporter.breadcrumbs, contains('Save failed and was undone'));
      final everything = [...reporter.breadcrumbs, for (final r in reporter.reports) '${r.message} ${r.data}'].join(' ');
      expect(everything, isNot(contains('Sharma')));
      expect(everything, isNot(contains('50,000')));
    });

    test('an unexpected exception during a save is reported as an error', () async {
      final repo = ScriptedRepository<Task>([], (t) => t.id, script: [StateError('database exploded')]);
      final c = ProviderContainer(overrides: [taskRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);
      final tasks = c.read(tasksProvider.notifier);

      tasks.upsert(task('a'));
      await tasks.flush();

      expect(reporter.reports.single.error, isA<StateError>());
      expect(reporter.reports.single.data, {'record': 'Task', 'retryable': false});
      expect(c.read(saveFailureProvider)!.message, contains('Something went wrong'));
    });

    test('with no reporting service, framework and uncaught errors still go through the logger', () async {
      final originalFlutterHandler = FlutterError.onError;
      final originalPlatformHandler = PlatformDispatcher.instance.onError;
      addTearDown(() {
        FlutterError.onError = originalFlutterHandler;
        PlatformDispatcher.instance.onError = originalPlatformHandler;
      });

      await runObserved(() async {});

      PlatformDispatcher.instance.onError!(StateError('late failure'), StackTrace.current);
      expect(reporter.reports.map((r) => r.message), contains('Uncaught error'));

      final quietly = FlutterErrorDetails(exception: StateError('widget failure'), silent: true);
      FlutterError.onError!(quietly);
      expect(reporter.reports.map((r) => r.message), contains('Flutter framework error'));
    });
  });
}
