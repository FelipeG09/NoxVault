import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço responsável por encapsular o acesso ao [FlutterSecureStorage].
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const String pinKey = 'noxvault_pin';
  static const String notesKey = 'noxvault_notes';

  Future<String?> readPin() => _storage.read(key: pinKey);

  Future<void> writePin(String pin) => _storage.write(key: pinKey, value: pin);

  Future<void> deletePin() => _storage.delete(key: pinKey);

  Future<String?> readNotes() => _storage.read(key: notesKey);

  Future<void> writeNotes(String notesJson) =>
      _storage.write(key: notesKey, value: notesJson);
}

