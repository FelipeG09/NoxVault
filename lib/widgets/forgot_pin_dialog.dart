import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Redefine o PIN mestre na tela de login após validar biometria.
class ForgotPinDialog extends StatefulWidget {
  const ForgotPinDialog({super.key});

  @override
  State<ForgotPinDialog> createState() => _ForgotPinDialogState();
}

class _ForgotPinDialogState extends State<ForgotPinDialog> {
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  @override
  void dispose() {
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _onBiometric(AuthProvider auth) async {
    await auth.startPinRecoveryWithBiometric();
    if (mounted) setState(() {});
  }

  Future<void> _submit(AuthProvider auth) async {
    final nav = Navigator.of(context, rootNavigator: true);

    final ok = await auth.completeMasterPinRecovery(
      newPin: _newPinController.text,
      confirm: _confirmPinController.text,
    );

    if (!mounted) return;
    if (ok) {
      nav.pop();
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final ready = auth.pinRecoverySessionReady;

    return AlertDialog(
      title: const Text('Esqueci o PIN'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!ready) ...[
              Text(
                'Use a biometria cadastrada neste aparelho para provar que é você '
                'e definir um novo PIN mestre.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: auth.isLoading ? null : () => _onBiometric(auth),
                icon: const Icon(Icons.face),
                label: const Text('Confirmar com biometria'),
              ),
            ] else ...[
              Text(
                'Digite o novo PIN (4 a 6 dígitos) duas vezes.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Novo PIN',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Confirmar PIN',
                  counterText: '',
                ),
              ),
            ],
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                auth.errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            context.read<AuthProvider>().cancelPinRecoveryArm();
            Navigator.of(context, rootNavigator: true).pop();
          },
          child: const Text('Cancelar'),
        ),
        if (ready)
          FilledButton(
            onPressed: auth.isLoading ? null : () => _submit(auth),
            child: const Text('Salvar PIN'),
          ),
      ],
    );
  }
}
