import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../widgets/forgot_pin_dialog.dart';

/// Tela de desbloqueio: biometria primeiro (quando disponível), depois PIN e bloqueio progressivo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pinController = TextEditingController();

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _didAutoPromptBiometric = false;
  Timer? _lockoutTicker;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _lockoutTicker?.cancel();
    _pinController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _ensureLockoutTicker(AuthProvider auth) {
    if (auth.isPinLockedOut) {
      _lockoutTicker ??= Timer.periodic(const Duration(seconds: 1), (_) async {
        if (!mounted) return;
        await context.read<AuthProvider>().refreshPinLockoutState();
        if (mounted) setState(() {});
      });
    } else {
      _lockoutTicker?.cancel();
      _lockoutTicker = null;
    }
  }

  Future<void> _submit(AuthProvider auth) async {
    if (auth.isPinLockedOut) return;
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    final pin = _pinController.text.trim();
    final success = await auth.verifyPin(pin);
    if (!success && mounted && auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
    if (success && mounted) {
      _pinController.clear();
    }
  }

  Future<void> _tryBiometric(AuthProvider auth) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.authenticateWithBiometrics();
    if (!success && mounted && auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  void _maybeAutoPromptBiometric(AuthProvider auth) {
    if (_didAutoPromptBiometric) return;
    if (!auth.hasStoredPin || !auth.isBiometricPhase) return;
    if (auth.isLoading) return;
    _didAutoPromptBiometric = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tryBiometric(context.read<AuthProvider>());
    });
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoading) {
      _ensureLockoutTicker(auth);
      _maybeAutoPromptBiometric(auth);
    }

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isCreatingPin = !auth.hasStoredPin;
    final showBiometricPhase = auth.isBiometricPhase;
    final showPinForm = isCreatingPin || auth.shouldOfferPinEntry;
    final lockedOut = auth.isPinLockedOut;
    final lockLeft = auth.pinLockoutRemaining ?? Duration.zero;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    showBiometricPhase
                        ? Icons.face_retouching_natural_outlined
                        : Icons.lock_outline,
                    size: 72,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'NoxVault',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subtitle(
                      context,
                      isCreatingPin: isCreatingPin,
                      showBiometricPhase: showBiometricPhase,
                      lockedOut: lockedOut,
                    ),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  if (lockedOut && !isCreatingPin) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Tempo restante: ${_formatDuration(lockLeft)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.orangeAccent),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (showBiometricPhase) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () => _tryBiometric(auth),
                        icon: const Icon(Icons.face),
                        label: Text(
                          'Biometria (${auth.biometricAttemptsThisSession + 1}/$kMaxBiometricAttemptsBeforePin)',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No Android, o sistema usa rosto ou impressão digital, conforme configurado no aparelho.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.white38),
                    ),
                  ],
                  if (showPinForm) ...[
                    Form(
                      key: _formKey,
                      child: TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        maxLength: 6,
                        readOnly: lockedOut && !isCreatingPin,
                        decoration: const InputDecoration(
                          labelText: 'PIN',
                          hintText: 'Mínimo 4 dígitos',
                          counterText: '',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        validator: (value) {
                          final pin = value?.trim() ?? '';
                          if (pin.isEmpty) {
                            return 'Informe seu PIN.';
                          }
                          if (pin.length < 4) {
                            return 'O PIN deve ter no mínimo 4 dígitos.';
                          }
                          if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
                            return 'Use apenas números no PIN.';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (auth.isLoading ||
                                (lockedOut && !isCreatingPin))
                            ? null
                            : () => _submit(auth),
                        child: Text(
                          isCreatingPin ? 'Criar PIN e entrar' : 'Desbloquear',
                        ),
                      ),
                    ),
                    if (!isCreatingPin && auth.hasStoredPin) ...[
                      const SizedBox(height: 8),
                      if (auth.biometricAvailable)
                        TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => const ForgotPinDialog(),
                                  ),
                          child: const Text('Esqueci o PIN'),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Recuperação do PIN requer biometria neste aparelho.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white38),
                          ),
                        ),
                    ],
                  ],
                  if (auth.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        auth.errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle(
    BuildContext context, {
    required bool isCreatingPin,
    required bool showBiometricPhase,
    required bool lockedOut,
  }) {
    if (isCreatingPin) {
      return 'Crie um PIN para proteger seu cofre.';
    }
    if (lockedOut) {
      return 'Cofre temporariamente bloqueado após várias tentativas de PIN incorretas.';
    }
    if (showBiometricPhase) {
      return 'Confirme sua identidade com biometria. Após $kMaxBiometricAttemptsBeforePin tentativas sem sucesso, será solicitado o PIN.';
    }
    return 'Digite seu PIN para desbloquear o cofre.';
  }
}
