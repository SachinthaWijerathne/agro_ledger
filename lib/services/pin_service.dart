// lib/services/pin_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class PinService {
  static final PinService _instance = PinService._internal();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  PinService._internal();
  
  factory PinService() => _instance;
  
  Future<bool> isPinSetup() async {
    final pin = await _storage.read(key: AppConstants.prefKeyPinHash);
    return pin != null && pin.isNotEmpty;
  }
  
  Future<void> setupPin(String pin) async {
    final hashedPin = Helpers.hashPin(pin);
    await _storage.write(key: AppConstants.prefKeyPinHash, value: hashedPin);
    await _storage.write(key: AppConstants.prefKeyPinEnabled, value: 'true');
  }
  
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: AppConstants.prefKeyPinHash);
    if (storedHash == null) return false;
    return Helpers.verifyPin(pin, storedHash);
  }
  
  Future<void> changePin(String oldPin, String newPin) async {
    if (await verifyPin(oldPin)) {
      await setupPin(newPin);
    } else {
      throw Exception('Invalid current PIN');
    }
  }
  
  Future<void> clearPin() async {
    await _storage.delete(key: AppConstants.prefKeyPinHash);
    await _storage.delete(key: AppConstants.prefKeyPinEnabled);
  }
}