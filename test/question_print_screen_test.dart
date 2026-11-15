import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:mirsam/presentation/screens/question_print_screen.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

Finder unitSelector(String id) => find.byKey(ValueKey<String>('print-unit-$id'));
Finder get printButton => find.byKey(const ValueKey<String>('print-questions-button'));
Finder get fontSelector => find.byKey(const ValueKey<String>('print-font'));
Finder get bodySize => find.byKey(const ValueKey<String>('print-body-size'));
Finder get headingSize => find.byKey(const ValueKey<String>('print-heading-size'));

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
    await tapVisible(tester, find.text('طباعة أسئلة الامتحان'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(QuestionPrintScreen), findsOneWidget);
    expect(find.text('اختر الوحدات'), findsOneWidget);
  });

  testWidgets('shows selected units and print settings without question contents', (tester) async {
    final state = await pumpScreen(
      tester,
      const QuestionPrintScreen(),
      size: const Size(900, 1600),
    );
    final units = state.library.unitsOf('g1');
    expect(find.text('طباعة أسئلة الامتحان'), findsOneWidget);
    for (final unit in units) {
      expect(tester.widget<CheckboxListTile>(unitSelector(unit.id)).value, isTrue);
      expect(find.text(unit.title), findsOneWidget);
      expect(find.byKey(ValueKey<String>('preview-unit-${unit.id}')), findsNothing);
      for (final question in unit.questions) {
        expect(
          find.textContaining(question.prompt),
          findsNothing,
          reason: '${unit.id}/${question.id}',
        );
      }
    }
    expect(find.byKey(const ValueKey<String>('print-unit-g2-u1')), findsNothing);
    expect(find.textContaining('٣ وحدة • ٢٥ سؤالاً'), findsOneWidget);
    expect(fontSelector, findsOneWidget);
    expect(tester.widget<TextField>(bodySize).controller!.text, '12');
    expect(tester.widget<TextField>(headingSize).controller!.text, '14');
  });

  testWidgets('prints one, two, or every selected unit; never prints an empty selection', (
    tester,
  ) async {
    final printed = <QuestionPrintPlan>[];
    final grades = <String>[];
    await pumpScreen(
      tester,
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) async {
          printed.add(plan);
          grades.add(grade);
        },
      ),
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

  testWidgets('passes the selected font and numeric sizes without changing reading settings', (
    tester,
  ) async {
    QuestionPrintPlan? printed;
    final state = await pumpScreen(
      tester,
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) async {
          printed = plan;
        },
      ),
      size: const Size(900, 1600),
    );
    final readingFont = state.font;
    final readingScale = state.textScale;
    await tapVisible(tester, fontSelector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('أميري').last);
    await tester.pumpAndSettle();
    await tester.enterText(bodySize, '١٨');
    await tester.enterText(headingSize, '۲۴');
    await tester.pump();
    await tester.tap(printButton);
    await tester.pump();

    expect(printed!.settings.font, QuestionPrintFont.amiri);
    expect(printed!.settings.bodyFontSize, 18);
    expect(printed!.settings.headingFontSize, 24);
    expect(state.font, readingFont);
    expect(state.textScale, readingScale);
  });

  testWidgets('invalid or empty sizes prevent printing until corrected', (tester) async {
    final printed = <QuestionPrintPlan>[];
    await pumpScreen(
      tester,
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) async {
          printed.add(plan);
        },
      ),
      size: const Size(900, 1600),
    );
    for (final value in <String>['7', '33', '']) {
      await tester.enterText(bodySize, value);
      await tester.pump();
      expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
      expect(find.text('أدخل أحجام خط صحيحة'), findsOneWidget);
    }
    await tester.enterText(bodySize, '٨');
    await tester.enterText(headingSize, '٣٣');
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    await tester.enterText(headingSize, '٣٢');
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNotNull);
    await tester.tap(printButton);
    await tester.pump();
    expect(printed.single.settings.bodyFontSize, 8);
    expect(printed.single.settings.headingFontSize, 32);
  });

  testWidgets('changing grade resets the selection and excludes the previous grade', (
    tester,
  ) async {
    QuestionPrintPlan? printed;
    final state = await pumpScreen(
      tester,
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) async {
          printed = plan;
        },
      ),
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
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) => completion.future,
      ),
      size: const Size(900, 1600),
    );
    await tester.tap(printButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNull);
    expect(tester.widget<CheckboxListTile>(unitSelector('g1-u1')).onChanged, isNull);
    expect(tester.widget<TextField>(bodySize).enabled, isFalse);
    expect(tester.widget<TextField>(headingSize).enabled, isFalse);
    expect(
      tester.widget<DropdownButtonFormField<QuestionPrintFont>>(fontSelector).onChanged,
      isNull,
    );
    expect(find.text('جاري التحضير'), findsOneWidget);
    completion.complete();
    await tester.pump();
    expect(tester.widget<FilledButton>(printButton).onPressed, isNotNull);
  });

  testWidgets('reports a printing failure and allows retry', (tester) async {
    await pumpScreen(
      tester,
      QuestionPrintScreen(
        printQuestions: (QuestionPrintPlan plan, String grade) async {
          throw StateError('printer unavailable');
        },
      ),
      size: const Size(900, 1600),
    );
    await tester.tap(printButton);
    await tester.pump();
    expect(find.textContaining('تعذّرت الطباعة'), findsOneWidget);
    expect(tester.widget<FilledButton>(printButton).onPressed, isNotNull);
  });

  testWidgets('shows an empty state and disables printing when a grade has no questions', (
    tester,
  ) async {
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
      await tester.ensureVisible(headingSize);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(findFlexOverflows(tester), isEmpty);
    });
  }
}
