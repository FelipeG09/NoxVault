import 'package:flutter/material.dart';

/// Resultado da análise de segurança de senhas retornado pelo Gemini.
class SecurityAnalysis {
  final int score;
  final String nivel;
  final int totalPasswords;
  final int reusedCount;
  final int weakCount;
  final int oldCount;
  final List<String> alertas;
  final List<String> sugestoes;
  final List<String> destaquesPositivos;
  final String resumo;

  const SecurityAnalysis({
    required this.score,
    required this.nivel,
    required this.totalPasswords,
    required this.reusedCount,
    required this.weakCount,
    required this.oldCount,
    required this.alertas,
    required this.sugestoes,
    required this.destaquesPositivos,
    required this.resumo,
  });

  factory SecurityAnalysis.fromJson(Map<String, dynamic> json) {
    return SecurityAnalysis(
      score: (json['score'] as num).toInt(),
      nivel: json['nivel'] as String,
      totalPasswords: (json['totalPasswords'] as num).toInt(),
      reusedCount: (json['reusedCount'] as num).toInt(),
      weakCount: (json['weakCount'] as num).toInt(),
      oldCount: (json['oldCount'] as num).toInt(),
      alertas: List<String>.from(json['alertas'] as List? ?? []),
      sugestoes: List<String>.from(json['sugestoes'] as List? ?? []),
      destaquesPositivos:
          List<String>.from(json['destaquesPositivos'] as List? ?? []),
      resumo: json['resumo'] as String? ?? '',
    );
  }

  /// Cor correspondente ao score: vermelho (≤30), laranja (≤60), âmbar (≤80), verde (>80).
  Color get scoreColor {
    if (score <= 30) return Colors.red;
    if (score <= 60) return Colors.orange;
    if (score <= 80) return Colors.amber;
    return Colors.green;
  }
}
