import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/backend/row_codecs.dart';
import 'package:freelance_os/data/backend/row_gateway.dart';
import 'package:freelance_os/data/backend/supabase_repository.dart';
import 'package:freelance_os/data/models/enums.dart';
import 'package:freelance_os/data/models/lead.dart';
import 'package:freelance_os/data/repositories/repositories.dart';
import 'package:freelance_os/data/repositories/save_failures.dart';
import 'package:freelance_os/features/auth/session_loader.dart';
import 'package:freelance_os/features/leads/lead_providers.dart';

Map<String, dynamic> wire(Map<String, Object?> row) => jsonDecode(jsonEncode(row)) as Map<String, dynamic>;

Lead lead(String id, String name) => Lead(
      id: id,
      name: name,
      company: '',
      email: '',
      phone: '',
      source: LeadSource.website,
      status: LeadStatus.newLead,
      createdAt: DateTime(2026, 11, 25),
    );

/// A database with a few switches for what goes wrong and when.
class SlowGateway implements RowGateway {
  final rows = <Map<String, dynamic>>[];
  Completer<void>? holdSaves;
  bool failReads = false;

  @override
  Future<List<Map<String, dynamic>>> select(String table, {String orderBy = 'updated_at', bool ascending = false, int? limit}) async {
    if (failReads) throw const RepositoryException('You appear to be offline.', retryable: true);
    return table == 'leads' ? [...rows] : [];
  }

  @override
  Future<void> upsert(String table, Map<String, Object?> row) async {
    await holdSaves?.future;
    if (table == 'leads') rows.add(wire(row));
  }

  @override
  Future<void> delete(String table, String id) async {}
}

void main() {
  late SlowGateway db;
  late SupabaseRepository<Lead> repo;
  late ProviderContainer container;

  setUp(() async {
    db = SlowGateway();
    repo = SupabaseRepository(db, Codecs.lead);
    container = ProviderContainer(overrides: [
      leadRepositoryProvider.overrideWithValue(repo),
      backendRepositoriesProvider.overrideWithValue([repo]),
      retryPolicyProvider.overrideWithValue(RetryPolicy.immediate),
    ]);
    addTearDown(container.dispose);
    await repo.load();
  });

  Future<void> refresh() => container.read(dataRefreshProvider)();

  test('a lead added by someone else (or the website form) appears after a refresh', () async {
    expect(container.read(leadsProvider), isEmpty);
    db.rows.add(wire(Codecs.lead.toRow(lead('lead_web_1', 'Neha Verma'))));

    await refresh();

    expect(container.read(leadsProvider).map((l) => l.name), ['Neha Verma']);
  });

  test('a save still on its way finishes first, so a refresh never hides it', () async {
    db.holdSaves = Completer<void>();
    container.read(leadsProvider.notifier).upsert(lead('mine', 'Just added'));
    expect(container.read(leadsProvider), hasLength(1), reason: 'shown at once');

    final refreshing = refresh();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    db.holdSaves!.complete();
    await refreshing;

    expect(container.read(leadsProvider).map((l) => l.name), ['Just added']);
    expect(db.rows, hasLength(1));
  });

  test('when the database cannot be reached, the refresh says so and the lists stay as they were', () async {
    container.read(leadsProvider.notifier).upsert(lead('a', 'Existing'));
    await container.read(leadsProvider.notifier).flush();
    db.failReads = true;

    await expectLater(refresh(), throwsA(isA<RepositoryException>().having((e) => e.retryable, 'retryable', isTrue)));

    expect(container.read(leadsProvider).map((l) => l.name), ['Existing']);
  });

  test('on sample data a refresh just completes', () async {
    final sample = ProviderContainer();
    addTearDown(sample.dispose);
    await sample.read(dataRefreshProvider)();
  });
}
