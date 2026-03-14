import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Tela de login com PIN e opção de biometria.
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
    _pinController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    final pin = _pinController.text.trim();
    final success = await auth.verifyPin(pin);
    if (!success && context.mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  Future<void> _tryBiometric(AuthProvider auth) async {
    final success = await auth.authenticateWithBiometrics();
    if (!success && context.mounted && auth.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    final isCreatingPin = !auth.hasStoredPin;

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
                  const Icon(
                    Icons.lock_outline,
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
                    isCreatingPin
                        ? 'Crie um PIN para proteger seu cofre.'
                        : 'Digite seu PIN para desbloquear o cofre.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 32),
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
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
                      onPressed:
                          auth.isLoading ? null : () => _submit(auth),
                      child: Text(
                        isCreatingPin ? 'Criar PIN e entrar' : 'Desbloquear',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (auth.biometricAvailable)
                    TextButton.icon(
                      onPressed:
                          auth.isLoading ? null : () => _tryBiometric(auth),
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Usar biometria'),
                    ),
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
}

