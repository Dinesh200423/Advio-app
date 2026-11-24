import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/observability/app_log.dart';
import '../../data/backend/backend_config.dart';
import '../settings/settings_providers.dart';
import '../team/team_providers.dart';
import 'session_loader.dart';

class AuthState {
  const AuthState({this.loggedIn = false, this.onboarded = false});
  final bool loggedIn;
  final bool onboarded;

  AuthState copyWith({bool? loggedIn, bool? onboarded}) =>
      AuthState(loggedIn: loggedIn ?? this.loggedIn, onboarded: onboarded ?? this.onboarded);
}

/// Sign-in could not complete. [message] is safe to show.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Changing this throws away all app state and starts a fresh session (see AdvioRoot). Done on sign-out
/// so no client or finance data stays in memory for the next person to use the device.
final sessionReset = ValueNotifier<int>(0);

// Remembered between sessions in one run, so signing out does not replay the intro slides.
bool _introSeen = false;

/// Authentication. With Supabase configured this is real, invite-only sign-in; without it, a demo sign-in
/// that accepts anything so the sample-data app can be explored.
class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState(onboarded: _introSeen);

  void finishOnboarding() {
    if (BackendConfig.isConfigured) _introSeen = true;
    state = state.copyWith(onboarded: true);
  }

  /// Called at start-up. If a previous session is still valid, load its data and go straight in.
  Future<bool> restoreSession() async {
    if (!BackendConfig.isConfigured) return false;
    if (Supabase.instance.client.auth.currentSession == null) return false;
    try {
      await loadSession(ref);
      state = state.copyWith(loggedIn: true, onboarded: true);
      return true;
    } catch (error) {
      // An old or revoked session: fall back to the sign-in screen rather than showing an error at launch.
      AppLog.warning('Could not restore the previous session', error: error);
      return false;
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    if (!BackendConfig.isConfigured) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      final clean = email.trim().toLowerCase();
      for (final m in ref.read(teamProvider)) {
        if (clean.isNotEmpty && m.active && m.email.toLowerCase() == clean) ref.read(currentMemberIdProvider.notifier).switchTo(m.id);
      }
      state = state.copyWith(loggedIn: true, onboarded: true);
      return;
    }

    final auth = Supabase.instance.client.auth;
    try {
      await auth.signInWithPassword(email: email.trim(), password: password);
    } on AuthException catch (error) {
      AppLog.info('Sign-in refused', data: {'status': error.statusCode});
      throw AuthFailure(_friendly(error));
    } catch (error) {
      AppLog.warning('Sign-in could not reach the server', error: error);
      throw const AuthFailure('Could not reach ADVIO. Check your connection and try again.');
    }

    try {
      await loadSession(ref);
    } catch (error) {
      // Signed in, but unusable (not linked to a team member, or data would not load): do not leave a half session.
      await auth.signOut(scope: SignOutScope.local);
      rethrow;
    }
    _introSeen = true;
    state = state.copyWith(loggedIn: true, onboarded: true);
  }

  Future<void> signUp({required String name, required String email, required String password}) async {
    if (BackendConfig.isConfigured) {
      throw const AuthFailure('Accounts are created by the ADVIO founder. Ask them to add you.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(name: name, email: email));
    // A new account is a new team member, and the app acts as them.
    final memberId = ref.read(teamProvider.notifier).registerAccount(name: name, email: email);
    ref.read(currentMemberIdProvider.notifier).switchTo(memberId);
    state = state.copyWith(loggedIn: true, onboarded: true);
  }

  Future<void> signOut() async {
    if (!BackendConfig.isConfigured) {
      state = state.copyWith(loggedIn: false);
      return;
    }
    final auth = Supabase.instance.client.auth;
    try {
      await auth.signOut(); // also revokes the session on the server
    } catch (error) {
      AppLog.warning('Server sign-out failed; signing out on this device only', error: error);
      await auth.signOut(scope: SignOutScope.local);
    }
    sessionReset.value++;
  }

  String _friendly(AuthException error) {
    final text = error.message.toLowerCase();
    if (error.statusCode == '429' || text.contains('rate limit') || text.contains('too many')) {
      return 'Too many attempts. Wait a minute and try again.';
    }
    if (text.contains('invalid login') || text.contains('invalid credentials')) return 'Email or password is incorrect.';
    if (text.contains('not confirmed')) return 'This email address has not been confirmed yet.';
    return 'Could not sign in. Please try again.';
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
