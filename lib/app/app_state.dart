import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AiProvider { gemini, openrouter, groq }

extension AiProviderLabel on AiProvider {
  String get label {
    switch (this) {
      case AiProvider.gemini:
        return 'Gemini';
      case AiProvider.openrouter:
        return 'OpenRouter 👑';
      case AiProvider.groq:
        return 'Groq';
    }
  }

  String get providerKey {
    switch (this) {
      case AiProvider.gemini:
        return 'google';
      case AiProvider.openrouter:
        return 'openrouter';
      case AiProvider.groq:
        return 'groq';
    }
  }
}

class SessionState {
  const SessionState({this.email});

  final String? email;

  bool get isAuthenticated => email != null && email!.isNotEmpty;
}

class AppState extends ChangeNotifier {
  AppState(SupabaseClient client) : _client = client {
    _authSubscription = _client.auth.onAuthStateChange.listen(
      _onAuthStateChange,
    );
  }

  final SupabaseClient _client;
  late final StreamSubscription<AuthState> _authSubscription;

  AiProvider _selectedProvider = AiProvider.gemini;
  SessionState _session = const SessionState();

  AiProvider get selectedProvider => _selectedProvider;
  SessionState get session => _session;

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  void selectProvider(AiProvider provider) {
    if (_selectedProvider == provider) return;
    _selectedProvider = provider;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> _onAuthStateChange(AuthState data) async {
    switch (data.event) {
      case AuthChangeEvent.initialSession:
      case AuthChangeEvent.signedIn:
        final userId = data.session?.user.id;
        if (userId != null) await _loadProfile(userId);
      case AuthChangeEvent.signedOut:
        _session = const SessionState();
        notifyListeners();
      default:
        break;
    }
  }

  Future<void> _loadProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select('email')
          .eq('id', userId)
          .single();
      _session = SessionState(email: data['email'] as String?);
    } catch (_) {
      _session = const SessionState();
    }
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    required super.notifier,
    required super.child,
    super.key,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found in context');
    return scope!.notifier!;
  }
}
