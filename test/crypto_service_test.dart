import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:noxvault/services/crypto_service.dart';

void main() {
  final crypto = CryptoService();

  group('CryptoService — PIN hash', () {
    test('hashPin gera hash diferente do PIN original', () {
      final hash = crypto.hashPin('1234');
      expect(hash, isNot(equals('1234')));
      expect(hash, contains(':'));
    });

    test('verifyPin retorna true para PIN correto', () {
      final hash = crypto.hashPin('5678');
      expect(crypto.verifyPin('5678', hash), isTrue);
    });

    test('verifyPin retorna false para PIN incorreto', () {
      final hash = crypto.hashPin('5678');
      expect(crypto.verifyPin('0000', hash), isFalse);
    });

    test('dois hashes do mesmo PIN são diferentes (salts únicos)', () {
      final h1 = crypto.hashPin('1234');
      final h2 = crypto.hashPin('1234');
      expect(h1, isNot(equals(h2)));
    });

    test('verifyPin retorna false para hash malformado', () {
      expect(crypto.verifyPin('1234', 'invalido_sem_dois_pontos'), isFalse);
    });
  });

  group('CryptoService — derivação de chave', () {
    test('deriveKey retorna Uint8List de 32 bytes', () {
      final hash = crypto.hashPin('1234');
      final key = crypto.deriveKey('1234', hash);
      expect(key, isA<Uint8List>());
      expect(key.length, equals(32));
    });

    test('mesma senha + mesmo salt derivam mesma chave', () {
      final hash = crypto.hashPin('4321');
      final k1 = crypto.deriveKey('4321', hash);
      final k2 = crypto.deriveKey('4321', hash);
      expect(k1, equals(k2));
    });

    test('PIN errado deriva chave diferente', () {
      final hash = crypto.hashPin('4321');
      final k1 = crypto.deriveKey('4321', hash);
      final k2 = crypto.deriveKey('9999', hash);
      expect(k1, isNot(equals(k2)));
    });
  });

  group('CryptoService — cifra/decifra notas', () {
    late Uint8List key;

    setUp(() {
      final hash = crypto.hashPin('abcd');
      key = crypto.deriveKey('abcd', hash);
    });

    test('encryptNotes retorna string diferente do original', () {
      const plain = '{"notes":[{"id":"1","title":"Teste"}]}';
      final cipher = crypto.encryptNotes(plain, key);
      expect(cipher, isNot(equals(plain)));
      expect(cipher, contains(':'));
    });

    test('decryptNotes recupera texto original', () {
      const plain = 'conteúdo secreto 🔒';
      final cipher = crypto.encryptNotes(plain, key);
      expect(crypto.decryptNotes(cipher, key), equals(plain));
    });

    test('dois encrypts do mesmo texto geram ciphertexts diferentes (IVs únicos)', () {
      const plain = 'texto igual';
      final c1 = crypto.encryptNotes(plain, key);
      final c2 = crypto.encryptNotes(plain, key);
      expect(c1, isNot(equals(c2)));
    });

    test('decifrar com chave errada lança exceção', () {
      final hash2 = crypto.hashPin('outra_senha');
      final wrongKey = crypto.deriveKey('outra_senha', hash2);
      const plain = 'dado sigiloso';
      final cipher = crypto.encryptNotes(plain, key);
      expect(() => crypto.decryptNotes(cipher, wrongKey), throwsException);
    });

    test('decifrar formato inválido lança FormatException', () {
      expect(
        () => crypto.decryptNotes('semDoisPontos', key),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
