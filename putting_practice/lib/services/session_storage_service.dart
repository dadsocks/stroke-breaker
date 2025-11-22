import 'package:shared_preferences/shared_preferences.dart';

import '../models/putting_session.dart';

class SessionStorageService {
  const SessionStorageService({SharedPreferences? prefs}) : _prefs = prefs;

  final SharedPreferences? _prefs;

  static const _sessionKey = 'putting_practice_active_session';

  Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  Future<void> saveSession(PuttingSession session) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(_sessionKey, session.toJson());
  }

  Future<PuttingSession?> loadSession() async {
    final prefs = await _ensurePrefs();
    final json = prefs.getString(_sessionKey);
    if (json == null) return null;
    return PuttingSession.fromJson(json);
  }

  Future<void> clearSession() async {
    final prefs = await _ensurePrefs();
    await prefs.remove(_sessionKey);
  }
}
