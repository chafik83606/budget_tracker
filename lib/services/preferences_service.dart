import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static final PreferencesService _instance = PreferencesService._internal();
  factory PreferencesService() => _instance;
  PreferencesService._internal();

  static const String _keyIsPro = 'is_pro';
  static const String _keyDarkTheme = 'dark_theme';
  static const String _keyAddCount = 'add_count';
  static const String _keyLastAutoBackupDate = 'last_auto_backup_date';
  static const String _keyOnboardingDone = 'onboarding_done';
  static const String _keyCurrentAccountId = 'current_account_id';
  static const String _keyBudgetAlerts = 'budget_alerts_enabled';
  static const String _keyAppLocale = 'app_locale';

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

  Future<bool> isOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingDone) ?? false;
  }

  Future<void> setOnboardingDone(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDone, value);
  }

  Future<int> getCurrentAccountId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentAccountId) ?? 1;
  }

  Future<void> setCurrentAccountId(int id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCurrentAccountId, id);
  }

  Future<bool> areBudgetAlertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBudgetAlerts) ?? true;
  }

  Future<void> setBudgetAlertsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBudgetAlerts, value);
  }

  Future<String> getAppLocaleCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAppLocale) ?? 'fr';
  }

  Future<void> setAppLocaleCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAppLocale, code);
  }
}
