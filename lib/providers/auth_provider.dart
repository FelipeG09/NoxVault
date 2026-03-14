import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/secure_storage_service.dart';

/// Provider responsável por autenticação com PIN e biometria.
class AuthProvider extends ChangeNotifier {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final SecureStorageService _storage = SecureStorageService();

  bool _isAuthenticated = false;
  bool _hasStoredPin = false;
  bool _isLoading = false;
  bool _biometricAvailable = false;
  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;

  bool get hasStoredPin => _hasStoredPin;

  bool get isLoading => _isLoading;

  bool get biometricAvailable => _biometricAvailable;

  String? get errorMessage => _errorMessage;

  /// Inicializa o provider verificando PIN salvo e biometria.
  Future<void> init() async {
    _setLoading(true);
    try {
      final pin = await _storage.readPin();
      _hasStoredPin = pin != null;

      _biometricAvailable = await _localAuth.canCheckBiometrics &&
          await _localAuth.isDeviceSupported();
    } catch (e) {
      _errorMessage = 'Falha ao inicializar autenticação.';
    } finally {
      _setLoading(false);
    }
  }

  /// Tenta autenticar via biometria (Face ID / Touch ID).
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
        localizedReason: 'Use sua biometria para desbloquear o NoxVault',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (didAuthenticate) {
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        _errorMessage =
            'Não foi possível autenticar com biometria. Tente novamente ou use seu PIN.';
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage =
          'Ocorreu um erro com a biometria. Tente novamente ou use seu PIN.';
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
    _setLoading(true);
    try {
      final storedPin = await _storage.readPin();
      if (storedPin == null) {
        // Se não existir PIN, tratamos como primeiro cadastro.
        await createPin(pin);
        return true;
      }

      if (storedPin == pin) {
        _isAuthenticated = true;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'PIN incorreto. Tente novamente.';
        notifyListeners();
        return false;
      }
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

