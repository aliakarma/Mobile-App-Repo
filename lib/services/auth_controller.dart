import 'package:flutter/foundation.dart';

import '../models/auth_session_model.dart';
import 'auth_api_service.dart';
import 'auth_local_storage.dart';

enum AuthStatus {
  unknown,
  authenticated,
  unauthenticated,
}

class AuthController extends ChangeNotifier {
  AuthController({
    AuthApiService? apiService,
    AuthLocalStorage? localStorage,
  })  : _apiService = apiService ?? AuthApiService(),
        _localStorage = localStorage ?? AuthLocalStorage();

  final AuthApiService _apiService;
  final AuthLocalStorage _localStorage;

  AuthStatus _status = AuthStatus.unknown;
  AuthSessionModel? _session;

  AuthStatus get status => _status;
  AuthSessionModel? get session => _session;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> initialize() async {
    final storedSession = await _localStorage
        .loadSession()
        .timeout(const Duration(seconds: 2), onTimeout: () => null);
    if (storedSession == null || storedSession.isExpired) {
      await _localStorage.clearSession();
      _setUnauthenticated();
      notifyListeners();
      return;
    }

    try {
      final currentUser = await _apiService
        .fetchCurrentUser(storedSession.accessToken)
        .timeout(const Duration(seconds: 2));
      _session = storedSession.copyWith(user: currentUser);
      _status = AuthStatus.authenticated;
    } catch (_) {
      await _localStorage.clearSession();
      _setUnauthenticated();
      notifyListeners();
      return;
    }

    notifyListeners();
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final session = await _apiService.signUp(
      fullName: fullName,
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    await _setSession(session);
  }

  Future<void> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final session = await _apiService.login(
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
    await _setSession(session);
  }

  Future<void> logout() async {
    final activeSession = _session;
    if (activeSession != null) {
      try {
        await _apiService.logout(activeSession.accessToken);
      } catch (_) {
        // Local logout still proceeds even if backend logout fails.
      }
    }

    await _localStorage.clearSession();
    _setUnauthenticated();
    notifyListeners();
  }

  Future<void> _setSession(AuthSessionModel session) async {
    _session = session;
    _status = AuthStatus.authenticated;
    await _localStorage.saveSession(session);
    notifyListeners();
  }

  void _setUnauthenticated() {
    _session = null;
    _status = AuthStatus.unauthenticated;
  }
}
