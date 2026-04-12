import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço responsável por encapsular o acesso ao [FlutterSecureStorage].
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const String pinKey = 'noxvault_pin';
  static const String notesKey = 'noxvault_notes';
  static const String pinLockoutUntilMsKey = 'noxvault_pin_lockout_until_ms';
  static const String pinFailCountKey = 'noxvault_pin_fail_count';

  Future<String?> readPin() => _storage.read(key: pinKey);

  Future<void> writePin(String pin) => _storage.write(key: pinKey, value: pin);

  Future<void> deletePin() => _storage.delete(key: pinKey);

  Future<String?> readNotes() => _storage.read(key: notesKey);

  Future<void> writeNotes(String notesJson) =>
      _storage.write(key: notesKey, value: notesJson);

  Future<int?> readPinLockoutUntilMs() async {
    final s = await _storage.read(key: pinLockoutUntilMsKey);
    if (s == null) return null;
    return int.tryParse(s);
  }

  Future<void> writePinLockoutUntilMs(int? millisSinceEpoch) async {
    if (millisSinceEpoch == null) {
      await _storage.delete(key: pinLockoutUntilMsKey);
    } else {
      await _storage.write(key: pinLockoutUntilMsKey, value: '$millisSinceEpoch');
    }
  }

  Future<int> readPinFailCount() async {
    final s = await _storage.read(key: pinFailCountKey);
    if (s == null) return 0;
    return int.tryParse(s) ?? 0;
  }

  Future<void> writePinFailCount(int count) =>
      _storage.write(key: pinFailCountKey, value: '$count');
}

