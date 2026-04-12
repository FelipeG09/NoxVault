import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/secure_storage_service.dart';

/// Máximo de tentativas de biometria antes de exigir PIN.
const int kMaxBiometricAttemptsBeforePin = 2;

/// Tentativas de PIN incorreto antes de bloquear.
const int kMaxPinFailuresBeforeLockout = 3;

/// Duração do bloqueio após exceder tentativas de PIN.
const Duration kPinLockoutDuration = Duration(minutes: 1);

/// Tempo para concluir a redefinição de PIN após validar biometria.
const Duration kPinRecoverySessionTtl = Duration(minutes: 3);

/// Provider responsável por autenticação com PIN e biometria (ex.: rosto / digital).
class AuthProvider extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _storage = SecureStorageService();

  bool _isAuthenticated = false;
  bool _hasStoredPin = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String? _errorMessage;

  /// Tentativas de biometria nesta sessão de desbloqueio (reinicia ao sair e voltar).
  int _biometricAttemptsThisSession = 0;

  int? _pinLockoutUntilMs;
  int _pinFailCount = 0;

  /// Após biometria em “esqueci o PIN”, permite definir novo PIN dentro do TTL.
  bool _pinRecoveryArmed = false;
  DateTime? _pinRecoveryArmedAt;

  bool get isAuthenticated => _isAuthenticated;

  bool get hasStoredPin => _hasStoredPin;

  bool get isLoading => _isLoading;

  bool get biometricAvailable => _biometricAvailable;

  String? get errorMessage => _errorMessage;

  int get biometricAttemptsThisSession => _biometricAttemptsThisSession;

  /// PIN só entra após esgotar biometria (ou se não houver biometria).
  bool get shouldOfferPinEntry =>
      !_hasStoredPin ||
      !_biometricAvailable ||
      _biometricAttemptsThisSession >= kMaxBiometricAttemptsBeforePin;

  /// Ainda na fase “reconhecimento facial / biometria” antes do PIN.
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
    if (left.isNegative) return Duration.zero;
    return left;
  }

  bool get pinRecoverySessionReady {
    if (!_pinRecoveryArmed || _pinRecoveryArmedAt == null) return false;
    return DateTime.now().difference(_pinRecoveryArmedAt!) < kPinRecoverySessionTtl;
  }

  /// Inicializa o provider verificando PIN salvo, biometria e bloqueio de PIN.
  Future<void> init() async {
    _setLoading(true);
    try {
      _clearPinRecoveryArm();
      final pin = await _storage.readPin();
      _hasStoredPin = pin != null;

      _biometricAvailable = await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();

      _pinFailCount = await _storage.readPinFailCount();
      final lockMs = await _storage.readPinLockoutUntilMs();
      _pinLockoutUntilMs = lockMs;
      await _clearExpiredPinLockout();
    } catch (e) {
      _errorMessage = 'Falha ao inicializar autenticação.';
    } finally {
      _setLoading(false);
    }
  }

  /// Chamado ao voltar para a tela de login (ex.: logout): reinicia fase biométrica.
  void resetUnlockSession() {
    _biometricAttemptsThisSession = 0;
    _errorMessage = null;
    notifyListeners();
  }

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

  /// Atualiza estado de bloqueio (ex.: countdown na UI).
  Future<void> refreshPinLockoutState() async {
    await _clearExpiredPinLockout();
  }

  void _clearPinRecoveryArm() {
    _pinRecoveryArmed = false;
    _pinRecoveryArmedAt = null;
  }

  /// Biometria para ações sensíveis (não altera contagem de desbloqueio).
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

  /// Inicia recuperação de PIN na tela de login (exige biometria).
  Future<bool> startPinRecoveryWithBiometric() async {
    _errorMessage = null;
    if (!_biometricAvailable) {
      _errorMessage =
          'Sem biometria neste aparelho não é possível redefinir o PIN por aqui.';
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

  /// Conclui redefinição do PIN após [startPinRecoveryWithBiometric].
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
      await _storage.writePin(n);
      _clearPinRecoveryArm();
      _hasStoredPin = true;
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

  /// Altera o PIN mestre estando já autenticado (exige PIN atual).
  Future<bool> changeMasterPin({
    required String currentPin,
    required String newPin,
    required String confirm,
  }) async {
    _errorMessage = null;
    if (!_isAuthenticated) {
      _errorMessage = 'Abra o cofre antes de alterar o PIN.';
      notifyListeners();
      return false;
    }
    final stored = await _storage.readPin();
    if (stored != currentPin.trim()) {
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
      await _storage.writePin(newPin.trim());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o novo PIN.';
      notifyListeners();
      return false;
    }
  }

  /// Altera o PIN mestre com biometria em vez do PIN atual.
  Future<bool> changeMasterPinWithBiometric({
    required String newPin,
    required String confirm,
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
      await _storage.writePin(newPin.trim());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Não foi possível salvar o novo PIN.';
      notifyListeners();
      return false;
    }
  }

  String? _validateNewPinPair(String newPin, String confirm) {
    final n = newPin.trim();
    final c = confirm.trim();
    if (n.isEmpty || c.isEmpty) {
      return 'Preencha o novo PIN e a confirmação.';
    }
    if (n != c) {
      return 'O novo PIN e a confirmação não coincidem.';
    }
    if (n.length < 4 || n.length > 6) {
      return 'O PIN deve ter entre 4 e 6 dígitos.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(n)) {
      return 'Use apenas números no PIN.';
    }
    return null;
  }

  /// Tenta autenticar via biometria forte (rosto / digital, conforme o dispositivo).
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

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason:
            'Use o reconhecimento biométrico para desbloquear o NoxVault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
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
            'Não foi possível autenticar. Tente novamente ($_biometricAttemptsThisSession/$kMaxBiometricAttemptsBeforePin).';
      }
      notifyListeners();
      return false;
    } catch (e) {
      _biometricAttemptsThisSession++;
      if (_biometricAttemptsThisSession >= kMaxBiometricAttemptsBeforePin) {
        _errorMessage =
            'Erro na biometria. Digite seu PIN para continuar.';
      } else {
        _errorMessage =
            'Erro na biometria. Tente novamente ($_biometricAttemptsThisSession/$kMaxBiometricAttemptsBeforePin).';
      }
      notifyListeners();
      return false;
    }
  }

  /// Salva um novo PIN (primeiro acesso) e autentica o usuário.
  Future<void> createPin(String pin) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      await _storage.writePin(pin);
      _hasStoredPin = true;
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

  /// Verifica o PIN digitado.
  Future<bool> verifyPin(String pin) async {
    _errorMessage = null;
    await refreshPinLockoutState();

    if (isPinLockedOut) {
      final rem = pinLockoutRemaining;
      final secs = rem?.inSeconds ?? 0;
      _errorMessage =
          'Muitas tentativas incorretas. Aguarde ${secs > 0 ? secs : 1} segundo(s).';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    try {
      final storedPin = await _storage.readPin();
      if (storedPin == null) {
        await createPin(pin);
        return true;
      }

      if (storedPin == pin) {
        _pinFailCount = 0;
        await _storage.writePinFailCount(0);
        _pinLockoutUntilMs = null;
        await _storage.writePinLockoutUntilMs(null);
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }

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

  /// Sai do cofre, mas mantém o PIN salvo.
  Future<void> logout() async {
    _isAuthenticated = false;
    resetUnlockSession();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
