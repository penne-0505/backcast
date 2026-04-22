import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

/// Application-level authentication state.
/// Wraps the Supabase [supabase.User] to expose a stable, app-specific API.
@immutable
class AppAuthState {
  const AppAuthState({this.user});

  final supabase.User? user;

  bool get isAuthenticated => user != null;

  /// Supabase user UUID, or null when not authenticated.
  String? get userId => user?.id;

  /// Display-friendly identifier (email or provider-specific).
  String? get displayIdentifier =>
      user?.email ?? user?.userMetadata?['name']?.toString();

  AppAuthState copyWith({supabase.User? user}) =>
      AppAuthState(user: user ?? this.user);
}

/// Notifier that keeps the auth state in sync with Supabase
/// and exposes sign-in / sign-out operations.
class AuthNotifier extends AsyncNotifier<AppAuthState> {
  @override
  Future<AppAuthState> build() async {
    final client = supabase.Supabase.instance.client;

    // Seed with the current session (may be null).
    final initialSession = client.auth.currentSession;
    var currentState = AppAuthState(user: initialSession?.user);

    // Listen to Supabase auth events for the lifetime of this provider.
    final subscription = client.auth.onAuthStateChange.listen((event) {
      final newUser = event.session?.user;
      if (newUser != currentState.user) {
        currentState = AppAuthState(user: newUser);
        state = AsyncValue.data(currentState);
      }
    });

    ref.onDispose(() => subscription.cancel());

    return currentState;
  }

  /// Sign in with Google via OAuth.
  /// The deep-link callback is handled automatically by supabase_flutter.
  Future<void> signInWithGoogle() async {
    try {
      final success =
          await supabase.Supabase.instance.client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: 'dev.otibo.ato://callback',
      );
      if (!success) {
        throw Exception('Google sign-in was not initiated successfully.');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sign in with Apple via OAuth (iOS / macOS only).
  Future<void> signInWithApple() async {
    if (!Platform.isIOS && !Platform.isMacOS) {
      throw UnsupportedError(
        'Sign in with Apple is only available on iOS and macOS.',
      );
    }
    try {
      final success =
          await supabase.Supabase.instance.client.auth.signInWithOAuth(
        supabase.OAuthProvider.apple,
        redirectTo: 'dev.otibo.ato://callback',
      );
      if (!success) {
        throw Exception('Apple sign-in was not initiated successfully.');
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    try {
      await supabase.Supabase.instance.client.auth.signOut();
      // The onAuthStateChange listener will update [state] automatically.
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// Global provider for authentication state.
final authProvider = AsyncNotifierProvider<AuthNotifier, AppAuthState>(
  AuthNotifier.new,
);

/// Derives the current Supabase user UUID, or null when unauthenticated.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).whenOrNull(data: (d) => d.userId);
});

/// Derives whether the user is currently authenticated.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).whenOrNull(data: (d) => d.isAuthenticated) ??
      false;
});
