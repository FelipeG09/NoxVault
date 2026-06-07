import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/crypto_service.dart';
import '../services/secure_storage_service.dart';

/// Máximo de tentativas de biometria antes de exigir PIN.
const int kMaxBiometricAttemptsBeforePin = 2;

/// Tentativas de PIN incorreto antes de bloquear.
const int kMaxPinFailuresBeforeLockout = 3;

/// Duração do bloqueio após exceder tentativas de PIN.
const Duration kPinLockoutDuration = Duration(minutes: 1);

/// Tempo para concluir a redefinição de PIN após validar biometria.
const Duration kPinRecoverySessionTtl = Duration(minutes: 3);

/// Provider responsável por autenticação com PIN (hash PBKDF2) e biometria.
///
/// SEGURANÇA:
/// - O PIN nunca é armazenado em texto puro.
/// - Um hash PBKDF2-SHA256 com salt aleatório de 32 bytes e 200 000 iterações
///   é persistido via [SecureStorageService].
/// - Uma chave AES-256 derivada do PIN ([vaultKey]) é mantida em memória apenas
///   enquanto o cofre estiver desbloqueado, e apagada no logout.
class AuthProvider extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _storage = SecureStorageService();
  final CryptoService _crypto = CryptoService();

  bool _isAuthenticated = false;
  bool _hasStoredPin = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String? _errorMessage;

  /// Chave AES-256 derivada do PIN — disponível apenas quando autenticado.
  /// Usada pelo [VaultProvider] para cifrar/decifrar notas.
  Uint8List? _vaultKey;

  int _biometricAttemptsThisSession = 0;
  int? _pinLockoutUntilMs;
  int _pinFailCount = 0;

  bool _pinRecoveryArmed = false;
  DateTime? _pinRecoveryArmedAt;

  // ── Getters públicos ──────────────────────────────────────────────────────

  bool get isAuthenticated => _isAuthenticated;
  bool get hasStoredPin => _hasStoredPin;
  bool get isLoading => _isLoading;
  bool get biometricAvailable => _biometricAvailable;
  String? get errorMessage => _errorMessage;
  int get biometricAttemptsThisSession => _biometricAttemptsThisSession;

  /// Chave AES derivada do PIN — `null` se não autenticado.
  Uint8List? get vaultKey => _vaultKey;

  bool get shouldOfferPinEntry =>
      !_hasStoredPin ||
      !_biometricAvailable ||
      _biometricAttemptsThisSession >= kMaxBiometricAttemptsBeforePin;

  bool get isBiometricPhase =>
      _hasStoredPin && _biometricAvailable && !shouldOfferPinEntry;

  bool get isPinLockedOut {
    final until = _pinLockoutUntilMs;
    if (until == null) return false;
    return DateTime.now().millisecondsSinceEpoch < until;
  }

  Duration? get pinLockoutRemaining {
    final until = _pinLockoutUntilMs;
    if (until == null) return null;
    final left = Duration(
      milliseconds: until - DateTime.now().millisecondsSinceEpoch,
    );
    return left.isNegative ? Duration.zero : left;
  }

  bool get pinRecoverySessionReady {
    if (!_pinRecoveryArmed || _pinRecoveryArmedAt == null) return false;
    return DateTime.now().difference(_pinRecoveryArmedAt!) < kPinRecoverySessionTtl;
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> init() async {
    _setLoading(true);
    try {
      _clearPinRecoveryArm();
      final pinHash = await _storage.readPinHash();
      _hasStoredPin = pinHash != null;

      _biometricAvailable = await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();

      _pinFailCount = await _storage.readPinFailCount();
      _pinLockoutUntilMs = await _storage.readPinLockoutUntilMs();
      await _clearExpiredPinLockout();
    } catch (e) {
      _errorMessage = 'Falha ao inicializar autenticação.';
    } finally {
      _setLoading(false);
    }
  }

  void resetUnlockSession() {
    _biometricAttemptsThisSession = 0;
    _errorMessage = null;
    notifyListeners();
  }

  // ── Bloqueio de PIN ───────────────────────────────────────────────────────

  Future<void> _clearExpiredPinLockout() async {
    final until = _pinLockoutUntilMs;
    if (until == null) return;
    if (DateTime.now().millisecondsSinceEpoch >= until) {
      _pinLockoutUntilMs = null;
      await _storage.writePinLockoutUntilMs(null);
      _pinFailCount = 0;
      await _storage.writePinFailCount(0);
      notifyListeners();
    }
  }

  Future<void> refreshPinLockoutState() => _clearExpiredPinLockout();

  // ── Recuperação de PIN (esqueci o PIN) ────────────────────────────────────

  void _clearPinRecoveryArm() {
    _pinRecoveryArmed = false;
    _pinRecoveryArmedAt = null;
  }

  Future<bool> startPinRecoveryWithBiometric() async {
    _errorMessage = null;
    if (!_biometricAvailable) {
      _errorMessage =
          'Sem biometria neste aparelho — não é possível redefinir o PIN por aqui.';
      notifyListeners();
      return false;
    }
    final ok = await authenticateForSensitiveAction(
      'Confirme sua identidade para redefinir o PIN mestre',
    );
    if (!ok) {
      _errorMessage = 'Biometria não reconhecida. Tente de novo.';
      notifyListeners();
      return false;
    }
    _pinRecoveryArmed = true;
    _pinRecoveryArmedAt = DateTime.now();
    notifyListeners();
    return true;
  }

  void cancelPinRecoveryArm() {
    _clearPinRecoveryArm();
    notifyListeners();
  }

  Future<bool> completeMasterPinRecovery({
    required String newPin,
    required String confirm,
  }) async {
    _errorMessage = null;
    if (!pinRecoverySessionReady) {
      _errorMessage =
          'Sessão expirada ou inválida. Inicie novamente com a biometria.';
      _clearPinRecoveryArm();
      notifyListeners();
      return false;
    }
    final err = _validateNewPinPair(newPin, confirm);
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return false;
    }
    try {
      final n = newPin.trim();
      // NOTA: ao redefinir o PIN sem saber o anterior, as notas cifradas
      // com a chave antiga ficam inacessíveis. O vault é limpo para garantir
      // integridade — comportamento esperado num cenário de perda de PIN.
      await _storage.writeEncryptedNotes('');
      await _persistNewPin(n);
      _clearPinRecoveryArm();
      _pinFailCount = 0;
      await _storage.writePinFailCount(0);
      _pinLockoutUntilMs = null;
      await _storage.writePinLockoutUntilMs(null);
      _isAuthenticated = true;
      _biometricAttemptsThisSession = 0;
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o novo PIN.';
      notifyListeners();
      return false;
    }
  }

  // ── Alteração de PIN (dentro do cofre) ────────────────────────────────────

  Future<bool> changeMasterPin({
    required String currentPin,
    required String newPin,
    required String confirm,
    required Future<String?> Function() reEncryptNotes,
  }) async {
    _errorMessage = null;
    if (!_isAuthenticated) {
      _errorMessage = 'Abra o cofre antes de alterar o PIN.';
      notifyListeners();
      return false;
    }
    final storedHash = await _storage.readPinHash();
    if (storedHash == null || !_crypto.verifyPin(currentPin.trim(), storedHash)) {
      _errorMessage = 'PIN atual incorreto.';
      notifyListeners();
      return false;
    }
    final err = _validateNewPinPair(newPin, confirm);
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return false;
    }
    try {
      // 1. Deriva nova chave antes de sobrescrever o hash
      final newHash = _crypto.hashPin(newPin.trim());
      final newKey = _crypto.deriveKey(newPin.trim(), newHash);
      // 2. Re-cifra as notas com a nova chave (delegado ao VaultProvider)
      final reEncrypted = await reEncryptNotes();
      if (reEncrypted != null) {
        await _storage.writeEncryptedNotes(reEncrypted);
      }
      // 3. Persiste novo hash e atualiza chave em memória
      await _storage.writePinHash(newHash);
      _vaultKey = newKey;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o novo PIN.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> changeMasterPinWithBiometric({
    required String newPin,
    required String confirm,
    required Future<String?> Function() reEncryptNotes,
  }) async {
    _errorMessage = null;
    if (!_isAuthenticated) {
      _errorMessage = 'Abra o cofre antes de alterar o PIN.';
      notifyListeners();
      return false;
    }
    if (!_biometricAvailable) {
      _errorMessage = 'Biometria não disponível neste dispositivo.';
      notifyListeners();
      return false;
    }
    final err = _validateNewPinPair(newPin, confirm);
    if (err != null) {
      _errorMessage = err;
      notifyListeners();
      return false;
    }
    final ok = await authenticateForSensitiveAction(
      'Confirme com biometria para alterar o PIN mestre',
    );
    if (!ok) {
      _errorMessage = 'Biometria não reconhecida.';
      notifyListeners();
      return false;
    }
    try {
      final newHash = _crypto.hashPin(newPin.trim());
      final newKey = _crypto.deriveKey(newPin.trim(), newHash);
      final reEncrypted = await reEncryptNotes();
      if (reEncrypted != null) {
        await _storage.writeEncryptedNotes(reEncrypted);
      }
      await _storage.writePinHash(newHash);
      _vaultKey = newKey;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o novo PIN.';
      notifyListeners();
      return false;
    }
  }

  // ── Autenticação ──────────────────────────────────────────────────────────

  Future<bool> authenticateForSensitiveAction(String localizedReason) async {
    if (!_biometricAvailable) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    _errorMessage = null;
    notifyListeners();
    try {
      if (!_biometricAvailable) {
        _errorMessage =
            'Biometria não disponível neste dispositivo. Use seu PIN.';
        notifyListeners();
        return false;
      }

      final ok = await _localAuth.authenticate(
        localizedReason:
            'Use o reconhecimento biométrico para desbloquear o NoxVault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (ok) {
        // Biometria não deriva a chave AES diretamente — ao desbloquear via
        // biometria, a chave AES deve ser lida de um slot protegido, ou o
        // usuário deve inserir o PIN uma vez após reinstalar.
        // Por ora: se a chave ainda está em memória (sessão em background),
        // mantém. Caso contrário, pede PIN para derivar a chave.
        if (_vaultKey == null) {
          _biometricAttemptsThisSession++;
          _errorMessage =
              'Sessão expirada. Por favor, insira seu PIN para reabrir o cofre.';
          notifyListeners();
          return false;
        }
        _isAuthenticated = true;
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      _biometricAttemptsThisSession++;
      if (_biometricAttemptsThisSession >= kMaxBiometricAttemptsBeforePin) {
        _errorMessage =
            'Limite de tentativas biométricas atingido. Digite seu PIN.';
      } else {
        _errorMessage =
            'Não foi possível autenticar. Tente novamente '
            '($_biometricAttemptsThisSession/$kMaxBiometricAttemptsBeforePin).';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _biometricAttemptsThisSession++;
      _errorMessage = _biometricAttemptsThisSession >= kMaxBiometricAttemptsBeforePin
          ? 'Erro na biometria. Digite seu PIN para continuar.'
          : 'Erro na biometria. Tente novamente '
            '($_biometricAttemptsThisSession/$kMaxBiometricAttemptsBeforePin).';
      notifyListeners();
      return false;
    }
  }

  /// Cria um novo PIN (primeiro acesso), gera hash e deriva a chave AES.
  Future<void> createPin(String pin) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      await _persistNewPin(pin);
      _pinFailCount = 0;
      await _storage.writePinFailCount(0);
      _pinLockoutUntilMs = null;
      await _storage.writePinLockoutUntilMs(null);
      _isAuthenticated = true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar seu PIN com segurança.';
    } finally {
      _setLoading(false);
    }
  }

  /// Verifica o PIN digitado comparando contra o hash armazenado.
  Future<bool> verifyPin(String pin) async {
    _errorMessage = null;
    await refreshPinLockoutState();

    if (isPinLockedOut) {
      final secs = pinLockoutRemaining?.inSeconds ?? 0;
      _errorMessage =
          'Muitas tentativas incorretas. Aguarde ${secs > 0 ? secs : 1} segundo(s).';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final storedHash = await _storage.readPinHash();
      if (storedHash == null) {
        // Primeiro acesso — cria PIN
        await createPin(pin);
        return true;
      }

      if (_crypto.verifyPin(pin, storedHash)) {
        _pinFailCount = 0;
        await _storage.writePinFailCount(0);
        _pinLockoutUntilMs = null;
        await _storage.writePinLockoutUntilMs(null);
        // Deriva chave AES em memória — nunca persistida
        _vaultKey = _crypto.deriveKey(pin, storedHash);
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }

      // PIN incorreto
      _pinFailCount++;
      await _storage.writePinFailCount(_pinFailCount);

      if (_pinFailCount >= kMaxPinFailuresBeforeLockout) {
        final until = DateTime.now().add(kPinLockoutDuration);
        _pinLockoutUntilMs = until.millisecondsSinceEpoch;
        await _storage.writePinLockoutUntilMs(_pinLockoutUntilMs);
        _pinFailCount = 0;
        await _storage.writePinFailCount(0);
        _errorMessage =
            'PIN incorreto várias vezes. Aguarde 1 minuto para tentar de novo.';
      } else {
        final left = kMaxPinFailuresBeforeLockout - _pinFailCount;
        _errorMessage =
            'PIN incorreto. Restam $left tentativa(s) antes do bloqueio de 1 minuto.';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Erro ao verificar PIN.';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Sai do cofre: apaga a chave AES da memória e desmarca autenticado.
  Future<void> logout() async {
    _isAuthenticated = false;
    _vaultKey = null; // Chave apagada da memória no logout
    resetUnlockSession();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Internos ──────────────────────────────────────────────────────────────

  Future<void> _persistNewPin(String pin) async {
    final hash = _crypto.hashPin(pin.trim());
    await _storage.writePinHash(hash);
    _hasStoredPin = true;
    _vaultKey = _crypto.deriveKey(pin.trim(), hash);
  }

  String? _validateNewPinPair(String newPin, String confirm) {
    final n = newPin.trim();
    final c = confirm.trim();
    if (n.isEmpty || c.isEmpty) return 'Preencha o novo PIN e a confirmação.';
    if (n != c) return 'O novo PIN e a confirmação não coincidem.';
    if (n.length < 4 || n.length > 6) return 'O PIN deve ter entre 4 e 6 dígitos.';
    if (!RegExp(r'^[0-9]+$').hasMatch(n)) return 'Use apenas números no PIN.';
    return null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
