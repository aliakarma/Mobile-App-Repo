import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session_model.dart';

class AuthLocalStorage {
  static const String _sessionKey = 'auth_session';

  AuthLocalStorage({FlutterSecureStorage? secureStorage})
      : _secureStorage =
            secureStorage ??
                const FlutterSecureStorage(
                  aOptions: AndroidOptions(encryptedSharedPreferences: true),
                );

  final FlutterSecureStorage _secureStorage;

  Future<void> saveSession(AuthSessionModel session) async {
    final raw = jsonEncode(session.toJson());
    try {
      await _secureStorage.write(key: _sessionKey, value: raw);
      return;
    } on MissingPluginException {
      // Fallback is used by unsupported platforms and widget tests.
    } on PlatformException {
      // Fallback is used by unsupported platforms and widget tests.
    } catch (_) {
      // Fallback is used by unsupported platforms and widget tests.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_sessionKey, raw);
  }

  Future<AuthSessionModel?> loadSession() async {
    String? raw;
    try {
      raw = await _secureStorage.read(key: _sessionKey);
    } on MissingPluginException {
      // Fallback is used by unsupported platforms and widget tests.
    } on PlatformException {
      // Fallback is used by unsupported platforms and widget tests.
    } catch (_) {
      // Fallback is used by unsupported platforms and widget tests.
    }

    if (raw == null || raw.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      raw = prefs.getString(_sessionKey);
    }

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AuthSessionModel.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      await _secureStorage.delete(key: _sessionKey);
    } on MissingPluginException {
      // Fallback is used by unsupported platforms and widget tests.
    } on PlatformException {
      // Fallback is used by unsupported platforms and widget tests.
    } catch (_) {
      // Fallback is used by unsupported platforms and widget tests.
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}
