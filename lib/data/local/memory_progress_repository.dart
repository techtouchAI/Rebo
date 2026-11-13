import '../../domain/models/progress.dart';
import '../../domain/repositories/progress_repository.dart';

/// In-memory repository used by the widget tests.
class MemoryProgressRepository implements ProgressRepository {
  MemoryProgressRepository([ReadingProgress? initial]) : _progress = initial;

  ReadingProgress? _progress;

  int saveCount = 0;

  ReadingProgress? get lastSaved => _progress;

  @override
  Future<ReadingProgress> load() async => _progress ?? ReadingProgress();

  @override
  Future<void> save(ReadingProgress progress) async {
    _progress = progress.copy();
    saveCount++;
  }
}
