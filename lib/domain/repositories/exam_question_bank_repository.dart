/// Storage contract of the saved question groups.
library;

import '../models/exam_question_bank.dart';

abstract interface class ExamQuestionBankRepository {
  /// Saved groups, newest first.
  Future<List<ExamQuestionBankEntry>> load();

  /// Replaces the whole bank; the list stays small (the last groups only).
  Future<void> save(List<ExamQuestionBankEntry> entries);
}
