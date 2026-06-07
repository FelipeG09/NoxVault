import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/crypto_service.dart';
import '../services/secure_storage_service.dart';

/// Provider responsável por gerenciar as notas do cofre.
///
/// SEGURANÇA:
/// - As notas são cifradas com AES-256-GCM usando a chave derivada do PIN.
/// - O método [loadNotes] exige a [vaultKey] — nunca carrega sem autenticação.
/// - O método [reEncryptWithNewKey] é usado ao trocar o PIN.
class VaultProvider extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();
  final CryptoService _crypto = CryptoService();

  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  // ── Carregamento ──────────────────────────────────────────────────────────

  /// Carrega e decifra as notas usando [vaultKey] derivada do PIN.
  /// Deve ser chamado somente após autenticação bem-sucedida.
  Future<void> loadNotes(Uint8List vaultKey) async {
    try {
      final encrypted = await _storage.readEncryptedNotes();
      if (encrypted == null || encrypted.isEmpty) return;

      final jsonString = _crypto.decryptNotes(encrypted, vaultKey);
      final decoded = json.decode(jsonString) as List<dynamic>;
      _notes
        ..clear()
        ..addAll(decoded.map((e) => Note.fromJson(e as Map<String, dynamic>)));
      notifyListeners();
    } catch (e) {
      // Falha na decifração: notas corrompidas ou chave incorreta
      // (não deve ocorrer em fluxo normal — logado em modo debug).
      debugPrint('VaultProvider.loadNotes error: $e');
    }
  }

  /// Limpa as notas da memória sem tocar no storage (chamado no logout).
  void clearMemory() {
    _notes.clear();
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<void> addNote({
    required String title,
    required String content,
    required Uint8List vaultKey,
    String username = '',
    String password = '',
  }) async {
    final now = DateTime.now();
    final note = Note(
      id: now.microsecondsSinceEpoch.toString(),
      title: title,
      content: content,
      username: username,
      password: password,
      createdAt: now,
      updatedAt: now,
    );
    _notes.insert(0, note);
    await _persist(vaultKey);
    notifyListeners();
  }

  Future<void> updateNote(Note updated, Uint8List vaultKey) async {
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i < 0) return;
    _notes[i] = updated.copyWith(updatedAt: DateTime.now());
    await _persist(vaultKey);
    notifyListeners();
  }

  Future<void> deleteNote(String id, Uint8List vaultKey) async {
    _notes.removeWhere((n) => n.id == id);
    await _persist(vaultKey);
    notifyListeners();
  }

  // ── Re-cifragem ao trocar PIN ─────────────────────────────────────────────

  /// Cifra o conteúdo atual com [newKey] e retorna o blob cifrado.
  /// Chamado por [AuthProvider] durante a troca de PIN.
  Future<String?> reEncryptWithNewKey(Uint8List newKey) async {
    if (_notes.isEmpty) return null;
    final json = _encodeJson();
    return _crypto.encryptNotes(json, newKey);
  }

  // ── Utilitários públicos ──────────────────────────────────────────────────

  bool isPasswordReusedElsewhere(String password, {String? excludeNoteId}) {
    final p = password.trim();
    if (p.isEmpty) return false;
    return _notes.any(
      (n) =>
          n.id != excludeNoteId &&
          n.password.trim().isNotEmpty &&
          n.password == p,
    );
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  String _encodeJson() =>
      json.encode(_notes.map((n) => n.toJson()).toList(growable: false));

  Future<void> _persist(Uint8List vaultKey) async {
    final encrypted = _crypto.encryptNotes(_encodeJson(), vaultKey);
    await _storage.writeEncryptedNotes(encrypted);
  }
}
