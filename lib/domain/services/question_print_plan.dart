import '../../core/utils/arabic_text.dart';
import '../models/library.dart';

/// The order used both in each unit's on-screen list and in the printed paper.
const List<QuestionKind> printableQuestionKinds = <QuestionKind>[
  QuestionKind.trueFalse,
  QuestionKind.choice,
  QuestionKind.open,
];

extension PrintableQuestionKind on QuestionKind {
  String get printHeading => switch (this) {
        QuestionKind.trueFalse => 'الصح والخطأ',
        QuestionKind.choice => 'الاختيارات',
        QuestionKind.open => 'التعداد',
      };
}

/// Units with questions, in curriculum order. Keep different grade sections in
/// their original order, and sort units within each section by unit number.
List<LearningUnit> printableUnits(Iterable<LearningUnit> units) {
  final result = units.where((unit) => unit.questions.isNotEmpty).toList();
  final sectionOrder = <String, int>{};
  final originalOrder = <String, int>{};
  for (var i = 0; i < result.length; i++) {
    sectionOrder.putIfAbsent(result[i].sectionId, () => sectionOrder.length);
    originalOrder[result[i].id] = i;
  }
  result.sort((LearningUnit a, LearningUnit b) {
    final section = sectionOrder[a.sectionId]!.compareTo(sectionOrder[b.sectionId]!);
    if (section != 0) {
      return section;
    }
    final order = a.order.compareTo(b.order);
    return order != 0 ? order : originalOrder[a.id]!.compareTo(originalOrder[b.id]!);
  });
  return List<LearningUnit>.unmodifiable(result);
}

/// Questions of a particular kind, in their original order within the unit.
List<Question> questionsOfKind(LearningUnit unit, QuestionKind kind) =>
    unit.questions.where((question) => question.kind == kind).toList(growable: false);

class QuestionPrintUnitGroup {
  QuestionPrintUnitGroup(this.unit, Iterable<Question> questions)
      : questions = List<Question>.unmodifiable(questions);

  final LearningUnit unit;
  final List<Question> questions;
}

class QuestionPrintSection {
  QuestionPrintSection(this.kind, Iterable<QuestionPrintUnitGroup> groups)
      : groups = List<QuestionPrintUnitGroup>.unmodifiable(groups);

  final QuestionKind kind;
  final List<QuestionPrintUnitGroup> groups;
}

/// An immutable snapshot of a selection, grouped by kind first, then by unit.
/// It deliberately carries only the selected units into the print pipeline.
class QuestionPrintPlan {
  factory QuestionPrintPlan.fromSelection(
    Iterable<LearningUnit> availableUnits,
    Set<String> selectedIds,
  ) {
    final units = printableUnits(availableUnits)
        .where((LearningUnit unit) => selectedIds.contains(unit.id))
        .toList(growable: false);
    final sections = <QuestionPrintSection>[];
    for (final kind in printableQuestionKinds) {
      final groups = <QuestionPrintUnitGroup>[];
      for (final unit in units) {
        final questions = questionsOfKind(unit, kind);
        if (questions.isNotEmpty) {
          groups.add(QuestionPrintUnitGroup(unit, questions));
        }
      }
      if (groups.isNotEmpty) {
        sections.add(QuestionPrintSection(kind, groups));
      }
    }
    return QuestionPrintPlan._(units, sections);
  }

  QuestionPrintPlan._(Iterable<LearningUnit> units, Iterable<QuestionPrintSection> sections)
      : units = List<LearningUnit>.unmodifiable(units),
        sections = List<QuestionPrintSection>.unmodifiable(sections);

  final List<LearningUnit> units;
  final List<QuestionPrintSection> sections;

  bool get isEmpty => sections.isEmpty;

  int get questionCount => units.fold<int>(0, (sum, unit) => sum + unit.questions.length);
}

/// A compact, answer-free question line. Choice options are preserved, but no
/// correct answer, explanation, or previously selected quiz response is used.
String formatPrintableQuestion(Question question, int number) {
  final prompt = '${toArabicDigits('$number')}. ${question.prompt}';
  switch (question.kind) {
    case QuestionKind.trueFalse:
      return '$prompt  (     )';
    case QuestionKind.choice:
      final options = <String>[
        for (var i = 0; i < question.options.length; i++)
          '(${_choiceLabel(i)}) ${question.options[i]}',
      ];
      return options.isEmpty ? prompt : '$prompt  ${options.join('   ')}';
    case QuestionKind.open:
      return prompt;
  }
}

String _choiceLabel(int index) {
  const letters = <String>['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح'];
  return index < letters.length ? letters[index] : toArabicDigits('${index + 1}');
}
