// Checks against the real Supabase project named in env.json. Skipped when env.json is absent,
// so it never blocks anyone who has not set up the backend.
//
// Nothing here needs a login, and nothing here can change data: the writes it attempts are
// supposed to be refused, and that is exactly what is being checked.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:freelance_os/data/backend/row_codecs.dart';
import 'package:freelance_os/data/backend/row_gateway.dart';
import 'package:freelance_os/data/repositories/save_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final envFile = File('env.json');
  final config = envFile.existsSync() ? jsonDecode(envFile.readAsStringSync()) as Map<String, dynamic> : null;
  final skip = config == null ? 'env.json not found' : null;

  late SupabaseClient client;
  late SupabaseGateway gateway;

  setUpAll(() {
    if (config == null) return;
    HttpOverrides.global = null; // flutter_test blocks real network by default
    client = SupabaseClient(config['SUPABASE_URL'] as String, config['SUPABASE_ANON_KEY'] as String);
    gateway = SupabaseGateway(client);
  });

  tearDownAll(() {
    if (config != null) client.dispose();
  });

  test('a stranger cannot read any table, and gets a clear, non-retryable refusal', () async {
    // Ask exactly as the app does: each table with its own sort column and row limit.
    for (final codec in Codecs.all) {
      await expectLater(
        gateway.select(codec.table, orderBy: codec.orderBy, limit: codec.limit),
        throwsA(isA<RepositoryException>()
            .having((e) => e.message, 'message', 'You are not allowed to do that.')
            .having((e) => e.retryable, 'retryable', isFalse)),
        reason: codec.table,
      );
    }
  }, skip: skip, timeout: const Timeout(Duration(seconds: 90)));

  test('a stranger cannot write', () async {
    await expectLater(
      gateway.upsert('tasks', {'id': 'live_test_should_be_refused', 'title': 'x', 'due_date': DateTime.now().toUtc().toIso8601String()}),
      throwsA(isA<RepositoryException>().having((e) => e.message, 'message', 'You are not allowed to do that.')),
    );
    await expectLater(gateway.delete('tasks', 'live_test_should_be_refused'), throwsA(isA<RepositoryException>()));
  }, skip: skip);

  test('a wrong password is refused by the auth server', () async {
    await expectLater(
      client.auth.signInWithPassword(email: 'nobody-here@example.invalid', password: 'not-a-real-password-123'),
      throwsA(isA<AuthException>().having((e) => e.message.toLowerCase(), 'message', contains('invalid'))),
    );
  }, skip: skip);

  test('public sign-up is switched off', () async {
    // Accounts are invite-only. If this fails, turn off "Allow new users to sign up" in Supabase > Authentication.
    final response = await HttpClient().getUrl(Uri.parse('${config!['SUPABASE_URL']}/auth/v1/settings')).then((r) {
      r.headers.set('apikey', config['SUPABASE_ANON_KEY'] as String);
      return r.close();
    });
    final settings = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
    expect(settings['disable_signup'], isTrue, reason: 'sign-ups are still open');
  }, skip: skip);
}
