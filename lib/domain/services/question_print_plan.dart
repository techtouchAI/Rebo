import '../../core/utils/arabic_text.dart';
import '../models/library.dart';
import '../models/question_print_settings.dart';

/// The order in which question types appear on the printed paper.
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
    Set<String> selectedIds, {
    QuestionPrintSettings settings = const QuestionPrintSettings(),
  }) {
    final units = printableUnits(
      availableUnits,
    ).where((LearningUnit unit) => selectedIds.contains(unit.id)).toList(growable: false);
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
    return QuestionPrintPlan._(units, sections, settings);
  }

  QuestionPrintPlan._(
    Iterable<LearningUnit> units,
    Iterable<QuestionPrintSection> sections,
    this.settings,
  ) : units = List<LearningUnit>.unmodifiable(units),
      sections = List<QuestionPrintSection>.unmodifiable(sections);

  final List<LearningUnit> units;
  final List<QuestionPrintSection> sections;
  final QuestionPrintSettings settings;

  bool get isEmpty => sections.isEmpty;

  int get questionCount => units.fold<int>(0, (sum, unit) => sum + unit.questions.length);
}

/// A question with its documented answer, independent of quiz responses.
/// Missing or invalid answers are identified explicitly rather than guessed.
String formatPrintableQuestion(Question question, int number) {
  final prompt = '${toArabicDigits('$number')}. ${question.prompt}';
  switch (question.kind) {
    case QuestionKind.trueFalse:
      final answer = switch (question.boolAnswer) {
        true => 'صح',
        false => 'خطأ',
        null => _missingAnswer,
      };
      final correction = question.boolAnswer == false ? question.answerSupport?.trim() : null;
      final detail = correction == null || correction.isEmpty ? '' : '  التصحيح: $correction';
      return '$prompt  الإجابة: $answer$detail';
    case QuestionKind.choice:
      final options = <String>[
        for (var i = 0; i < question.options.length; i++)
          '(${_choiceLabel(i)}) ${question.options[i]}',
      ];
      final index = question.answerIndex;
      final answer = index == null || index < 0 || index >= question.options.length
          ? _missingAnswer
          : '(${_choiceLabel(index)}) ${question.options[index]}';
      final choices = options.isEmpty ? '' : '  ${options.join('   ')}';
      return '$prompt$choices  الإجابة: $answer';
    case QuestionKind.open:
      return '$prompt  الإجابة: ${_formatEnumeration(question.textAnswer)}';
  }
}

const String _missingAnswer = 'غير متوفرة في المصدر';

/// Source enumeration answers are normally numbered on separate lines. Lay
/// them out inline, with consecutive Arabic-Indic numbers, while retaining the
/// wording of each item. Also accepts future unnumbered or CRLF-separated
/// answers and does not invent an answer when the source is empty.
String _formatEnumeration(String? answer) {
  final prefix = RegExp(r'^[0-9٠-٩۰-۹]{1,3}\s*[-–—.،)]\s*');
  final items = (answer ?? '')
      .split(RegExp(r'\r\n?|\n'))
      .map((line) => line.trim().replaceFirst(prefix, '').trim())
      .where((line) => line.isNotEmpty)
      .toList(growable: false);
  if (items.isEmpty) {
    return _missingAnswer;
  }
  return <String>[
    // Keep the number attached to the first word so it cannot be orphaned at
    // the end of a PDF line; separate complete items with two spaces.
    for (var i = 0; i < items.length; i++) '${toArabicDigits('${i + 1}')}-${items[i]}',
  ].join('  ');
}

String _choiceLabel(int index) {
  const letters = <String>['أ', 'ب', 'ج', 'د', 'هـ', 'و', 'ز', 'ح'];
  return index < letters.length ? letters[index] : toArabicDigits('${index + 1}');
}
