import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart';

/// Serviço de criptografia do NoxVault.
///
/// PIN: PBKDF2-SHA256 com salt aleatório de 32 bytes e 200 000 iterações.
///      Armazenado como "base64(salt):base64(hash)".
///
/// Notas: AES-256-GCM com IV aleatório de 16 bytes por operação.
///        Armazenado como "base64(iv):base64(ciphertext)".
///        A chave AES é derivada do PIN via PBKDF2 (32 bytes).
class CryptoService {
  static const int _pbkdf2Iterations = 200000;
  static const int _saltLength = 32;
  static const int _keyLength = 32; // 256 bits
  static const int _ivLength = 16; // 128 bits

  // ── PIN hash ──────────────────────────────────────────────────────────────

  /// Gera um salt aleatório seguro e retorna "base64(salt):base64(hash)".
  String hashPin(String pin) {
    final salt = _randomBytes(_saltLength);
    final hash = _pbkdf2(pin, salt);
    return '${base64.encode(salt)}:${base64.encode(hash)}';
  }

  /// Verifica se [pin] corresponde ao [stored] gerado por [hashPin].
  bool verifyPin(String pin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) return false;
    final salt = base64.decode(parts[0]);
    final expected = base64.decode(parts[1]);
    final actual = _pbkdf2(pin, salt);
    // Comparação em tempo constante para evitar timing attacks
    return _constantTimeEquals(actual, expected);
  }

  // ── Derivação de chave AES a partir do PIN ────────────────────────────────

  /// Deriva uma chave AES-256 a partir do PIN e do salt já armazenado.
  /// O salt é extraído do campo "base64(salt):..." do hash guardado no storage.
  Uint8List deriveKey(String pin, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 2) throw StateError('Hash de PIN inválido.');
    final salt = base64.decode(parts[0]);
    return _pbkdf2(pin, salt, length: _keyLength);
  }

  // ── Criptografia AES-256-GCM das notas ───────────────────────────────────

  /// Cifra [plaintext] com AES-256-GCM usando [key] derivada do PIN.
  /// Retorna "base64(iv):base64(ciphertext+tag)".
  String encryptNotes(String plaintext, Uint8List key) {
    final iv = enc.IV(_randomBytes(_ivLength));
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    return '${base64.encode(iv.bytes)}:${encrypted.base64}';
  }

  /// Decifra [ciphertext] no formato "base64(iv):base64(ciphertext+tag)".
  String decryptNotes(String ciphertext, Uint8List key) {
    final parts = ciphertext.split(':');
    if (parts.length != 2) throw FormatException('Formato de notas inválido.');
    final iv = enc.IV(base64.decode(parts[0]));
    final encrypted = enc.Encrypted.fromBase64(parts[1]);
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );
    return encrypter.decrypt(encrypted, iv: iv);
  }

  // ── Utilitários ───────────────────────────────────────────────────────────

  Uint8List _pbkdf2(String password, Uint8List salt, {int? length}) {
    final keyLen = length ?? _keyLength;
    final params = Pbkdf2Parameters(salt, _pbkdf2Iterations, keyLen);
    final mac = HMac(SHA256Digest(), 64);
    final kdf = PBKDF2KeyDerivator(mac)..init(params);
    return kdf.process(Uint8List.fromList(utf8.encode(password)));
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }

  bool _constantTimeEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
