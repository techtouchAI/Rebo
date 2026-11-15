import '../../domain/repositories/exam_profile_repository.dart';

/// In-memory profile store used by the widget tests.
class MemoryExamProfileRepository implements ExamProfileRepository {
  MemoryExamProfileRepository([ExamProfile? initial])
      : _profile = initial ?? const ExamProfile();

  ExamProfile _profile;

  ExamProfile get profile => _profile;

  int saveCount = 0;

  @override
  Future<ExamProfile> load() async => _profile;

  @override
  Future<void> save(ExamProfile profile) async {
    _profile = profile;
    saveCount++;
  }
}
