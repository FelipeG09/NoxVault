import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/note.dart';
import '../services/secure_storage_service.dart';

/// Provider responsável por gerenciar as notas do cofre.
class VaultProvider extends ChangeNotifier {
  final SecureStorageService _storage = SecureStorageService();

  final List<Note> _notes = [];

  List<Note> get notes => List.unmodifiable(_notes);

  /// Carrega notas salvas do armazenamento seguro.
  Future<void> loadNotes() async {
    try {
      final jsonString = await _storage.readNotes();
      if (jsonString == null) return;

      final List<dynamic> decoded = json.decode(jsonString) as List<dynamic>;
      _notes
        ..clear()
        ..addAll(
          decoded
              .map((e) => Note.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      notifyListeners();
    } catch (e) {
      // Em produção você poderia logar o erro; aqui apenas ignoramos
      // para manter o exemplo simples.
    }
  }

  /// Adiciona uma nova nota ao cofre e salva no storage seguro.
  Future<void> addNote({
    required String title,
    required String content,
    String username = '',
    String password = '',
  }) async {
    final note = Note(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      content: content,
      username: username,
      password: password,
      createdAt: DateTime.now(),
    );
    _notes.insert(0, note);
    await _persist();
    notifyListeners();
  }

  /// Atualiza uma nota existente.
  Future<void> updateNote(Note updated) async {
    final i = _notes.indexWhere((n) => n.id == updated.id);
    if (i < 0) return;
    _notes[i] = updated;
    await _persist();
    notifyListeners();
  }

  /// Remove uma nota.
  Future<void> deleteNote(String id) async {
    _notes.removeWhere((n) => n.id == id);
    await _persist();
    notifyListeners();
  }

  /// `true` se outra entrada (diferente de [excludeNoteId]) usa a mesma senha.
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

  Future<void> _persist() async {
    final encoded =
        json.encode(_notes.map((note) => note.toJson()).toList(growable: false));
    await _storage.writeNotes(encoded);
  }
}

