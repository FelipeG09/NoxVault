import 'package:flutter_test/flutter_test.dart';
import 'package:noxvault/models/note.dart';

void main() {
  group('Note — serialização', () {
    test('toJson / fromJson é idempotente', () {
      final now = DateTime(2024, 6, 15, 10, 30);
      final note = Note(
        id: '123',
        title: 'Google',
        content: 'Conta principal',
        username: 'user@gmail.com',
        password: 'S3cr3t!',
        createdAt: now,
        updatedAt: now,
      );

      final json = note.toJson();
      final restored = Note.fromJson(json);

      expect(restored.id, equals(note.id));
      expect(restored.title, equals(note.title));
      expect(restored.username, equals(note.username));
      expect(restored.password, equals(note.password));
      expect(restored.createdAt, equals(note.createdAt));
      expect(restored.updatedAt, equals(note.updatedAt));
    });

    test('fromJson sem updatedAt usa createdAt (retrocompatibilidade)', () {
      final json = {
        'id': '1',
        'title': 'Antiga',
        'content': '',
        'username': '',
        'password': '',
        'createdAt': '2023-01-01T00:00:00.000',
        // updatedAt ausente
      };
      final note = Note.fromJson(json);
      expect(note.updatedAt, equals(note.createdAt));
    });
  });

  group('Note — copyWith', () {
    test('copyWith atualiza apenas os campos informados', () {
      final original = Note(
        id: '1',
        title: 'Título original',
        content: '',
        createdAt: DateTime(2024),
      );
      final updated = original.copyWith(title: 'Novo título');

      expect(updated.id, equals(original.id));
      expect(updated.title, equals('Novo título'));
      expect(updated.createdAt, equals(original.createdAt));
    });

    test('copyWith com updatedAt diferente de createdAt', () {
      final created = DateTime(2023);
      final updated = DateTime(2024);
      final note = Note(
        id: '1',
        title: 'T',
        content: '',
        createdAt: created,
      ).copyWith(updatedAt: updated);

      expect(note.createdAt, equals(created));
      expect(note.updatedAt, equals(updated));
    });
  });

  group('Note — hasCredentialFields', () {
    test('retorna true quando username ou password preenchidos', () {
      final n = Note(
        id: '1', title: 'T', content: '',
        createdAt: DateTime.now(),
        username: 'user',
      );
      expect(n.hasCredentialFields, isTrue);
    });

    test('retorna false quando ambos vazios', () {
      final n = Note(id: '1', title: 'T', content: '', createdAt: DateTime.now());
      expect(n.hasCredentialFields, isFalse);
    });
  });
}
