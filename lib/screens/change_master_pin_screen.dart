import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Alteração do PIN mestre dentro do cofre (PIN atual ou biometria).
class ChangeMasterPinScreen extends StatefulWidget {
  const ChangeMasterPinScreen({super.key});

  @override
  State<ChangeMasterPinScreen> createState() => _ChangeMasterPinScreenState();
}

class _ChangeMasterPinScreenState extends State<ChangeMasterPinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _useBiometricInsteadOfCurrent = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final newPin = _newPinController.text.trim();
    final confirm = _confirmPinController.text.trim();

    final bool ok;
    if (_useBiometricInsteadOfCurrent) {
      ok = await auth.changeMasterPinWithBiometric(
        newPin: newPin,
        confirm: confirm,
      );
    } else {
      ok = await auth.changeMasterPin(
        currentPin: _currentPinController.text.trim(),
        newPin: newPin,
        confirm: confirm,
      );
    }

    if (!mounted) return;
    if (ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('PIN mestre alterado com sucesso.')),
      );
      Navigator.of(context).pop();
    } else if (auth.errorMessage != null) {
      messenger.showSnackBar(
        SnackBar(content: Text(auth.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alterar PIN mestre'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Escolha um PIN numérico de 4 a 6 dígitos. '
                  'Você pode confirmar com o PIN atual ou com biometria.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                if (auth.biometricAvailable)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar biometria em vez do PIN atual'),
                    value: _useBiometricInsteadOfCurrent,
                    onChanged: (v) =>
                        setState(() => _useBiometricInsteadOfCurrent = v),
                  ),
                if (!_useBiometricInsteadOfCurrent) ...[
                  TextFormField(
                    controller: _currentPinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'PIN atual',
                      counterText: '',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) {
                      final p = value?.trim() ?? '';
                      if (p.isEmpty) return 'Informe o PIN atual.';
                      if (p.length < 4 || p.length > 6) {
                        return 'PIN inválido.';
                      }
                      if (!RegExp(r'^[0-9]+$').hasMatch(p)) {
                        return 'Apenas números.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _newPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Novo PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                  validator: (value) {
                    final p = value?.trim() ?? '';
                    if (p.isEmpty) return 'Informe o novo PIN.';
                    if (p.length < 4 || p.length > 6) {
                      return 'Entre 4 e 6 dígitos.';
                    }
                    if (!RegExp(r'^[0-9]+$').hasMatch(p)) {
                      return 'Apenas números.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar novo PIN',
                    counterText: '',
                    prefixIcon: Icon(Icons.password_outlined),
                  ),
                  validator: (value) {
                    final p = value?.trim() ?? '';
                    if (p.isEmpty) return 'Confirme o novo PIN.';
                    if (p != _newPinController.text.trim()) {
                      return 'Não coincide com o novo PIN.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: auth.isLoading ? null : _submit,
                  child: const Text('Salvar novo PIN'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
