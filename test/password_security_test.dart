import 'package:flutter_test/flutter_test.dart';
import 'package:noxvault/utils/password_security.dart';

void main() {
  group('analyzeVaultPassword — força da senha', () {
    test('senha vazia retorna strength none', () {
      final r = analyzeVaultPassword(password: '', reusedElsewhere: false);
      expect(r.strength, equals(PasswordStrengthLabel.none));
    });

    test('senha curta (< 8 chars) é fraca', () {
      final r = analyzeVaultPassword(password: '12345', reusedElsewhere: false);
      expect(r.strength, equals(PasswordStrengthLabel.weak));
    });

    test('senha longa com maiús/minús/números/símbolos é forte', () {
      final r = analyzeVaultPassword(
        password: 'Tr0ub4dor&3!xK#',
        reusedElsewhere: false,
      );
      expect(r.strength, equals(PasswordStrengthLabel.strong));
    });

    test('reutilização marca isReused como true', () {
      final noReuse = analyzeVaultPassword(
        password: 'MinhaSenh@Forte1',
        reusedElsewhere: false,
      );
      final withReuse = analyzeVaultPassword(
        password: 'MinhaSenh@Forte1',
        reusedElsewhere: true,
      );
      expect(noReuse.isReused, isFalse);
      expect(withReuse.isReused, isTrue);
    });

    test('senha da lista de senhas comuns é fraca', () {
      final r = analyzeVaultPassword(
        password: 'password123',
        reusedElsewhere: false,
      );
      expect(r.strength, equals(PasswordStrengthLabel.weak));
    });

    test('hasIssues é true para senha fraca ou reutilizada', () {
      final weak = analyzeVaultPassword(password: '123', reusedElsewhere: false);
      final reused = analyzeVaultPassword(
        password: 'Tr0ub4dor&3!xK#',
        reusedElsewhere: true,
      );
      expect(weak.hasIssues, isTrue);
      expect(reused.hasIssues, isTrue);
    });
  });

  group('generateStrongPassword', () {
    test('gera senha com comprimento esperado', () {
      final pwd = generateStrongPassword(length: 16);
      expect(pwd.length, equals(16));
    });

    test('gera senhas diferentes a cada chamada', () {
      final p1 = generateStrongPassword();
      final p2 = generateStrongPassword();
      expect(p1, isNot(equals(p2)));
    });

    test('senha gerada é forte', () {
      final pwd = generateStrongPassword(length: 20);
      final r = analyzeVaultPassword(password: pwd, reusedElsewhere: false);
      expect(r.strength, equals(PasswordStrengthLabel.strong));
    });
  });
}
