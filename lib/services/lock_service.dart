import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockService {
  LockService._internal();
  static final LockService instance = LockService._internal();

  static const _keyPinHash = 'lock_pin_hash';
  static const _keyLockEnabled = 'lock_enabled';
  static const _keyBiometricEnabled = 'lock_biometric';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isUnlocked = false;

  bool get isUnlocked => _isUnlocked;

  void markUnlocked() => _isUnlocked = true;

  void markLocked() => _isUnlocked = false;

  Future<bool> isLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyLockEnabled) ?? false;
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  Future<bool> hasPin() async {
    final hash = await _secureStorage.read(key: _keyPinHash);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> canUseBiometric() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _secureStorage.write(key: _keyPinHash, value: hash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, true);
    _isUnlocked = true;
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _secureStorage.read(key: _keyPinHash);
    if (stored == null) return false;
    return stored == _hashPin(pin);
  }

  Future<bool> authenticateWithBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Déverrouiller Budget Tracker',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException {
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, enabled);
  }

  Future<void> disableLock() async {
    await _secureStorage.delete(key: _keyPinHash);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLockEnabled, false);
    await prefs.setBool(_keyBiometricEnabled, false);
    _isUnlocked = true;
  }

  Future<bool> shouldShowLock() async {
    if (_isUnlocked) return false;
    final enabled = await isLockEnabled();
    if (!enabled) return false;
    return await hasPin();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode('budget_tracker_$pin');
    return sha256.convert(bytes).toString();
  }
}
