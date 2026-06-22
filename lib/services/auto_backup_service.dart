import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'backup_crypto.dart';
import 'database_service.dart';
import 'preferences_service.dart';

class AutoBackupStatus {
  final DateTime? lastBackupDate;
  final bool hasTodayFile;
  final bool hasYesterdayFile;

  const AutoBackupStatus({
    this.lastBackupDate,
    required this.hasTodayFile,
    required this.hasYesterdayFile,
  });
}

class AutoBackupService {
  static final AutoBackupService instance = AutoBackupService._();
  AutoBackupService._();

  static const String todayFileName = 'budget_backup_today.btk';
  static const String yesterdayFileName = 'budget_backup_yesterday.btk';

  final DatabaseService _db = DatabaseService();
  final PreferencesService _prefs = PreferencesService();

  Future<Directory> _backupDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/auto_backups');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _todayFile() async =>
      File('${(await _backupDir()).path}/$todayFileName');

  Future<File> _yesterdayFile() async =>
      File('${(await _backupDir()).path}/$yesterdayFileName');

  String _dateKey(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Sauvegarde au plus une fois par jour. Conserve exactement 2 fichiers :
  /// aujourd'hui et hier (l'ancien « aujourd'hui » devient « hier »).
  Future<void> runDailyBackupIfNeeded() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayKey = _dateKey(today);

    final lastKey = await _prefs.getLastAutoBackupDate();
    if (lastKey == todayKey) return;

    final data = await _db.exportAllData();
    final encrypted = BackupCrypto.encryptJson(data);

    final todayFile = await _todayFile();
    final yesterdayFile = await _yesterdayFile();

    if (await todayFile.exists()) {
      await todayFile.copy(yesterdayFile.path);
    }

    await todayFile.writeAsBytes(encrypted);
    await _prefs.setLastAutoBackupDate(todayKey);
    await _removeExtraFiles();
  }

  Future<void> _removeExtraFiles() async {
    final dir = await _backupDir();
    await for (final entity in dir.list()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (name != todayFileName && name != yesterdayFileName) {
        await entity.delete();
      }
    }
  }

  Future<AutoBackupStatus> getStatus() async {
    final lastKey = await _prefs.getLastAutoBackupDate();
    DateTime? lastDate;
    if (lastKey != null) {
      final parts = lastKey.split('-');
      if (parts.length == 3) {
        lastDate = DateTime.tryParse(lastKey);
      }
    }

    return AutoBackupStatus(
      lastBackupDate: lastDate,
      hasTodayFile: await (await _todayFile()).exists(),
      hasYesterdayFile: await (await _yesterdayFile()).exists(),
    );
  }

  /// Restaure depuis la sauvegarde la plus récente si la base est vide.
  Future<bool> tryRestoreLatestIfEmpty() async {
    final count = await _db.getTransactionCount();
    if (count > 0) return false;

    final today = await _todayFile();
    if (await today.exists()) {
      return restoreFromFile(today);
    }

    final yesterday = await _yesterdayFile();
    if (await yesterday.exists()) {
      return restoreFromFile(yesterday);
    }

    return false;
  }

  Future<bool> restoreToday() async {
    return restoreFromFile(await _todayFile());
  }

  Future<bool> restoreYesterday() async {
    return restoreFromFile(await _yesterdayFile());
  }

  Future<bool> restoreFromFile(File file) async {
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    final data = BackupCrypto.decryptToMap(bytes);
    await _db.importAllData(data);
    return true;
  }
}
