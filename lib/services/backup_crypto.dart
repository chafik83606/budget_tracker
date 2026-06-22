import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;

class BackupCrypto {
  static const String _encryptionKey = 'BudgetTracker2024SecureKey123456';
  static const String _encryptionIV = 'BudgetTrackerIV1';

  static List<int> encryptJson(Map<String, dynamic> data) {
    final jsonStr = jsonEncode(data);
    final key = enc.Key.fromUtf8(_encryptionKey);
    final iv = enc.IV.fromUtf8(_encryptionIV);
    final encrypter = enc.Encrypter(enc.AES(key));
    return encrypter.encrypt(jsonStr, iv: iv).bytes;
  }

  static Map<String, dynamic> decryptToMap(List<int> bytes) {
    final key = enc.Key.fromUtf8(_encryptionKey);
    final iv = enc.IV.fromUtf8(_encryptionIV);
    final encrypter = enc.Encrypter(enc.AES(key));
    final decrypted = encrypter.decrypt(
      enc.Encrypted(Uint8List.fromList(bytes)),
      iv: iv,
    );
    return jsonDecode(decrypted) as Map<String, dynamic>;
  }
}
