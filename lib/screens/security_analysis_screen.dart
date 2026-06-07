import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';

import '../models/security_analysis.dart';
import '../providers/vault_provider.dart';
import '../services/ai_security_service.dart';

/// Tela de análise de segurança das senhas com IA (GROQ / LLaMA).
///
/// Envia apenas metadados das senhas — tamanho, diversidade de caracteres,
/// reutilização e antiguidade. Nenhuma senha em texto puro é transmitida.
class SecurityAnalysisScreen extends StatefulWidget {
  const SecurityAnalysisScreen({super.key});

  @override
  State<SecurityAnalysisScreen> createState() => _SecurityAnalysisScreenState();
}

enum _AnalysisState { initial, loading, result }

class _SecurityAnalysisScreenState extends State<SecurityAnalysisScreen> {
  static const _kApiKeyStorageKey = 'noxvault_groq_api_key';
  static const _storage = FlutterSecureStorage();

  _AnalysisState _state = _AnalysisState.initial;
  SecurityAnalysis? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise de Segurança'),
        actions: [
          if (_state != _AnalysisState.loading)
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              onSelected: (value) {
                if (value == 'reset_key') _resetApiKey();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'reset_key',
                  child: Row(
                    children: [
                      Icon(Icons.key_off_outlined, size: 20),
                      SizedBox(width: 12),
                      Text('Redefinir chave de API'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: switch (_state) {
          _AnalysisState.initial => _buildInitialView(),
          _AnalysisState.loading => _buildLoadingView(),
          _AnalysisState.result => _buildResultView(_result!),
        },
      ),
    );
  }

  // ── Views ──────────────────────────────────────────────────────────────────

  Widget _buildInitialView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.security_outlined,
              size: 80,
              color: Colors.white24,
            ),
            const SizedBox(height: 24),
            Text(
              'Análise de Segurança com IA',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'A IA analisa metadados das suas senhas — '
              'tamanho, variedade de caracteres, reutilização e tempo de uso. '
              'Nenhuma senha é enviada em texto puro.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, height: 1.5),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _analyze,
              icon: const Icon(Icons.analytics_outlined),
              label: const Text('Analisar minhas senhas'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text('Analisando senhas...', style: TextStyle(fontSize: 16)),
          SizedBox(height: 8),
          Text(
            'Isso pode levar alguns segundos.',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildResultView(SecurityAnalysis analysis) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Score circular ─────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: analysis.scoreColor.withValues(alpha: 0.12),
                    border: Border.all(color: analysis.scoreColor, width: 4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${analysis.score}',
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.bold,
                          color: analysis.scoreColor,
                        ),
                      ),
                      Text(
                        analysis.nivel,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: analysis.scoreColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  analysis.resumo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Estatísticas ───────────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                label: 'Total',
                value: analysis.totalPasswords,
                color: Colors.blueGrey,
              ),
              _StatChip(
                label: 'Reutilizadas',
                value: analysis.reusedCount,
                color: Colors.orange,
              ),
              _StatChip(
                label: 'Fracas',
                value: analysis.weakCount,
                color: Colors.red,
              ),
              _StatChip(
                label: 'Antigas',
                value: analysis.oldCount,
                color: Colors.grey,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ── Alertas ────────────────────────────────────────────────────────
          if (analysis.alertas.isNotEmpty) ...[
            _InfoCard(
              title: 'Alertas',
              items: analysis.alertas,
              icon: Icons.warning_amber_rounded,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
          ],

          // ── Sugestões ──────────────────────────────────────────────────────
          if (analysis.sugestoes.isNotEmpty) ...[
            _InfoCard(
              title: 'Sugestões',
              items: analysis.sugestoes,
              icon: Icons.lightbulb_outline,
              color: Colors.blue,
            ),
            const SizedBox(height: 12),
          ],

          // ── Destaques positivos ────────────────────────────────────────────
          if (analysis.destaquesPositivos.isNotEmpty) ...[
            _InfoCard(
              title: 'Destaques Positivos',
              items: analysis.destaquesPositivos,
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
          ],

          // ── Analisar novamente ─────────────────────────────────────────────
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _state = _AnalysisState.initial;
              _result = null;
            }),
            icon: const Icon(Icons.refresh),
            label: const Text('Analisar novamente'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Lógica de análise ──────────────────────────────────────────────────────

  Future<void> _analyze() async {
    // Captura notes ANTES de qualquer await para evitar uso de context
    // após gap assíncrono (causa: _dependents.isEmpty assertion).
    final notes = context.read<VaultProvider>().notes;

    final apiKey = await _getOrRequestApiKey();
    if (apiKey == null || apiKey.isEmpty) return;

    if (!mounted) return;
    setState(() => _state = _AnalysisState.loading);

    try {
      final service = AISecurityService(apiKey: apiKey);
      final result = await service.analyzePasswords(notes);

      if (!mounted) return;
      setState(() {
        _result = result;
        _state = _AnalysisState.result;
      });
    } on AISecurityException catch (e) {
      if (!mounted) return;
      setState(() => _state = _AnalysisState.initial);
      _showError(_friendlyMessage(e));
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _AnalysisState.initial);
      _showError('Erro inesperado. Tente novamente.');
    }
  }

  // ── Gerenciamento da API Key ───────────────────────────────────────────────

  /// Tenta obter a chave em ordem: variável de ambiente → storage → diálogo.
  Future<String?> _getOrRequestApiKey() async {
    // Variável de ambiente definida em tempo de compilação:
    // flutter run --dart-define=GROQ_API_KEY=sua_chave
    const envKey = String.fromEnvironment('GROQ_API_KEY');
    if (envKey.isNotEmpty) return envKey;

    final stored = await _storage.read(key: _kApiKeyStorageKey);
    if (stored != null && stored.isNotEmpty) return stored;

    if (!mounted) return null;
    return _showApiKeyDialog();
  }

  Future<String?> _showApiKeyDialog() async {
    final controller = TextEditingController();
    String? fieldError;

    final key = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Configurar API GROQ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informe sua chave da API GROQ para ativar '
                'a análise de segurança com IA. A chave é salva de '
                'forma criptografada no dispositivo.',
                style: TextStyle(color: Colors.white70, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: 'gsk_...',
                  errorText: fieldError,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => _submitKey(
                  ctx,
                  controller,
                  (err) => setDialogState(() => fieldError = err),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => _submitKey(
                ctx,
                controller,
                (err) => setDialogState(() => fieldError = err),
              ),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();

    if (key != null && key.isNotEmpty) {
      await _storage.write(key: _kApiKeyStorageKey, value: key);
    }

    return key;
  }

  void _submitKey(
    BuildContext ctx,
    TextEditingController controller,
    void Function(String?) setError,
  ) {
    final value = controller.text.trim();
    if (value.isEmpty) {
      setError('Insira a chave de API');
    } else if (!value.startsWith('gsk_') || value.length < 20) {
      setError('Chave inválida. Chaves da GROQ começam com "gsk_".');
    } else {
      Navigator.pop(ctx, value);
    }
  }

  Future<void> _resetApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redefinir chave GROQ?'),
        content: const Text(
          'A chave salva será removida. Você poderá inserir uma nova '
          'na próxima análise.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redefinir'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _storage.delete(key: _kApiKeyStorageKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chave de API removida.')),
        );
        // Volta ao estado inicial para nova configuração
        setState(() {
          _state = _AnalysisState.initial;
          _result = null;
        });
      }
    }
  }

  // ── Utilitários ────────────────────────────────────────────────────────────

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyMessage(AISecurityException e) {
    return switch (e.type) {
      AISecurityErrorType.noInternet =>
        'Sem conexão com a internet. Verifique sua rede e tente novamente.',
      AISecurityErrorType.invalidApiKey =>
        'Chave de API inválida. Redefina-a pelo menu e tente novamente.',
      AISecurityErrorType.timeout =>
        'A análise demorou muito. Verifique sua conexão e tente novamente.',
      AISecurityErrorType.invalidResponse =>
        'Resposta inesperada da IA. Tente novamente em alguns instantes.',
      AISecurityErrorType.noPasswordsFound =>
        'Nenhuma entrada com senha encontrada no cofre para analisar.',
      AISecurityErrorType.unknown => e.message,
    };
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Card de estatística numérica (total, reutilizadas, fracas, antigas).
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white54),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de lista de itens com ícone e cor temática (alertas, sugestões, destaques).
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.items,
    required this.icon,
    required this.color,
  });

  final String title;
  final List<String> items;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
