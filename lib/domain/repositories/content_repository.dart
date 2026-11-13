import '../models/library.dart';

/// Source of the offline curriculum content.
abstract class ContentRepository {
  Future<Library> load();
}
