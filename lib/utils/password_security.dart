import 'dart:math';

/// Classificação da senha armazenada no cofre (não o PIN numérico).
enum PasswordStrengthLabel {
  none,
  weak,
  medium,
  strong,
}

/// Resultado da análise de uma senha de login.
class PasswordAnalysis {
  const PasswordAnalysis({
    required this.strength,
    required this.message,
    required this.isReused,
  });

  final PasswordStrengthLabel strength;
  final String message;
  final bool isReused;

  bool get hasIssues =>
      strength == PasswordStrengthLabel.weak || isReused;
}

const _commonPasswords = <String>{
  '123456',
  '12345678',
  'password',
  'senha',
  'qwerty',
  'abc123',
  '111111',
  '123123',
  'admin',
  'letmein',
  'welcome',
  'monkey',
  'dragon',
  'master',
  'sunshine',
  'princess',
  'football',
  'iloveyou',
  '654321',
  'shadow',
  'michael',
  'jessica',
  'baseball',
  'superman',
  'batman',
  'trustno1',
  'hunter',
  'ranger',
  'thomas',
  'soccer',
  'charlie',
  'andrew',
  'michelle',
  'love',
  'starwars',
  'whatever',
  'password1',
  'senha123',
};

/// Avalia força e indica reutilização com base nas notas já salvas.
PasswordAnalysis analyzeVaultPassword({
  required String password,
  required bool reusedElsewhere,
}) {
  final trimmed = password.trim();
  if (trimmed.isEmpty) {
    return const PasswordAnalysis(
      strength: PasswordStrengthLabel.none,
      message: '',
      isReused: false,
    );
  }

  final lower = trimmed.toLowerCase();
  var score = 0;
  if (trimmed.length >= 8) score++;
  if (trimmed.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(trimmed)) score++;
  if (RegExp(r'[a-z]').hasMatch(trimmed)) score++;
  if (RegExp(r'[0-9]').hasMatch(trimmed)) score++;
  if (RegExp(r'[^A-Za-z0-9]').hasMatch(trimmed)) score++;

  PasswordStrengthLabel strength;
  String message;

  if (trimmed.length < 6 ||
      _commonPasswords.contains(lower) ||
      score <= 2) {
    strength = PasswordStrengthLabel.weak;
    message =
        'Senha fraca: use mais caracteres, misture maiúsculas, números e símbolos.';
  } else if (score <= 4) {
    strength = PasswordStrengthLabel.medium;
    message = 'Senha média: considere aumentar o tamanho e a variedade.';
  } else {
    strength = PasswordStrengthLabel.strong;
    message = 'Senha forte.';
  }

  return PasswordAnalysis(
    strength: strength,
    message: message,
    isReused: reusedElsewhere,
  );
}

/// Gera senha aleatória (criptograficamente segura o suficiente para o app).
String generateStrongPassword({int length = 16}) {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghijkmnopqrstuvwxyz';
  const digits = '23456789';
  const symbols = '!@#\$%&*-_=+?';
  final all = '$upper$lower$digits$symbols';
  final rnd = Random.secure();
  final buf = StringBuffer();
  buf.writeCharCode(upper.codeUnitAt(rnd.nextInt(upper.length)));
  buf.writeCharCode(lower.codeUnitAt(rnd.nextInt(lower.length)));
  buf.writeCharCode(digits.codeUnitAt(rnd.nextInt(digits.length)));
  buf.writeCharCode(symbols.codeUnitAt(rnd.nextInt(symbols.length)));
  for (var i = buf.length; i < length; i++) {
    buf.writeCharCode(all.codeUnitAt(rnd.nextInt(all.length)));
  }
  final chars = buf.toString().split('')..shuffle(rnd);
  return chars.join();
}
