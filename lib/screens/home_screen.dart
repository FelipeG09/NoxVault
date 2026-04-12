import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/note.dart';
import '../providers/auth_provider.dart';
import '../providers/vault_provider.dart';
import '../utils/password_security.dart';
import '../widgets/note_form_sheet.dart';
import '../widgets/password_hint_row.dart';
import 'change_master_pin_screen.dart';

/// Tela principal que mostra as notas do cofre.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, Note note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir entrada?'),
        content: Text('Remover “${note.title}” do cofre?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await context.read<VaultProvider>().deleteNote(note.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entrada removida.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final vault = context.watch<VaultProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu cofre'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Mais opções',
            onSelected: (value) {
              if (value == 'change_pin') {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const ChangeMasterPinScreen(),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'change_pin',
                child: Row(
                  children: [
                    Icon(Icons.pin_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Alterar PIN mestre'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: vault.notes.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.note_alt_outlined,
                          size: 72,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma nota ainda.',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Use o botão + para adicionar credenciais ou notas.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: vault.notes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final Note note = vault.notes[index];
                        return _NoteCard(
                          note: note,
                          onEdit: () => showNoteFormSheet(context, existing: note),
                          onDelete: () => _confirmDelete(context, note),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showNoteFormSheet(context),
        tooltip: 'Adicionar',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NoteCard extends StatefulWidget {
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final Note note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  bool _isOpen = false;
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final vault = context.watch<VaultProvider>();

    final reusedElsewhere = note.password.trim().isNotEmpty &&
        vault.isPasswordReusedElsewhere(
          note.password,
          excludeNoteId: note.id,
        );
    final pwdAnalysis = note.password.trim().isEmpty
        ? null
        : analyzeVaultPassword(
            password: note.password,
            reusedElsewhere: reusedElsewhere,
          );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => setState(() => _isOpen = !_isOpen),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
                bottom: Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Icon(
                      _isOpen ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white54,
                    ),
                  ],
                ),
              ),
            ),
            if (_isOpen) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      tooltip: 'Editar',
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: widget.onEdit,
                    ),
                    IconButton(
                      tooltip: 'Excluir',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: widget.onDelete,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (note.username.trim().isNotEmpty) ...[
                      Text(
                        'Usuário',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      SelectableText(
                        note.username.trim(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (note.password.trim().isNotEmpty) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Senha',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.45),
                                  ),
                                ),
                                Text(
                                  _showPassword
                                      ? note.password
                                      : '•' * note.password.length,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip:
                                _showPassword ? 'Ocultar senha' : 'Mostrar senha',
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                          ),
                          IconButton(
                            tooltip: 'Copiar senha',
                            icon: const Icon(Icons.copy_outlined),
                            onPressed: () async {
                              await Clipboard.setData(
                                ClipboardData(text: note.password),
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Senha copiada.'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      if (pwdAnalysis != null)
                        PasswordHintRow(analysis: pwdAnalysis),
                      const SizedBox(height: 8),
                    ],
                    if (note.content.trim().isNotEmpty) ...[
                      Text(
                        'Observações',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        note.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (note.username.trim().isEmpty &&
                        note.password.trim().isEmpty &&
                        note.content.trim().isEmpty)
                      const Text(
                        '(sem detalhes)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white38,
                        ),
                      ),
                    Text(
                      'Criada em ${note.createdAt.day.toString().padLeft(2, '0')}/'
                      '${note.createdAt.month.toString().padLeft(2, '0')}/'
                      '${note.createdAt.year}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  'Conteúdo oculto — toque para abrir',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
