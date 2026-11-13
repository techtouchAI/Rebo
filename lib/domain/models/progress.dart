/// Local reading state of the learner. Pure Dart so it can be tested without
/// Flutter bindings and serialised to `shared_preferences`.
library;

enum AppThemeMode {
  system,
  light,
  dark;

  static AppThemeMode parse(String? value) {
    switch (value) {
      case 'light':
        return AppThemeMode.light;
      case 'dark':
        return AppThemeMode.dark;
      default:
        return AppThemeMode.system;
    }
  }
}

class ReadingProgress {
  ReadingProgress({
    Set<String>? favorites,
    Set<String>? readUnits,
    this.lastUnitId,
    Map<String, double>? scrollOffsets,
    Map<String, int>? quizScores,
    this.themeMode = AppThemeMode.system,
    this.textScale = 1.0,
    this.gradeId,
  })  : favorites = favorites ?? <String>{},
        readUnits = readUnits ?? <String>{},
        scrollOffsets = scrollOffsets ?? <String, double>{},
        quizScores = quizScores ?? <String, int>{};

  final Set<String> favorites;
  final Set<String> readUnits;
  String? lastUnitId;
  final Map<String, double> scrollOffsets;
  final Map<String, int> quizScores;
  AppThemeMode themeMode;
  double textScale;

  /// The grade chosen on first launch (`g1`, `g2`, `g3`); null shows the picker.
  String? gradeId;

  bool isFavorite(String id) => favorites.contains(id);
  bool isRead(String id) => readUnits.contains(id);

  int get readCount => readUnits.length;

  ReadingProgress copy() {
    return ReadingProgress(
      favorites: Set<String>.from(favorites),
      readUnits: Set<String>.from(readUnits),
      lastUnitId: lastUnitId,
      scrollOffsets: Map<String, double>.from(scrollOffsets),
      quizScores: Map<String, int>.from(quizScores),
      themeMode: themeMode,
      textScale: textScale,
      gradeId: gradeId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'favorites': favorites.toList(),
      'readUnits': readUnits.toList(),
      'lastUnitId': lastUnitId,
      'scrollOffsets': scrollOffsets,
      'quizScores': quizScores,
      'themeMode': themeMode.name,
      'textScale': textScale,
      'gradeId': gradeId,
    };
  }

  static ReadingProgress fromJson(Map<String, dynamic> json) {
    return ReadingProgress(
      favorites: _stringSet(json['favorites']),
      readUnits: _stringSet(json['readUnits']),
      lastUnitId: json['lastUnitId'] as String?,
      scrollOffsets: _doubleMap(json['scrollOffsets']),
      quizScores: _intMap(json['quizScores']),
      themeMode: AppThemeMode.parse(json['themeMode'] as String?),
      textScale: (json['textScale'] as num?)?.toDouble() ?? 1.0,
      gradeId: json['gradeId'] as String?,
    );
  }

  static Set<String> _stringSet(Object? value) {
    if (value is! List) {
      return <String>{};
    }
    return value.whereType<String>().toSet();
  }

  static Map<String, double> _doubleMap(Object? value) {
    if (value is! Map) {
      return <String, double>{};
    }
    final result = <String, double>{};
    value.forEach((key, item) {
      if (key is String && item is num) {
        result[key] = item.toDouble();
      }
    });
    return result;
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) {
      return <String, int>{};
    }
    final result = <String, int>{};
    value.forEach((key, item) {
      if (key is String && item is num) {
        result[key] = item.toInt();
      }
    });
    return result;
  }
}
