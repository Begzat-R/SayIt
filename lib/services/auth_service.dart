import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

final authStateProvider = StreamProvider<AuthState>((ref) {
  return _supabase.auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  ref.watch(authStateProvider);
  return _supabase.auth.currentUser;
});

class AuthFormState {
  final bool isLoading;
  final String? emailError;
  final String? passwordError;
  final String? generalError;

  const AuthFormState({
    this.isLoading = false,
    this.emailError,
    this.passwordError,
    this.generalError,
  });

  bool get hasError =>
      emailError != null || passwordError != null || generalError != null;
}

class AuthNotifier extends StateNotifier<AuthFormState> {
  late final StreamSubscription<AuthState> _authSub;

  AuthNotifier() : super(const AuthFormState()) {
    _authSub = _supabase.auth.onAuthStateChange.listen((event) {
      if (event.event == AuthChangeEvent.signedIn) {
        _syncProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    if (!_validEmail(email)) {
      state = const AuthFormState(emailError: 'Enter a valid email address.');
      return;
    }
    if (password.isEmpty) {
      state = const AuthFormState(passwordError: 'Enter your password.');
      return;
    }
    state = const AuthFormState(isLoading: true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      state = const AuthFormState();
    } on AuthException catch (e) {
      state = _parseError(e);
    } catch (_) {
      state = const AuthFormState(
          generalError: 'Something went wrong. Please try again.');
    }
  }

  Future<void> signUp(String email, String password) async {
    if (!_validEmail(email)) {
      state = const AuthFormState(emailError: 'Enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      state = const AuthFormState(
          passwordError: 'Password must be at least 6 characters.');
      return;
    }
    state = const AuthFormState(isLoading: true);
    try {
      await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );
      state = const AuthFormState();
    } on AuthException catch (e) {
      state = _parseError(e);
    } catch (_) {
      state = const AuthFormState(
          generalError: 'Something went wrong. Please try again.');
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AuthFormState(isLoading: true);
    try {
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.opwcsijnfypcmgqjobuf://login-callback/',
      );
      // Browser launched — auth completes via deep link callback
      state = const AuthFormState();
    } catch (_) {
      state = const AuthFormState(
          generalError: 'Could not open Google sign-in. Please try again.');
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const AuthFormState();
  }

  void clearErrors() {
    if (state.hasError) state = AuthFormState(isLoading: state.isLoading);
  }

  bool _validEmail(String email) {
    final e = email.trim();
    return e.isNotEmpty && e.contains('@') && e.contains('.');
  }

  AuthFormState _parseError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password') ||
        msg.contains('email not confirmed')) {
      return const AuthFormState(generalError: 'Incorrect email or password.');
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return const AuthFormState(
          emailError:
              'An account with this email already exists. Try signing in.');
    }
    if (msg.contains('password') &&
        (msg.contains('short') ||
            msg.contains('characters') ||
            msg.contains('least 6'))) {
      return const AuthFormState(
          passwordError: 'Password must be at least 6 characters.');
    }
    if (msg.contains('email') &&
        (msg.contains('invalid') || msg.contains('format'))) {
      return const AuthFormState(emailError: 'Enter a valid email address.');
    }
    return AuthFormState(generalError: e.message);
  }

  Future<void> _syncProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String? displayName;
    final googleName = (user.userMetadata?['full_name'] as String? ??
            user.userMetadata?['name'] as String?)
        ?.trim();
    if (googleName != null && googleName.isNotEmpty) {
      displayName = googleName;
    } else {
      final prefs = await SharedPreferences.getInstance();
      final stored = (prefs.getString('user_name') ?? '').trim();
      if (stored.isNotEmpty) {
        displayName = stored;
      } else {
        final email = user.email ?? '';
        final prefix =
            email.contains('@') ? email.split('@').first : email;
        if (prefix.isNotEmpty) displayName = prefix;
      }
    }

    final data = <String, dynamic>{'id': user.id};
    if (displayName != null) data['display_name'] = displayName;
    await _supabase.from('profiles').upsert(data, onConflict: 'id');
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthFormState>((ref) {
  return AuthNotifier();
});
