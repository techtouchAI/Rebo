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
    search = SearchService(
      library,
      unitFilter: progress.gradeId == null ? null : _unitIdsOf(library, progress.gradeId!),
    );
  }

  static Set<String> _unitIdsOf(Library library, String gradeId) {
    return library.unitsOf(gradeId).map((LearningUnit unit) => unit.id).toSet();
  }

  final Library library;
  final ProgressRepository _progressRepository;
  late SearchService search;

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

  // ---------------------------------------------------------------- grade ---

  /// The grade chosen on first launch. Null means the picker is shown.
  String? get gradeId => _progress.gradeId;

  bool get hasGrade => _progress.gradeId != null;

  ContentSection? get gradeSection {
    final id = _progress.gradeId;
    if (id == null) {
      return null;
    }
    for (final section in library.sections) {
      if (section.kind == 'grade' && section.id == id) {
        return section;
      }
    }
    return null;
  }

  /// The three grade sections offered by the picker.
  List<ContentSection> get gradeSections {
    return library.sections.where((section) => section.kind == 'grade').toList(growable: false);
  }

  String get gradeTitle => gradeSection?.title ?? 'كل الصفوف';

  /// Units of the selected grade only; everything else stays out of the UI.
  List<LearningUnit> get visibleUnits {
    final id = _progress.gradeId;
    if (id == null) {
      return library.units;
    }
    return library.unitsOf(id);
  }

  /// Ids of every unit the learner may open: the chosen grade plus the shared
  /// introduction that the home and index pages keep visible.
  Set<String> get visibleUnitIds {
    final ids = visibleUnits.map((unit) => unit.id).toSet();
    if (gradeSection != null) {
      ids.addAll(library.unitsOf('intro').map((unit) => unit.id));
    }
    return ids;
  }

  /// Previous / next order limited to the material the learner can see.
  List<String> get visibleReadingOrder {
    final ids = <String>[];
    for (final section in visibleSections) {
      if (section.kind == 'grade' || section.kind == 'intro') {
        for (final unit in library.unitsOf(section.id)) {
          ids.add(unit.id);
        }
      }
    }
    return ids;
  }

  /// Sections shown in the index: the chosen grade, then the shared material.
  List<ContentSection> get visibleSections {
    final section = gradeSection;
    final result = <ContentSection>[
      ...library.sections.where((item) => item.kind == 'intro'),
      if (section != null) section,
      ...library.sections.where((item) => item.kind == 'lessons' || item.kind == 'plates'),
    ];
    return result;
  }

  /// General introduction, always reachable from the home page.
  LearningUnit? get introductionUnit {
    for (final unit in library.units) {
      if (unit.isIntroduction) {
        return unit;
      }
    }
    return null;
  }

  List<Plate> get visiblePlates {
    final id = _progress.gradeId;
    if (id == null) {
      return library.plates;
    }
    // Plates belong to grade units; the shared appendix plates (not tied to a
    // grade unit) stay available for every grade.
    final gradeUnitIds = library.units
        .where((LearningUnit unit) => !unit.isIntroduction)
        .map((LearningUnit unit) => unit.id)
        .toSet();
    final visible = visibleUnitIds;
    return library.plates
        .where((plate) => visible.contains(plate.unitId) || !gradeUnitIds.contains(plate.unitId))
        .toList(growable: false);
  }

  List<GlossaryTerm> get visibleGlossary {
    final id = _progress.gradeId;
    if (id == null) {
      return library.glossary;
    }
    return library.glossary.where((term) => visibleUnitIds.contains(term.unitId)).toList(growable: false);
  }

  Future<void> setGrade(String? gradeId) async {
    _progress.gradeId = gradeId;
    search = SearchService(
      library,
      unitFilter: gradeId == null ? null : _unitIdsOf(library, gradeId),
    );
    notifyListeners();
    await _persist();
  }

  // ------------------------------------------------------------- progress ---

  bool isFavorite(String id) => _progress.isFavorite(id);

  bool isRead(String id) => _progress.isRead(id);

  String? get lastReadUnitId => _progress.lastUnitId;

  /// Last unit opened, as long as it still belongs to the chosen grade.
  LearningUnit? get lastReadUnit {
    final id = _progress.lastUnitId;
    if (id == null) {
      return null;
    }
    final unit = library.unitById(id);
    if (unit == null) {
      return null;
    }
    return visibleUnitIds.contains(unit.id) ? unit : null;
  }

  /// Read units inside the visible material only.
  int get readUnitsCount => visibleUnits.where((unit) => _progress.isRead(unit.id)).length;

  int get totalUnits => visibleUnits.length;

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
    return visibleUnits.where((unit) => _progress.isFavorite(unit.id)).toList(growable: false);
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
    // The chosen grade is a display setting, not reading data: keep it so the
    // learner is not pushed back to the picker.
    _progress = ReadingProgress(gradeId: _progress.gradeId);
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
