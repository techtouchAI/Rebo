import '../../domain/models/exam_question_bank.dart';
import '../../domain/repositories/exam_question_bank_repository.dart';

/// In-memory bank used by the widget tests.
class MemoryExamQuestionBankRepository implements ExamQuestionBankRepository {
  MemoryExamQuestionBankRepository([List<ExamQuestionBankEntry>? initial])
      : _entries = List<ExamQuestionBankEntry>.of(initial ?? const <ExamQuestionBankEntry>[]);

  List<ExamQuestionBankEntry> _entries;

  List<ExamQuestionBankEntry> get entries => List<ExamQuestionBankEntry>.unmodifiable(_entries);

  int saveCount = 0;

  @override
  Future<List<ExamQuestionBankEntry>> load() async =>
      List<ExamQuestionBankEntry>.unmodifiable(_entries);

  @override
  Future<void> save(List<ExamQuestionBankEntry> entries) async {
    _entries = List<ExamQuestionBankEntry>.of(entries);
    saveCount++;
  }
}
