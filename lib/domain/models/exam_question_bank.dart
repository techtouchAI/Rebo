/// A group of questions the teacher built in the composer and kept, so the
/// same paper can be reopened later without choosing everything again.
library;

import 'exam_paper.dart';

/// Everything needed to restore a saved selection.
///
/// The questions themselves are content of the curriculum, so only their ids
/// are kept: the bank stays small and always shows the current wording of the
/// source file instead of a stale copy.
class ExamQuestionBankEntry {
  const ExamQuestionBankEntry({
    required this.id,
    required this.title,
    required this.savedAt,
    this.selection = const <String, List<String>>{},
    this.practicalPrompts = const <String>[],
    this.theoryDegree = ExamQuestionBankEntry.defaultTheoryDegree,
    this.practicalDegree = ExamQuestionBankEntry.defaultPracticalDegree,
    this.theoryHeader = ExamPaper.defaultTheoryHeader,
    this.practicalHeader = ExamPaper.defaultPracticalHeader,
  });

  static const int defaultTheoryDegree = 30;
  static const int defaultPracticalDegree = 70;

  /// Unique key of the entry.
  final String id;

  /// What the teacher sees in the list, e.g. the grade and the date.
  final String title;
  final DateTime savedAt;

  /// Selected option ids per question kind (`trueFalse`, `choice`, `open`).
  final Map<String, List<String>> selection;

  /// The practical questions, in the order they were written.
  final List<String> practicalPrompts;

  final int theoryDegree;
  final int practicalDegree;
  final String theoryHeader;
  final String practicalHeader;

  int get itemCount =>
      selection.values.fold<int>(0, (int sum, List<String> ids) => sum + ids.length) +
      practicalPrompts.where((String prompt) => prompt.trim().isNotEmpty).length;

  bool get isEmpty => itemCount == 0;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'savedAt': savedAt.toIso8601String(),
      'selection': <String, dynamic>{
        for (final MapEntry<String, List<String>> entry in selection.entries)
          entry.key: entry.value,
      },
      'practicalPrompts': practicalPrompts,
      'theoryDegree': theoryDegree,
      'practicalDegree': practicalDegree,
      'theoryHeader': theoryHeader,
      'practicalHeader': practicalHeader,
    };
  }

  factory ExamQuestionBankEntry.fromJson(Map<String, dynamic> json) {
    final selection = <String, List<String>>{};
    final rawSelection = json['selection'];
    if (rawSelection is Map) {
      for (final MapEntry<dynamic, dynamic> entry in rawSelection.entries) {
        final key = '${entry.key}';
        final value = entry.value;
        if (value is List) {
          selection[key] = <String>[
            for (final dynamic id in value)
              if (id is String && id.isNotEmpty) id,
          ];
        }
      }
    }
    return ExamQuestionBankEntry(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      savedAt: DateTime.tryParse('${json['savedAt'] ?? ''}') ?? DateTime.now(),
      selection: selection,
      practicalPrompts: <String>[
        for (final dynamic prompt in (json['practicalPrompts'] as List<dynamic>? ?? const <dynamic>[]))
          if (prompt is String) prompt,
      ],
      theoryDegree: (json['theoryDegree'] as num?)?.toInt() ?? defaultTheoryDegree,
      practicalDegree: (json['practicalDegree'] as num?)?.toInt() ?? defaultPracticalDegree,
      theoryHeader: json['theoryHeader'] as String? ?? ExamPaper.defaultTheoryHeader,
      practicalHeader: json['practicalHeader'] as String? ?? ExamPaper.defaultPracticalHeader,
    );
  }
}
