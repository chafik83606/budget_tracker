import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _keyIsPro = 'is_pro';
  static const String _keyDarkTheme = 'dark_theme';
  static const String _keyAddCount = 'add_count';
  static const String _keyLastAutoBackupDate = 'last_auto_backup_date';

  // ─── STATUT PRO ──────────────────────────────────────────────────────────

  Future<bool> isPro() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsPro) ?? false;
  }

  Future<void> setPro(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsPro, value);
  }

  // ─── THÈME ───────────────────────────────────────────────────────────────

  Future<bool> isDarkTheme() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyDarkTheme) ?? false;
  }

  Future<void> setDarkTheme(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkTheme, value);
  }

  // ─── COMPTEUR AJOUTS (pour interstitielle) ────────────────────────────────

  Future<int> getAddCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyAddCount) ?? 0;
  }

  Future<int> incrementAddCount() async {
    final prefs = await SharedPreferences.getInstance();
    final count = (prefs.getInt(_keyAddCount) ?? 0) + 1;
    await prefs.setInt(_keyAddCount, count);
    return count;
  }

  Future<void> resetAddCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyAddCount, 0);
  }

  // ─── SAUVEGARDE AUTO ─────────────────────────────────────────────────────

  Future<String?> getLastAutoBackupDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastAutoBackupDate);
  }

  Future<void> setLastAutoBackupDate(String dateKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastAutoBackupDate, dateKey);
  }
}
