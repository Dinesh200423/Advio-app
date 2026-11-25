import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/backend/row_codecs.dart';
import 'package:freelance_os/data/backend/row_gateway.dart';
import 'package:freelance_os/data/backend/supabase_repository.dart';
import 'package:freelance_os/data/mock/mock_business.dart';
import 'package:freelance_os/data/mock/mock_checklist_templates.dart';
import 'package:freelance_os/data/mock/mock_checklists.dart';
import 'package:freelance_os/data/mock/mock_crm.dart';
import 'package:freelance_os/data/mock/mock_team.dart';
import 'package:freelance_os/data/models/task.dart';
import 'package:freelance_os/data/repositories/save_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Every kind of record the sample data contains, keyed by its codec.
Map<RowCodec<dynamic>, List<dynamic>> samples() => {
      Codecs.team: MockTeam.members(),
      Codecs.client: MockCrm.clients(),
      Codecs.lead: MockCrm.leads(),
      Codecs.project: MockCrm.projects(),
      Codecs.task: MockCrm.tasks(),
      Codecs.checklistTemplate: MockChecklistTemplates.all(),
      Codecs.projectChecklist: MockChecklists.all(),
      Codecs.quotation: MockBusiness.quotations(),
      Codecs.invoice: MockBusiness.invoices(),
      Codecs.expense: MockBusiness.expenses(),
      Codecs.ticket: MockBusiness.tickets(),
      Codecs.maintenancePlan: MockBusiness.plans(),
      Codecs.automationRule: MockBusiness.automations(),
      Codecs.activity: MockBusiness.activity(),
      Codecs.notification: MockBusiness.notifications(),
    };

/// What the database hands back: JSON over the wire, plus columns it maintains itself.
Map<String, dynamic> viaWire(Map<String, Object?> row) {
  final wire = Map<String, dynamic>.from(jsonDecode(jsonEncode(row)) as Map);
  wire['updated_at'] = DateTime.now().toUtc().toIso8601String();
  return wire;
}

/// Parses `create table public.x ( ... )` blocks from the schema migration.
Map<String, ({Set<String> columns, Set<String> required})> parseSchema(String sql) {
  final tables = <String, ({Set<String> columns, Set<String> required})>{};
  for (final m in RegExp(r'create table public\.(\w+) \(([\s\S]*?)\n\);').allMatches(sql)) {
    final columns = <String>{};
    final required = <String>{};
    for (final raw in m.group(2)!.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('--')) continue;
      final match = RegExp(r'^(\w+)\s+(.+?),?$').firstMatch(line);
      if (match == null) continue;
      final name = match.group(1)!;
      if (const {'primary', 'unique', 'constraint', 'check', 'foreign'}.contains(name)) continue;
      columns.add(name);
      final rest = match.group(2)!.toLowerCase();
      final mustSupply = rest.contains('primary key') || (rest.contains('not null') && !rest.contains('default'));
      if (mustSupply) required.add(name);
    }
    tables[m.group(1)!] = (columns: columns, required: required);
  }
  // Columns added by later migrations: `alter table public.x add column if not exists name type ...;`
  for (final m in RegExp(r'alter table public\.(\w+) add column(?: if not exists)? (\w+)([^;]*);').allMatches(sql)) {
    final table = tables[m.group(1)!];
    if (table == null) continue;
    table.columns.add(m.group(2)!);
    final rest = m.group(3)!.toLowerCase();
    if (rest.contains('not null') && !rest.contains('default')) table.required.add(m.group(2)!);
  }
  return tables;
}

class FakeGateway implements RowGateway {
  final Map<String, List<Map<String, dynamic>>> tables = {};
  Object? failNext;
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> select(String table, {String orderBy = 'updated_at', bool ascending = false, int? limit}) async {
    calls.add('select $table by $orderBy limit $limit');
    return [...?tables[table]];
  }

  @override
  Future<void> upsert(String table, Map<String, Object?> row) async {
    calls.add('upsert $table');
    if (failNext != null) {
      final e = failNext!;
      failNext = null;
      throw e;
    }
    final rows = tables.putIfAbsent(table, () => []);
    final i = rows.indexWhere((r) => r['id'] == row['id']);
    final stored = viaWire(row);
    i < 0 ? rows.add(stored) : rows[i] = stored;
  }

  @override
  Future<void> delete(String table, String id) async {
    calls.add('delete $table');
    if (failNext != null) {
      final e = failNext!;
      failNext = null;
      throw e;
    }
    tables[table]?.removeWhere((r) => r['id'] == id);
  }
}

void main() {
  group('rows match the database schema', () {
    // Every migration in order, so columns added later (alter table ... add column) count too.
    final migrations = Directory('supabase/migrations').listSync().whereType<File>().toList()..sort((a, b) => a.path.compareTo(b.path));
    final schema = parseSchema(migrations.map((f) => f.readAsStringSync()).join('\n'));

    test('the schema file was parsed (sanity check)', () {
      expect(schema.keys, containsAll(['team_members', 'leads', 'tasks', 'invoices', 'project_checklists']));
      expect(schema['leads']!.columns, containsAll(['id', 'owner_id', 'follow_ups']));
      expect(schema['leads']!.required, containsAll(['id', 'name', 'source', 'status']));
      expect(schema['leads']!.required, isNot(contains('company')), reason: 'has a default');
    });

    test('every codec has a table, and uses only columns that exist in it', () {
      for (final entry in samples().entries) {
        final codec = entry.key;
        final table = schema[codec.table];
        expect(table, isNotNull, reason: 'no table "${codec.table}" in the migration');
        final written = codec.encode(entry.value.first).keys.toSet();
        final unknown = written.difference(table!.columns);
        expect(unknown, isEmpty, reason: '${codec.table}: the app writes columns that do not exist: $unknown');
        expect(codec.orderBy, isIn(table.columns), reason: '${codec.table}: cannot order by ${codec.orderBy}');
      }
    });

    test('every required column is supplied, so an insert cannot be rejected for a missing value', () {
      for (final entry in samples().entries) {
        final table = schema[entry.key.table]!;
        final written = entry.key.encode(entry.value.first).keys.toSet();
        expect(table.required.difference(written), isEmpty, reason: '${entry.key.table}: missing required columns');
      }
    });

    test('the app never overwrites columns the database owns', () {
      for (final entry in samples().entries) {
        final written = entry.key.encode(entry.value.first).keys;
        expect(written, isNot(contains('updated_at')), reason: entry.key.table);
        expect(written, isNot(contains('user_id')), reason: '${entry.key.table}: would unlink a login');
      }
    });

    test('every table in the schema is either mapped or deliberately left alone', () {
      final mapped = Codecs.all.map((c) => c.table).toSet();
      expect(schema.keys.toSet().difference(mapped), {'workspace_settings'}, reason: 'company settings are still kept on the device');
    });
  });

  group('records survive the trip to the database and back', () {
    test('every sample record, over JSON, comes back identical', () {
      for (final entry in samples().entries) {
        final codec = entry.key;
        for (final item in entry.value) {
          final row = codec.encode(item);
          final back = codec.fromRow(viaWire(row));
          expect(jsonEncode(codec.encode(back)), jsonEncode(row), reason: '${codec.table} ${codec.idOfItem(item)} changed on the round trip');
        }
      }
    });

    test('nested lists keep their content and order (lead notes, invoice payments, checklist evidence)', () {
      final lead = MockCrm.leads().firstWhere((l) => l.followUps.isNotEmpty && l.notes.isNotEmpty);
      final leadBack = Codecs.lead.fromRow(viaWire(Codecs.lead.toRow(lead)));
      expect(leadBack.followUps.map((f) => f.id), lead.followUps.map((f) => f.id));
      expect(leadBack.notes.first.text, lead.notes.first.text);
      expect(leadBack.service, lead.service);
      expect(leadBack.budget, lead.budget);
      expect(leadBack.ownerId, lead.ownerId);

      final invoice = MockBusiness.invoices().firstWhere((i) => i.payments.isNotEmpty);
      final invoiceBack = Codecs.invoice.fromRow(viaWire(Codecs.invoice.toRow(invoice)));
      expect(invoiceBack.payments.map((p) => p.amount), invoice.payments.map((p) => p.amount));
      expect(invoiceBack.total, invoice.total);
      expect(invoiceBack.balance, invoice.balance);
      expect(invoiceBack.displayStatus, invoice.displayStatus);

      final checklist = MockChecklists.all().first;
      final checklistBack = Codecs.projectChecklist.fromRow(viaWire(Codecs.projectChecklist.toRow(checklist)));
      expect(checklistBack.progress, checklist.progress);
      expect(checklistBack.allItems.length, checklist.allItems.length);
      expect(checklistBack.allItems.expand((i) => i.evidence).length, checklist.allItems.expand((i) => i.evidence).length);
    });

    test('an unknown value written by a newer app version does not crash an older one', () {
      final row = viaWire(Codecs.lead.toRow(MockCrm.leads().first))
        ..['status'] = 'some_future_status'
        ..['source'] = 'carrier_pigeon';
      final lead = Codecs.lead.fromRow(row);
      expect(lead.status.name, 'newLead');
      expect(lead.source.name, 'other');
    });

    test('money stays exact through numeric columns', () {
      final expense = MockBusiness.expenses().first.copyWith(amount: 1234.56);
      final back = Codecs.expense.fromRow(viaWire(Codecs.expense.toRow(expense)));
      expect(back.amount, 1234.56);
      // The database may return whole numbers as ints.
      final asInt = viaWire(Codecs.expense.toRow(expense))..['amount'] = 1200;
      expect(Codecs.expense.fromRow(asInt).amount, 1200.0);
    });
  });

  group('the repository', () {
    late FakeGateway gateway;
    late SupabaseRepository<Task> repo;
    Task task(String id, String title) => Task(id: id, title: title, dueDate: DateTime(2030), createdAt: DateTime(2026));

    setUp(() {
      gateway = FakeGateway();
      repo = SupabaseRepository(gateway, Codecs.task);
    });

    test('load fills the local copy, and getAll answers instantly afterwards', () async {
      gateway.tables['tasks'] = [viaWire(Codecs.task.toRow(task('a', 'First'))), viaWire(Codecs.task.toRow(task('b', 'Second')))];
      expect(repo.getAll(), isEmpty, reason: 'nothing loaded yet');
      await repo.load();
      expect(repo.getAll().map((t) => t.id), ['a', 'b']);
      expect(gateway.calls.single, 'select tasks by updated_at limit null');
    });

    test('activity only loads the latest entries', () async {
      final activity = SupabaseRepository(gateway, Codecs.activity);
      await activity.load();
      expect(gateway.calls.single, 'select activity by at limit 200');
    });

    test('a saved record is in the database first, then in the local copy', () async {
      await repo.upsert(task('a', 'New'));
      expect(gateway.tables['tasks']!.single['title'], 'New');
      expect(repo.getAll().single.title, 'New');
      await repo.upsert(task('a', 'Edited'));
      expect(repo.getAll().single.title, 'Edited');
      expect(gateway.tables['tasks']!.length, 1, reason: 'updated, not duplicated');
    });

    test('a refused save leaves the local copy untouched and tells the caller why', () async {
      await repo.upsert(task('a', 'Keep me'));
      gateway.failNext = const RepositoryException('You are not allowed to do that.');
      await expectLater(repo.upsert(task('a', 'Rejected')), throwsA(isA<RepositoryException>()));
      expect(repo.getAll().single.title, 'Keep me', reason: 'the copy never claims more than the database has');
    });

    test('delete removes from both, and a failed delete keeps the record', () async {
      await repo.upsert(task('a', 'x'));
      gateway.failNext = const RepositoryException('offline', retryable: true);
      await expectLater(repo.delete('a'), throwsA(isA<RepositoryException>()));
      expect(repo.getAll().length, 1);
      await repo.delete('a');
      expect(repo.getAll(), isEmpty);
      expect(gateway.tables['tasks'], isEmpty);
    });
  });

  group('database errors become messages a person can act on', () {
    RepositoryException map(Object e) => mapSupabaseError(e);

    test('not allowed (row level security) is never retried', () {
      final e = map(const PostgrestException(message: 'new row violates row-level security policy', code: '42501'));
      expect(e.retryable, isFalse);
      expect(e.message, 'You are not allowed to do that.');
    });

    test('an expired session asks to sign in again, without retrying', () {
      expect(map(const AuthException('JWT expired')).message, contains('sign in again'));
      expect(map(const PostgrestException(message: 'JWT expired', code: 'PGRST301')).retryable, isFalse);
    });

    test('a duplicate number is explained', () {
      expect(map(const PostgrestException(message: 'duplicate key', code: '23505')).message, contains('already in use'));
    });

    test('server trouble and timeouts are retried; so is being offline', () {
      expect(map(const PostgrestException(message: 'unavailable', code: '503')).retryable, isTrue);
      expect(map(TimeoutException('slow')).retryable, isTrue);
      expect(map(const SocketException('no route')).retryable, isTrue);
      expect(map(const SocketException('no route')).message, contains('offline'));
    });

    test('a mistake in the query (unknown column) is permanent, not mistaken for server trouble', () {
      final e = map(const PostgrestException(message: 'column does not exist', code: '42703'));
      expect(e.retryable, isFalse);
      expect(e.message, isNot(contains('busy')));
    });

    test('an error that is already a RepositoryException passes through unchanged', () {
      const original = RepositoryException('x', retryable: true);
      expect(identical(map(original), original), isTrue);
    });
  });
}
