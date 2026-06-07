import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../models/note.dart';
import '../models/security_analysis.dart';

/// Tipos de falha possíveis durante a análise com IA.
enum AISecurityErrorType {
  noInternet,
  invalidApiKey,
  timeout,
  invalidResponse,
  noPasswordsFound,
  unknown,
}

/// Exceção lançada pelo [AISecurityService] em situações de erro controlado.
class AISecurityException implements Exception {
  final AISecurityErrorType type;
  final String message;

  const AISecurityException(this.type, this.message);

  @override
  String toString() => 'AISecurityException(${type.name}): $message';
}

/// Analisa a segurança das senhas do cofre via GROQ API (LLaMA).
///
/// SEGURANÇA: Somente metadados (tamanho, tipos de caractere, reutilização,
/// antiguidade) são transmitidos. Nenhuma senha em texto puro é enviada à API.
class AISecurityService {
  static const _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'llama-3.3-70b-versatile';

  final String _apiKey;

  AISecurityService({required String apiKey}) : _apiKey = apiKey;

  /// Extrai metadados de [notes] e consulta a GROQ para análise de segurança.
  Future<SecurityAnalysis> analyzePasswords(List<Note> notes) async {
    await _assertConnected();

    if (_apiKey.isEmpty) {
      throw const AISecurityException(
        AISecurityErrorType.invalidApiKey,
        'Chave de API não configurada.',
      );
    }

    final notesWithPassword =
        notes.where((n) => n.password.trim().isNotEmpty).toList();

    if (notesWithPassword.isEmpty) {
      throw const AISecurityException(
        AISecurityErrorType.noPasswordsFound,
        'Nenhuma entrada com senha encontrada no cofre.',
      );
    }

    final allPasswords = notesWithPassword.map((n) => n.password).toList();

    final metadata = notesWithPassword.map((note) {
      final pwd = note.password;
      final ageDays = DateTime.now().difference(note.updatedAt).inDays;

      return <String, dynamic>{
        'site': note.title,
        'passwordLength': pwd.length,
        'hasUppercase': pwd.contains(RegExp(r'[A-Z]')),
        'hasLowercase': pwd.contains(RegExp(r'[a-z]')),
        'hasNumbers': pwd.contains(RegExp(r'[0-9]')),
        'hasSpecialChars':
            pwd.contains(RegExp(r'[!@#$%^&*()\-_=+\[\]{};:",.<>?/\\|`~]')),
        'isReused': allPasswords.where((p) => p == pwd).length > 1,
        'ageDays': ageDays,
        'startsWithCommonWord': _startsWithCommonWord(pwd),
      };
    }).toList();

    final metadataJson = const JsonEncoder.withIndent('  ').convert(metadata);

    try {
      final response = await http
          .post(
            Uri.parse(_groqEndpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'user', 'content': _buildPrompt(metadataJson)},
              ],
              'temperature': 0.3,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const AISecurityException(
          AISecurityErrorType.invalidApiKey,
          'Chave de API inválida ou sem permissão de acesso.',
        );
      }

      if (response.statusCode != 200) {
        throw AISecurityException(
          AISecurityErrorType.unknown,
          'Erro ao chamar a API: HTTP ${response.statusCode}.',
        );
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          (decoded['choices'] as List).first['message']['content'] as String;

      return _parseResponse(content);
    } on AISecurityException {
      rethrow;
    } on TimeoutException {
      throw const AISecurityException(
        AISecurityErrorType.timeout,
        'A análise ultrapassou 30 segundos. Tente novamente.',
      );
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('401') ||
          msg.contains('403') ||
          msg.contains('invalid_api_key') ||
          msg.contains('authentication')) {
        throw const AISecurityException(
          AISecurityErrorType.invalidApiKey,
          'Chave de API inválida ou sem permissão de acesso.',
        );
      }
      throw AISecurityException(
        AISecurityErrorType.unknown,
        'Erro ao chamar a API: $msg',
      );
    }
  }

  /// Verifica conectividade antes de fazer a chamada de rede.
  Future<void> _assertConnected() async {
    final results = await Connectivity().checkConnectivity();
    if (!results.any((r) => r != ConnectivityResult.none)) {
      throw const AISecurityException(
        AISecurityErrorType.noInternet,
        'Sem conexão com a internet.',
      );
    }
  }

  /// Monta o prompt enviado à GROQ com os metadados JSON das senhas.
  String _buildPrompt(String metadataJson) => '''
Você é um especialista em segurança da informação. Analise os metadados de senhas abaixo.

IMPORTANTE: Responda SOMENTE com um JSON válido. Sem markdown, sem blocos de código, sem texto extra antes ou depois.

Estrutura obrigatória do JSON de resposta:
{
  "score": <inteiro de 0 a 100 representando a segurança geral>,
  "nivel": <"Crítico" | "Fraco" | "Médio" | "Bom" | "Excelente">,
  "totalPasswords": <total de entradas analisadas>,
  "reusedCount": <quantidade com isReused=true>,
  "weakCount": <quantidade com passwordLength < 8 OU sem variedade de tipos>,
  "oldCount": <quantidade com ageDays > 180>,
  "alertas": [<até 5 strings descrevendo os principais problemas encontrados>],
  "sugestoes": [<até 5 strings com recomendações práticas e objetivas>],
  "destaquesPositivos": [<até 3 strings com pontos positivos encontrados>],
  "resumo": <string de até 20 palavras resumindo o estado geral da segurança>
}

Metadados das senhas (sem texto das senhas):
$metadataJson
''';

  /// Remove eventual marcação de markdown e faz parse do JSON da resposta.
  SecurityAnalysis _parseResponse(String raw) {
    var text = raw.trim();

    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }

    try {
      final decoded = jsonDecode(text);
      return SecurityAnalysis.fromJson(decoded as Map<String, dynamic>);
    } catch (_) {
      throw const AISecurityException(
        AISecurityErrorType.invalidResponse,
        'Resposta da IA em formato inesperado. Tente novamente.',
      );
    }
  }

  /// Verifica se a senha começa com padrões comumente fracos.
  bool _startsWithCommonWord(String password) {
    final lower = password.toLowerCase();
    const weak = [
      'senha',
      'pass',
      '123',
      'abc',
      'qwerty',
      '111',
      '000',
      'admin',
    ];
    return weak.any(lower.startsWith);
  }
}
