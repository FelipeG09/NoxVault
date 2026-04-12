import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/vault_provider.dart';
import '../utils/password_security.dart';
import 'password_hint_row.dart';

/// Abre o formulário para criar ou editar nota/credencial.
Future<void> showNoteFormSheet(
  BuildContext context, {
  Note? existing,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _NoteFormBody(existing: existing),
  );
}

class _NoteFormBody extends StatefulWidget {
  const _NoteFormBody({this.existing});

  final Note? existing;

  @override
  State<_NoteFormBody> createState() => _NoteFormBodyState();
}

class _NoteFormBodyState extends State<_NoteFormBody> {
  late final TextEditingController _titleController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _contentController;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _usernameController = TextEditingController(text: e?.username ?? '');
    _passwordController = TextEditingController(text: e?.password ?? '');
    _contentController = TextEditingController(text: e?.content ?? '');
    _passwordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  PasswordAnalysis _analysis(VaultProvider vault) {
    final pwd = _passwordController.text;
    final reused = vault.isPasswordReusedElsewhere(
      pwd,
      excludeNoteId: widget.existing?.id,
    );
    return analyzeVaultPassword(
      password: pwd,
      reusedElsewhere: reused,
    );
  }

  void _applyGeneratedPassword() {
    setState(() {
      _passwordController.text = generateStrongPassword();
      _obscurePassword = false;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty && content.isEmpty && username.isEmpty && password.isEmpty) {
      return;
    }

    final vault = context.read<VaultProvider>();
    final messenger = ScaffoldMessenger.of(context);

    if (widget.existing != null) {
      final updated = widget.existing!.copyWith(
        title: title.isEmpty ? 'Nota sem título' : title,
        username: username,
        password: password,
        content: content,
      );
      await vault.updateNote(updated);
    } else {
      await vault.addNote(
        title: title.isEmpty ? 'Nota sem título' : title,
        username: username,
        password: password,
        content: content,
      );
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.existing != null ? 'Alterações salvas.' : 'Salvo no cofre.',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final vault = context.watch<VaultProvider>();
    final analysis = _analysis(vault);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEdit ? 'Editar entrada' : 'Nova entrada',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Título',
              hintText: 'Ex.: Netflix, E-mail trabalho',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Usuário / e-mail (opcional)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Senha (opcional)',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _obscurePassword ? 'Mostrar' : 'Ocultar',
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _applyGeneratedPassword,
              icon: const Icon(Icons.auto_fix_high_outlined, size: 20),
              label: const Text('Sugerir senha forte'),
            ),
          ),
          PasswordHintRow(analysis: analysis),
          const SizedBox(height: 12),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observações (opcional)',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(isEdit ? 'Salvar alterações' : 'Salvar no cofre'),
            ),
          ),
        ],
      ),
    );
  }
}
