import 'package:flutter/material.dart';

import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../domain/services/search_service.dart';

/// Central application state: the loaded library, the local reading progress
/// and the derived search service.
///
/// A single [ChangeNotifier] is enough for this project size and keeps the
/// dependency graph small; every screen listens through [AppScope].
class AppState extends ChangeNotifier {
  AppState({
    required this.library,
    required ReadingProgress progress,
    required ProgressRepository progressRepository,
  })  : _progress = progress,
        _progressRepository = progressRepository {
    search = SearchService(library);
  }

  final Library library;
  final ProgressRepository _progressRepository;
  late final SearchService search;

  ReadingProgress _progress;

  ReadingProgress get progress => _progress;

  // ---------------------------------------------------------------- theme ---

  ThemeMode get themeMode {
    switch (_progress.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  double get textScale => _progress.textScale;

  bool isDark(BuildContext context) {
    final mode = _progress.themeMode;
    if (mode == AppThemeMode.dark) {
      return true;
    }
    if (mode == AppThemeMode.light) {
      return false;
    }
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    _progress.themeMode = mode;
    notifyListeners();
    await _persist();
  }

  Future<void> setTextScale(double scale) async {
    _progress.textScale = scale.clamp(MinTextScale, MaxTextScale);
    notifyListeners();
    await _persist();
  }

  static const double MinTextScale = 0.9;
  static const double MaxTextScale = 1.5;

  // ------------------------------------------------------------- progress ---

  bool isFavorite(String id) => _progress.isFavorite(id);

  bool isRead(String id) => _progress.isRead(id);

  String? get lastReadUnitId => _progress.lastUnitId;

  LearningUnit? get lastReadUnit {
    final id = _progress.lastUnitId;
    if (id == null) {
      return null;
    }
    return library.unitById(id);
  }

  int get readUnitsCount => _progress.readCount;

  int get totalUnits => library.units.length;

  double get overallProgress {
    if (totalUnits == 0) {
      return 0;
    }
    return (readUnitsCount / totalUnits).clamp(0.0, 1.0);
  }

  double sectionProgress(String sectionId) {
    final units = library.unitsOf(sectionId);
    if (units.isEmpty) {
      return 0;
    }
    final read = units.where((unit) => _progress.isRead(unit.id)).length;
    return read / units.length;
  }

  int sectionReadCount(String sectionId) {
    return library.unitsOf(sectionId).where((unit) => _progress.isRead(unit.id)).length;
  }

  List<LearningUnit> get favoriteUnits {
    return library.units.where((unit) => _progress.isFavorite(unit.id)).toList(growable: false);
  }

  List<LessonPlan> get favoriteLessons {
    return library.lessons.where((lesson) => _progress.isFavorite(lesson.id)).toList(growable: false);
  }

  Future<void> toggleFavorite(String id) async {
    if (!_progress.favorites.remove(id)) {
      _progress.favorites.add(id);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> markRead(String id, {bool read = true}) async {
    if (read) {
      _progress.readUnits.add(id);
    } else {
      _progress.readUnits.remove(id);
    }
    _progress.lastUnitId = id;
    notifyListeners();
    await _persist();
  }

  Future<void> setLastRead(String id) async {
    if (_progress.lastUnitId == id) {
      return;
    }
    _progress.lastUnitId = id;
    notifyListeners();
    await _persist();
  }

  double scrollOffsetOf(String id) => _progress.scrollOffsets[id] ?? 0;

  Future<void> saveScrollOffset(String id, double offset) async {
    if (offset <= 0) {
      return;
    }
    _progress.scrollOffsets[id] = offset;
    await _progressRepository.save(_progress.copy());
  }

  int? quizScoreOf(String unitId) => _progress.quizScores[unitId];

  Future<void> recordQuizScore(String unitId, int score) async {
    final previous = _progress.quizScores[unitId] ?? -1;
    if (score > previous) {
      _progress.quizScores[unitId] = score;
      notifyListeners();
      await _persist();
    }
  }

  Future<void> resetProgress() async {
    _progress = ReadingProgress();
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() => _progressRepository.save(_progress.copy());

  /// Feed used by the "share/copy" action: a self-contained text of one unit.
  String shareTextOfUnit(LearningUnit unit) {
    final buffer = StringBuffer()
      ..writeln(unit.title)
      ..writeln(unit.grade)
      ..writeln();
    for (final topic in unit.topics) {
      buffer.writeln('• ${topic.title}');
      for (final bullet in topic.bullets) {
        buffer.writeln('  - $bullet');
      }
      for (final item in topic.listItems) {
        buffer.writeln('  - $item');
      }
      buffer.writeln();
    }
    buffer
      ..writeln('من تطبيق مِرسم — التربية الفنية للمرحلة المتوسطة.')
      ..writeln('المصدر: ملخص التربية الفنية (دليل معلم التربية الفنية للمرحلة المتوسطة).');
    return buffer.toString();
  }
}

/// Makes [AppState] available to the widget tree and rebuilds on change.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to changes (for callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope was not found in the widget tree');
    return scope!.notifier!;
  }
}
