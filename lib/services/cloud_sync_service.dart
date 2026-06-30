import 'dart:convert';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import 'backup_crypto.dart';

/// Sync cloud — export chiffré partageable (Google Drive / iCloud via partage système).
/// Une intégration API directe pourra être ajoutée ultérieurement.
class CloudSyncService {
  CloudSyncService._();
  static final CloudSyncService instance = CloudSyncService._();

  final DatabaseService _db = DatabaseService();

  Future<void> exportToCloud() async {
    final data = await _db.exportAllData();
    final encrypted = BackupCrypto.encryptJson(data);
    final base64Data = base64Encode(encrypted);
    await Share.share(
      base64Data,
      subject: 'Budget Tracker — sauvegarde cloud',
    );
  }

  Future<String> getLastSyncHint() async {
    final data = await _db.exportAllData();
    final exportedAt = data['exported_at'] as String?;
    if (exportedAt == null) return 'Jamais synchronisé';
    return 'Dernière export : ${exportedAt.substring(0, 10)}';
  }
}
