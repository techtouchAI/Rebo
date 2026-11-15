import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:mirsam/presentation/screens/question_print_screen.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

Finder unitSelector(String id) => find.byKey(ValueKey<String>('print-unit-$id'));
Finder unitPreview(String id) => find.byKey(ValueKey<String>('preview-unit-$id'));
Finder get printButton => find.byKey(const ValueKey<String>('print-questions-button'));

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  await tester.tap(target);
  await tester.pump();
}

void main() {
  setUpAll(ensureLibrary);

  testWidgets('the home page opens the dedicated printing section', (tester) async {
    await pumpApplication(tester, size: const Size(1280, 1600));
    await tapVisible(tester, find.text('طباعة الأسئلة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuestionPrintScreen), findsOneWidget);
    expect(find.text('اختر الوحدات'), findsOneWidget);
  });

  testWidgets('shows all questions by unit and kind without answers, with all selected',
      (tester) async {
    final state = await pumpScreen(
      tester,
      const QuestionPrintScreen(),
      size: const Size(900, 8000),
    );
    final units = state.library.unitsOf('g1');
    for (final unit in units) {
      expect(tester.widget<CheckboxListTile>(unitSelector(unit.id)).value, isTrue);
      final preview = unitPreview(unit.id);
      expect(preview, findsOneWidget);
      final headers = <Finder>[
        for (final kind in printableQuestionKinds)
          find.descendant(of: preview, matching: find.text(kind.printHeading)),
      ];
      for (final header in headers) {
        expect(header, findsOneWidget);
      }
      final positions = headers.map((header) => tester.getTopLeft(header).dy).toList();
      expect(positions[0], lessThan(positions[1]));
      expect(positions[1], lessThan(positions[2]));
      for (final question in unit.questions) {
        expect(
          find.descendant(of: preview, matching: find.textContaining(question.prompt)),
          findsOneWidget,
          reason: '${unit.id}/${question.id} is missing',
        );
        if (question.answerSupport != null) {
          expect(find.textContaining(question.answerSupport!), findsNothing);
        }
        if (question.kind == QuestionKind.open && question.textAnswer != null) {
          expect(find.textContaining(question.textAnswer!), findsNothing);
        }
      }
    }
    expect(find.byKey(const ValueKey<String>('preview-unit-g2-u1')), findsNothing);
    final firstChoice = units.first.questions.firstWhere((q) => q.kind == QuestionKind.choice);
    expect(find.textContaining('(أ) ${firstChoice.options.first}'), findsOneWidget);
    expect(find.textContaining('٣ وحدة • ٢٥ سؤالاً'), findsOneWidget);
  });

  testWidgets('prints one, two, or every selected unit; never prints an empty selection',
      (tester) async {
    final printed = <QuestionPrintPlan>[];
    final grades = <String>[];
    await pumpScreen(
      tester,
      QuestionPrintScreen(printQuestions: (QuestionPrintPlan plan, String grade) async {
        printed.add(plan);
        grades.add(grade);
      }),
      size: const Size(900, 1600),
    );

    await tapVisible(tester, find.text('إلغاء التحديد'));
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    expect(find.text('اختر وحدة للطباعة'), findsOneWidget);

    await tapVisible(tester, unitSelector('g1-u4'));
    await tester.tap(printButton);
    await tester.pump();
    expect(printed.single.units.map((unit) => unit.id), <String>['g1-u4']);
    expect(grades.single, 'الصف الأول المتوسط');

    await tapVisible(tester, unitSelector('g1-u1'));
    await tester.tap(printButton);
    await tester.pump();
    expect(printed[1].units.map((unit) => unit.id), <String>['g1-u1', 'g1-u4']);
    expect(printed[1].sections.map((section) => section.kind), printableQuestionKinds);

    await tapVisible(tester, find.text('تحديد الكل'));
    await tester.tap(printButton);
    await tester.pump();
    expect(printed[2].units.map((unit) => unit.id), <String>['g1-u1', 'g1-u2', 'g1-u4']);
    expect(printed[2].questionCount, 25);
  });

  testWidgets('changing grade resets the selection and excludes the previous grade', (tester) async {
    QuestionPrintPlan? printed;
    final state = await pumpScreen(
      tester,
      QuestionPrintScreen(printQuestions: (QuestionPrintPlan plan, String grade) async {
        printed = plan;
      }),
      size: const Size(900, 1600),
    );
    await tapVisible(tester, unitSelector('g1-u1'));
    await state.setGrade('g2');
    await tester.pump();

    expect(unitSelector('g1-u1'), findsNothing);
    for (final id in <String>['g2-u1', 'g2-u2', 'g2-u4']) {
      expect(tester.widget<CheckboxListTile>(unitSelector(id)).value, isTrue);
    }
    await tester.tap(printButton);
    await tester.pump();
    expect(printed!.units.every((unit) => unit.sectionId == 'g2'), isTrue);
    expect(printed!.questionCount, 23);
  });

  testWidgets('disables controls while printing and restores them afterwards', (tester) async {
    final completion = Completer<void>();
    await pumpScreen(
      tester,
      QuestionPrintScreen(printQuestions: (QuestionPrintPlan plan, String grade) => completion.future),
      size: const Size(900, 1600),
    );
    await tester.tap(printButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(unitSelector('g1-u1')).onChanged, isNull);
    expect(find.text('جاري التحضير'), findsOneWidget);
    completion.complete();
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNotNull);
  });

  testWidgets('reports a printing failure and allows retry', (tester) async {
    await pumpScreen(
      tester,
      QuestionPrintScreen(printQuestions: (QuestionPrintPlan plan, String grade) async {
        throw StateError('printer unavailable');
      }),
      size: const Size(900, 1600),
    );
    await tester.tap(printButton);
    await tester.pump();
    expect(find.textContaining('تعذّرت الطباعة'), findsOneWidget);
    expect(tester.widget<FilledButton>(printButton).onPressed, isNotNull);
  });

  testWidgets('shows an empty state and disables printing when a grade has no questions',
      (tester) async {
    await pumpScreen(
      tester,
      const QuestionPrintScreen(),
      progress: ReadingProgress(gradeId: 'no-units'),
      size: const Size(390, 844),
    );
    expect(find.text('لا توجد أسئلة للطباعة'), findsOneWidget);
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
  });

  for (final width in <double>[320, 360, 390]) {
    testWidgets('fits a $width pixel phone at the largest supported text scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpScreen(tester, const QuestionPrintScreen(), size: Size(width, 800));
      expect(tester.takeException(), isNull);
      expect(findFlexOverflows(tester), isEmpty);
    });
  }
}
