import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
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
    expect(printableUnits(shuffled).map((unit) => unit.id), <String>['g1-u1', 'g1-u2', 'g1-u4']);
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
      'bool-1',
      'bool-2',
    ]);
    expect(plan.sections.last.groups.single.questions.map((q) => q.id), <String>[
      'open-1',
      'open-2',
    ]);
  });

  test('prints the documented true or false answer and a correction when available', () {
    const falseQuestion = Question(
      id: 'false',
      kind: QuestionKind.trueFalse,
      prompt: 'عبارة اختبارية',
      boolAnswer: false,
      answerSupport: 'هذا هو التصحيح الموثق.',
    );
    const trueQuestion = Question(
      id: 'true',
      kind: QuestionKind.trueFalse,
      prompt: 'عبارة صحيحة',
      boolAnswer: true,
    );
    expect(
      formatPrintableQuestion(falseQuestion, 1),
      '١. عبارة اختبارية  الإجابة: خطأ  التصحيح: هذا هو التصحيح الموثق.',
    );
    expect(formatPrintableQuestion(trueQuestion, 2), '٢. عبارة صحيحة  الإجابة: صح');
  });

  test('prints all options and identifies the correct answer', () {
    const choice = Question(
      id: 'choice',
      kind: QuestionKind.choice,
      prompt: 'اختر أحد الآتي:',
      options: <String>['خيار أول', 'خيار ثان', 'خيار ثالث'],
      answerIndex: 1,
    );
    final line = formatPrintableQuestion(choice, 2);
    expect(line, contains('(أ) خيار أول'));
    expect(line, contains('(ب) خيار ثان'));
    expect(line, contains('(ج) خيار ثالث'));
    expect(line, contains('الإجابة: (ب) خيار ثان'));
  });

  test('prints enumeration answers inline with consecutive Arabic numbers', () {
    const open = Question(
      id: 'open',
      kind: QuestionKind.open,
      prompt: 'عدد العناصر',
      textAnswer: '١- العنصر الأول.\r\n2. العنصر الثاني.\nالعنصر الثالث.',
    );
    expect(
      formatPrintableQuestion(open, 3),
      '٣. عدد العناصر  الإجابة: ١-العنصر الأول.  ٢-العنصر الثاني.  ٣-العنصر الثالث.',
    );
    final manyItems = Question(
      id: 'many',
      kind: QuestionKind.open,
      prompt: 'عدد',
      textAnswer: List<String>.generate(11, (index) => 'عنصر ${index + 1}').join('\n'),
    );
    expect(formatPrintableQuestion(manyItems, 1), contains('١٠-عنصر 10  ١١-عنصر 11'));
  });

  test('does not invent missing or invalid answers', () {
    final questions = <Question>[
      const Question(id: 'unknown-bool', kind: QuestionKind.trueFalse, prompt: 'سؤال'),
      const Question(id: 'unknown-open', kind: QuestionKind.open, prompt: 'سؤال', textAnswer: '  '),
      for (final index in <int?>[null, -1, 2])
        Question(
          id: 'unknown-choice-$index',
          kind: QuestionKind.choice,
          prompt: 'سؤال',
          options: const <String>['أول', 'ثان'],
          answerIndex: index,
        ),
    ];
    for (final question in questions) {
      expect(formatPrintableQuestion(question, 1), contains('الإجابة: غير متوفرة في المصدر'));
    }
  });

  test('all curriculum answers are included, including every enumeration item', () {
    for (final unit in printableUnits(library.units)) {
      for (final question in unit.questions) {
        final line = formatPrintableQuestion(question, 1);
        expect(line, isNot(contains('غير متوفرة في المصدر')), reason: '${unit.id}/${question.id}');
        switch (question.kind) {
          case QuestionKind.trueFalse:
            expect(line, contains(question.boolAnswer! ? 'الإجابة: صح' : 'الإجابة: خطأ'));
          case QuestionKind.choice:
            expect(line, contains(question.options[question.answerIndex!]));
          case QuestionKind.open:
            final items = question.textAnswer!.split('\n');
            for (final item in items) {
              expect(
                line,
                contains(item.trim().replaceFirst('- ', '-')),
                reason: '${unit.id}/${question.id}',
              );
            }
        }
      }
    }
  });

  test('print settings are an immutable part of the selection snapshot', () {
    const settings = QuestionPrintSettings(
      font: QuestionPrintFont.amiri,
      bodyFontSize: 18,
      headingFontSize: 22,
    );
    final unit = library.unitsOf('g1').first;
    final plan = QuestionPrintPlan.fromSelection(
      <LearningUnit>[unit],
      <String>{unit.id},
      settings: settings,
    );
    expect(plan.settings, same(settings));
    expect(plan.settings.isValid, isTrue);
    expect(const QuestionPrintSettings(bodyFontSize: 7).isValid, isFalse);
    expect(const QuestionPrintSettings(headingFontSize: 33).isValid, isFalse);
    expect(QuestionPrintSettings.isValidFontSize(8), isTrue);
    expect(QuestionPrintSettings.isValidFontSize(32), isTrue);
  });
}
