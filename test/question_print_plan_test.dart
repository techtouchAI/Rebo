import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';

import 'test_support.dart';

LearningUnit unitWithQuestions(String id, int order, List<Question> questions) {
  return LearningUnit(
    id: id,
    sectionId: 'test-grade',
    title: 'الوحدة $order',
    displayTitle: 'الوحدة $order',
    grade: 'صف تجريبي',
    order: order,
    template: PresentationTemplate.concept,
    accent: 'primary',
    topics: const <Topic>[],
    questions: questions,
    figures: const <Figure>[],
  );
}

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  test('orders printable units by their actual curriculum numbers', () {
    final shuffled = library.unitsOf('g1').reversed;
    expect(printableUnits(shuffled).map((unit) => unit.id), <String>[
      'g1-u1', 'g1-u2', 'g1-u4',
    ]);
    expect(printableUnits(library.unitsOf('intro')), isEmpty);
    expect(printableUnits(library.unitsOf('theatre')), isEmpty);
  });

  for (final selected in <Set<String>>[
    <String>{'g1-u2'},
    <String>{'g1-u4', 'g1-u1'},
    <String>{'g1-u1', 'g1-u2', 'g1-u4'},
  ]) {
    test('groups exactly the selected units by question type: $selected', () {
      final available = library.unitsOf('g1').reversed.toList();
      final plan = QuestionPrintPlan.fromSelection(available, selected);
      final selectedInOrder = <String>[
        for (final id in <String>['g1-u1', 'g1-u2', 'g1-u4'])
          if (selected.contains(id)) id,
      ];

      expect(plan.units.map((unit) => unit.id), selectedInOrder);
      expect(plan.sections.map((section) => section.kind), printableQuestionKinds);
      expect(
        plan.questionCount,
        plan.units.fold<int>(0, (sum, unit) => sum + unit.questions.length),
      );
      for (final section in plan.sections) {
        expect(section.groups.map((group) => group.unit.id), selectedInOrder);
        for (final group in section.groups) {
          final original = group.unit.questions.where((question) => question.kind == section.kind);
          expect(group.questions, orderedEquals(original));
        }
      }
    });
  }

  test('selection is a snapshot and ignores unknown or questionless units', () {
    final selected = <String>{'intro', 'g1-u1', 'missing'};
    final plan = QuestionPrintPlan.fromSelection(library.units, selected);
    selected.clear();

    expect(plan.units.map((unit) => unit.id), <String>['g1-u1']);
    expect(() => plan.units.clear(), throwsUnsupportedError);
    expect(() => plan.sections.first.groups.clear(), throwsUnsupportedError);
    expect(QuestionPrintPlan.fromSelection(library.units, <String>{}).isEmpty, isTrue);
    expect(QuestionPrintPlan.fromSelection(library.units, <String>{'intro'}).isEmpty, isTrue);
  });

  test('skips absent kinds while retaining original order within each kind', () {
    final unit = unitWithQuestions('one', 1, const <Question>[
      Question(id: 'open-1', kind: QuestionKind.open, prompt: 'تعداد أول'),
      Question(id: 'bool-1', kind: QuestionKind.trueFalse, prompt: 'صح أول'),
      Question(id: 'open-2', kind: QuestionKind.open, prompt: 'تعداد ثان'),
      Question(id: 'bool-2', kind: QuestionKind.trueFalse, prompt: 'صح ثان'),
    ]);
    final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});

    expect(plan.sections.map((section) => section.kind), <QuestionKind>[
      QuestionKind.trueFalse,
      QuestionKind.open,
    ]);
    expect(plan.sections.first.groups.single.questions.map((q) => q.id), <String>[
      'bool-1', 'bool-2',
    ]);
    expect(plan.sections.last.groups.single.questions.map((q) => q.id), <String>[
      'open-1', 'open-2',
    ]);
  });

  test('the formatted paper includes choices and blanks but never answer keys', () {
    const boolean = Question(
      id: 'bool',
      kind: QuestionKind.trueFalse,
      prompt: 'عبارة اختبارية',
      boolAnswer: false,
      answerSupport: 'سبب سري',
    );
    const choice = Question(
      id: 'choice',
      kind: QuestionKind.choice,
      prompt: 'اختر أحد الآتي:',
      options: <String>['خيار أول', 'خيار ثان', 'خيار ثالث'],
      answerIndex: 1,
      answerSupport: 'تفسير سري',
    );
    const open = Question(
      id: 'open',
      kind: QuestionKind.open,
      prompt: 'عدد العناصر',
      textAnswer: 'إجابة سرية',
    );

    final boolLine = formatPrintableQuestion(boolean, 1);
    expect(boolLine, contains('١. عبارة اختبارية'));
    expect(boolLine, contains('(     )'));
    expect(boolLine, isNot(contains('سبب سري')));

    final choiceLine = formatPrintableQuestion(choice, 2);
    expect(choiceLine, contains('(أ) خيار أول'));
    expect(choiceLine, contains('(ب) خيار ثان'));
    expect(choiceLine, contains('(ج) خيار ثالث'));
    expect(choiceLine, isNot(contains('تفسير سري')));
    expect(formatPrintableQuestion(open, 3), '٣. عدد العناصر');
  });
}
