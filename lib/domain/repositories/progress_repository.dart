import '../models/progress.dart';

/// Persistence of the local reading state.
abstract class ProgressRepository {
  Future<ReadingProgress> load();

  Future<void> save(ReadingProgress progress);
}
