import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Serviço responsável por encapsular o acesso ao [FlutterSecureStorage].
///
/// SEGURANÇA:
/// - O PIN é armazenado como "base64(salt):base64(pbkdf2_hash)" — nunca em texto puro.
/// - As notas são armazenadas como "base64(iv):base64(aes256gcm_ciphertext)".
/// - A chave AES é derivada do PIN em tempo de execução e nunca persistida.
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  // Chaves do keystore
  static const String pinHashKey        = 'noxvault_pin_hash';
  static const String notesKey          = 'noxvault_notes_enc';
  static const String pinLockoutKey     = 'noxvault_pin_lockout_until_ms';
  static const String pinFailCountKey   = 'noxvault_pin_fail_count';

  // ── PIN hash ──────────────────────────────────────────────────────────────

  /// Lê o hash PBKDF2 do PIN (formato "salt:hash" em base64).
  /// Retorna `null` se nenhum PIN foi criado ainda.
  Future<String?> readPinHash() => _storage.read(key: pinHashKey);

  /// Grava o hash PBKDF2 do PIN.
  Future<void> writePinHash(String hash) =>
      _storage.write(key: pinHashKey, value: hash);

  /// Remove o hash do PIN (reset de fábrica / testes).
  Future<void> deletePinHash() => _storage.delete(key: pinHashKey);

  // ── Notas cifradas ────────────────────────────────────────────────────────

  /// Lê as notas cifradas em AES-256-GCM.
  Future<String?> readEncryptedNotes() => _storage.read(key: notesKey);

  /// Grava as notas cifradas.
  Future<void> writeEncryptedNotes(String encryptedJson) =>
      _storage.write(key: notesKey, value: encryptedJson);

  // ── Bloqueio de PIN ───────────────────────────────────────────────────────

  Future<int?> readPinLockoutUntilMs() async {
    final s = await _storage.read(key: pinLockoutKey);
    return s == null ? null : int.tryParse(s);
  }

  Future<void> writePinLockoutUntilMs(int? ms) async {
    if (ms == null) {
      await _storage.delete(key: pinLockoutKey);
    } else {
      await _storage.write(key: pinLockoutKey, value: '$ms');
    }
  }

  Future<int> readPinFailCount() async {
    final s = await _storage.read(key: pinFailCountKey);
    return int.tryParse(s ?? '') ?? 0;
  }

  Future<void> writePinFailCount(int count) =>
      _storage.write(key: pinFailCountKey, value: '$count');
}
