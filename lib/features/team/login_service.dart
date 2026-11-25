import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/observability/app_log.dart';

/// Something went wrong creating a login. [message] is safe to show.
class LoginFailure implements Exception {
  const LoginFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Creates a login for a team member, or resets the password of the one they have. Returns true when a new
/// login was made, false when an existing one was reset. A provider so tests can replace it.
///
/// This calls the "create-login" function on Supabase, which checks the caller is the founder and holds the
/// admin key that the app must never have.
typedef LoginCreator = Future<bool> Function({required String memberId, required String password});

final loginCreatorProvider = Provider<LoginCreator>((ref) {
  return ({required memberId, required password}) async {
    try {
      final response = await Supabase.instance.client.functions.invoke('create-login', body: {'memberId': memberId, 'password': password});
      final data = response.data;
      return data is Map && data['created'] == true;
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map ? details['error'] : null;
      AppLog.info('Create login refused', data: {'status': error.status});
      throw LoginFailure(message is String && message.isNotEmpty ? message : 'Could not create the login.');
    } catch (error) {
      AppLog.warning('Create login could not reach the server', error: error);
      throw const LoginFailure('Could not reach ADVIO. Check your connection and try again.');
    }
  };
});

/// A temporary password that is easy to read out or type: no look-alike characters (0/O, 1/l/I),
/// and always at least one capital, one small letter and one digit.
String generatePassword({Random? random, int length = 12}) {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnpqrstuvwxyz';
  const digits = '23456789';
  final rng = random ?? Random.secure();
  String pick(String from) => from[rng.nextInt(from.length)];
  final chars = [pick(upper), pick(lower), pick(digits), for (var i = 3; i < length; i++) pick(upper + lower + digits)]..shuffle(rng);
  return chars.join();
}
