import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/exam_question_bank.dart';
import '../../domain/repositories/exam_question_bank_repository.dart';

/// Keeps the saved question groups as one JSON list in shared preferences.
class PrefsExamQuestionBankRepository implements ExamQuestionBankRepository {
  const PrefsExamQuestionBankRepository();

  static const String storageKey = 'mirsam.exam-question-bank.v1';

  /// The bank is a convenience store, not an archive: older groups are dropped
  /// so Start-up never parses an unbounded document.
  static const int maxEntries = 20;

  @override
  Future<List<ExamQuestionBankEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return <ExamQuestionBankEntry>[];
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <ExamQuestionBankEntry>[];
      }
      return <ExamQuestionBankEntry>[
        for (final dynamic item in decoded)
          if (item is Map<String, dynamic>) ExamQuestionBankEntry.fromJson(item),
      ];
    } on FormatException {
      return <ExamQuestionBankEntry>[];
    }
  }

  @override
  Future<void> save(List<ExamQuestionBankEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = entries.take(maxEntries).toList(growable: false);
    await prefs.setString(
      storageKey,
      jsonEncode(<Map<String, dynamic>>[
        for (final ExamQuestionBankEntry entry in trimmed) entry.toJson(),
      ]),
    );
  }
}
