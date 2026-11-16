import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/exam_document_exporter.dart';
import 'package:mirsam/data/local/memory_exam_profile_repository.dart';
import 'package:mirsam/data/local/memory_exam_question_bank_repository.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/repositories/exam_profile_repository.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/presentation/screens/exam_composer_screen.dart';
import 'package:mirsam/presentation/state/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'docx_test_support.dart';
import 'overflow_utils.dart';
import 'test_support.dart';

Finder key(String value) => find.byKey(ValueKey<String>(value));

Future<void> tapKey(WidgetTester tester, String value) async {
  final finder = key(value);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

Future<AppState> pumpComposer(
  WidgetTester tester, {
  ExamDocumentExport? exporter,
  ExamProfileRepository? repository,
  MemoryExamQuestionBankRepository? bank,
  Size size = const Size(900, 1600),
}) async {
  final state = await pumpScreen(
    tester,
    ExamComposerScreen(
      exportDocument: exporter,
      profileRepository: repository ?? MemoryExamProfileRepository(),
      questionBankRepository: bank ?? MemoryExamQuestionBankRepository(),
    ),
    size: size,
  );
  await tester.pumpAndSettle();
  return state;
}

/// The first documented question of each kind of the test grade, as offered
/// options (their ids are the globally unique selection keys).
({ExamQuestionOption trueFalse, ExamQuestionOption choice, ExamQuestionOption open})
firstQuestions(AppState state) {
  final options = examQuestionOptions(state.library.unitsOf(testGrade));
  return (
    trueFalse: options.firstWhere(
      (ExamQuestionOption option) => option.question.kind == QuestionKind.trueFalse,
    ),
    choice: options.firstWhere(
      (ExamQuestionOption option) => option.question.kind == QuestionKind.choice,
    ),
    open: options.firstWhere(
      (ExamQuestionOption option) => option.question.kind == QuestionKind.open,
    ),
  );
}

Future<void> chooseDrawing(WidgetTester tester, int slot, TopicDrawing drawing) async {
  await tapKey(tester, 'exam-drawing-$slot');
  await tester.pumpAndSettle();
  await tester.tap(find.text('${drawing.title} — ${drawing.unitTitle}').last);
  await tester.pumpAndSettle();
}

/// Fills the smallest complete paper: header, one theoretical question, one
/// practical question, then returns to the last step.
Future<void> fillMinimumPaper(WidgetTester tester, AppState state) async {
  final questions = firstQuestions(state);
  final drawing = state.visibleDrawings.first;
  await tapKey(tester, 'exam-next'); // Header step.
  await tester.enterText(key('exam-school'), 'متوسطة النخبة للبنين');
  await tester.enterText(key('exam-teacher'), 'فائز محمد عبد النبي');
  await tester.pump();
  await tapKey(tester, 'exam-next'); // Theory step.
  await tapKey(tester, 'exam-item-${questions.trueFalse.id}');
  await tapKey(tester, 'exam-next'); // Practical step.
  await chooseDrawing(tester, 0, drawing);
  await tapKey(tester, 'exam-next'); // Review step.
}

String fieldText(WidgetTester tester, String keyValue) =>
    tester.widget<TextField>(key(keyValue)).controller!.text;

void main() {
  setUpAll(ensureLibrary);

  setUp(() {
    // The home page opens the real composer, whose default profile store reads
    // shared preferences; without the in-memory backend the plugin channel is
    // missing in widget tests and the screen would stay on its spinner.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the home page opens the question writer', (tester) async {
    await pumpApplication(tester, size: const Size(1280, 1600));
    final entry = find.text('كتابة الأسئلة');
    await tester.ensureVisible(entry);
    await tester.pump();
    await tester.tap(entry);
    await tester.pumpAndSettle();
    expect(find.byType(ExamComposerScreen), findsOneWidget);
    expect(find.text('نوع الخط وحجمه'), findsOneWidget);
  });

  testWidgets('the home page shows the writer as its own section card',
      (tester) async {
    await pumpApplication(tester, size: const Size(1280, 1600));

    expect(find.text('أقسام التطبيق'), findsOneWidget);
    // A standalone card, not only the shortcut row below the grid.
    expect(find.text('كتابة الأسئلة'), findsOneWidget);
    expect(
      find.text('اكتب ورقة امتحان وصدّرها ملف وورد مطابقاً للنموذج الرسمي'),
      findsOneWidget,
    );
  });

  testWidgets('starts from the official sizes and the device academic year', (tester) async {
    await pumpComposer(tester);
    expect(fieldText(tester, 'exam-header-size'), '12');
    expect(fieldText(tester, 'exam-body-size'), '14');
    expect(fieldText(tester, 'exam-heading-size'), '16');
    expect(fieldText(tester, 'exam-line-spacing'), '55');

    await tapKey(tester, 'exam-next');
    expect(fieldText(tester, 'exam-school'), isEmpty);
    expect(fieldText(tester, 'exam-grade'), 'الأول المتوسط');
    expect(fieldText(tester, 'exam-year'), academicYearLabel(DateTime.now()));
    expect(fieldText(tester, 'exam-teacher'), isEmpty);
  });

  testWidgets('pre-fills the saved profile and its typography', (tester) async {
    final repository = MemoryExamProfileRepository(
      const ExamProfile(
        schoolName: 'متوسطة الرافدين للبنين',
        gradeLabel: 'الثاني المتوسط',
        sectionName: 'ب',
        teacherName: 'أ. علي حسن',
        typography: ExamPaperTypography(
          font: ExamPaperFont.amiri,
          headerFontSize: 11,
          bodyFontSize: 16,
          headingFontSize: 18,
        ),
      ),
    );
    await pumpComposer(tester, repository: repository);
    expect(find.text('أميري'), findsOneWidget);
    expect(fieldText(tester, 'exam-body-size'), '16');
    expect(fieldText(tester, 'exam-heading-size'), '18');
    expect(fieldText(tester, 'exam-header-size'), '11');

    await tapKey(tester, 'exam-next');
    expect(fieldText(tester, 'exam-school'), 'متوسطة الرافدين للبنين');
    expect(fieldText(tester, 'exam-grade'), 'الثاني المتوسط');
    expect(fieldText(tester, 'exam-section'), 'ب');
    expect(fieldText(tester, 'exam-teacher'), 'أ. علي حسن');
  });

  testWidgets('moves from a theoretical question to the next one', (tester) async {
    final state = await pumpComposer(tester);
    final questions = firstQuestions(state);
    await tapKey(tester, 'exam-next');
    await tapKey(tester, 'exam-next');
    expect(find.text('س1: الصح والخطأ'), findsOneWidget);
    expect(key('exam-item-${questions.trueFalse.id}'), findsOneWidget);

    await tapKey(tester, 'exam-theory-next');
    expect(find.text('س2: الاختيارات'), findsOneWidget);
    expect(key('exam-item-${questions.trueFalse.id}'), findsNothing);
    expect(key('exam-item-${questions.choice.id}'), findsOneWidget);

    await tapKey(tester, 'exam-theory-next');
    expect(find.text('س3: التعداد'), findsOneWidget);
    expect(key('exam-answer-lines'), findsOneWidget);
    await tapKey(tester, 'exam-theory-previous');
    expect(find.text('س2: الاختيارات'), findsOneWidget);
  });

  testWidgets('tightens the line spacing and restores the official one',
      (tester) async {
    final exports = <({Uint8List bytes, String name})>[];
    final state = await pumpComposer(
      tester,
      exporter: (Uint8List bytes, String name) async {
        exports.add((bytes: bytes, name: name));
        return ExamExportResult(message: 'تم تجهيز الملف', path: '/tmp/$name', shared: true);
      },
    );

    // The project starts from a tightened 55 %; restoring means the official
    // 100 %, so the button is already usable.
    expect(key('exam-spacing-label'), findsOneWidget);
    expect(tester.widget<Slider>(key('exam-line-spacing-slider')).value, 55);
    expect(
      tester.widget<TextButton>(key('exam-line-spacing-reset')).onPressed,
      isNotNull,
    );

    await tester.enterText(key('exam-line-spacing'), '70');
    await tester.pump();
    expect(find.textContaining('٧٠٪'), findsOneWidget);
    expect(tester.widget<Slider>(key('exam-line-spacing-slider')).value, 70);
    expect(
      tester.widget<TextButton>(key('exam-line-spacing-reset')).onPressed,
      isNotNull,
    );

    // Out-of-range input is refused instead of silently exported.
    await tester.enterText(key('exam-line-spacing'), '10');
    await tester.pump();
    expect(find.textContaining('أدخل نسبة بين'), findsOneWidget);

    await tapKey(tester, 'exam-line-spacing-reset');
    expect(fieldText(tester, 'exam-line-spacing'), '100');
    expect(tester.widget<Slider>(key('exam-line-spacing-slider')).value, 100);
    // Nothing left to restore.
    expect(
      tester.widget<TextButton>(key('exam-line-spacing-reset')).onPressed,
      isNull,
    );

    // 70 % must reach the exported document: 360 * 0.7 = 252 twips.
    await tester.enterText(key('exam-line-spacing'), '70');
    await tester.pump();
    await fillMinimumPaper(tester, state);
    await tapKey(tester, 'exam-export');
    await tester.pumpAndSettle();

    expect(exports, hasLength(1));
    final xml = documentXmlOf(exports.single.bytes);
    expect(xml, contains('w:line="252" w:lineRule="auto"'));
    expect(xml, isNot(contains('w:line="360" w:lineRule="auto"')));
    expectWellFormedXml(xml);
  });

  testWidgets('writes a full paper and exports it as a Word file', (tester) async {
    final exports = <({Uint8List bytes, String name})>[];
    final repository = MemoryExamProfileRepository();
    final state = await pumpComposer(
      tester,
      repository: repository,
      exporter: (Uint8List bytes, String name) async {
        exports.add((bytes: bytes, name: name));
        return ExamExportResult(message: 'تم تجهيز الملف', path: '/tmp/$name', shared: true);
      },
    );
    final questions = firstQuestions(state);
    final drawing = state.visibleDrawings.first;

    await tester.enterText(key('exam-body-size'), '٢٠');
    await tester.pump();
    await tapKey(tester, 'exam-next');
    await tester.enterText(key('exam-school'), 'متوسطة النخبة للبنين');
    await tester.enterText(key('exam-section'), 'أ');
    await tester.enterText(key('exam-teacher'), 'فائز محمد عبد النبي');
    await tester.pump();
    await tapKey(tester, 'exam-term-endOfYear');
    await tapKey(tester, 'exam-next');

    await tapKey(tester, 'exam-item-${questions.trueFalse.id}');
    await tapKey(tester, 'exam-theory-next');
    await tapKey(tester, 'exam-item-${questions.choice.id}');
    await tapKey(tester, 'exam-theory-next');
    await tapKey(tester, 'exam-item-${questions.open.id}');
    expect(key('exam-answer-lines'), findsOneWidget);

    await tapKey(tester, 'exam-next');
    await chooseDrawing(tester, 0, drawing);
    await tester.enterText(key('exam-practical-1'), 'ارسم منظراً طبيعياً مستخدماً الألوان ؟');
    await tester.pump();
    await tapKey(tester, 'exam-next');

    expect(key('exam-preview'), findsOneWidget);
    final preview = tester.widget<SelectableText>(key('exam-preview')).data!;
    expect(preview, contains('متوسطة النخبة للبنين'));
    expect(preview, contains('المادة العملية'));
    expect(preview, contains('فائز محمد عبد النبي'));

    final exportButton = key('exam-export');
    await tester.ensureVisible(exportButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNotNull);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();

    expect(exports, hasLength(1));
    expect(exports.single.name, endsWith('.docx'));
    expect(exports.single.name, contains('آخر السنة'));
    final xml = documentXmlOf(exports.single.bytes);
    expect(xml, contains('متوسطة النخبة للبنين'));
    expect(xml, contains('فائز محمد عبد النبي'));
    expect(xml, contains('اسئلة امتحانات نهاية السنة'));
    expect(xml, contains(questions.trueFalse.question.prompt.substring(0, 20)));
    expect(xml, contains(questions.choice.question.options.first.trim()));
    expect(xml, contains(questions.open.question.prompt.substring(0, 20)));
    expect(xml, contains(drawing.title));
    expect(xml, contains('ارسم منظراً طبيعياً مستخدماً الألوان ؟'));
    expect(xml, contains('<w:sz w:val="40"/><w:szCs w:val="40"/>'));
    expectWellFormedXml(xml);

    expect(repository.saveCount, 1);
    expect(repository.profile.teacherName, 'فائز محمد عبد النبي');
    expect(repository.profile.typography.bodyFontSize, 20);
  });

  testWidgets('blocks the export until the paper is complete', (tester) async {
    await pumpComposer(tester);
    await tapKey(tester, 'exam-step-4');
    final exportButton = key('exam-export');
    await tester.ensureVisible(exportButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNull);
    expect(find.text(ExamPaperInfo.missingSchool), findsWidgets);
    expect(find.text(ExamPaper.noTheory), findsWidgets);
  });

  testWidgets('reports a failed export and keeps the button usable', (tester) async {
    final state = await pumpComposer(
      tester,
      exporter: (Uint8List bytes, String name) async => throw StateError('no storage'),
    );
    await fillMinimumPaper(tester, state);
    final exportButton = key('exam-export');
    await tester.ensureVisible(exportButton);
    await tester.pump();
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
    expect(find.textContaining('تعذّر تصدير ملف وورد'), findsOneWidget);
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNotNull);
  });

  testWidgets('exports the minimum paper built by the flow', (tester) async {
    final exports = <({Uint8List bytes, String name})>[];
    final state = await pumpComposer(
      tester,
      exporter: (Uint8List bytes, String name) async {
        exports.add((bytes: bytes, name: name));
        return ExamExportResult(message: 'saved', path: '/tmp/$name');
      },
    );
    await fillMinimumPaper(tester, state);
    final exportButton = key('exam-export');
    await tester.ensureVisible(exportButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(exportButton).onPressed, isNotNull);
    await tester.tap(exportButton);
    await tester.pumpAndSettle();
    expect(exports, hasLength(1));
    final xml = documentXmlOf(exports.single.bytes);
    expect(xml, contains('المادة النظرية'));
    expect(xml, contains('المادة العملية'));
  });

  testWidgets('saves the group in the app and restores it', (tester) async {
    final bank = MemoryExamQuestionBankRepository();
    final state = await pumpComposer(tester, bank: bank);
    final questions = firstQuestions(state);

    // Nothing saved yet.
    await tapKey(tester, 'exam-open-bank');
    expect(find.text('لا توجد مجموعات محفوظة بعد.'), findsOneWidget);
    expect(bank.saveCount, 0);

    await tapKey(tester, 'exam-next');
    await tapKey(tester, 'exam-next');
    await tapKey(tester, 'exam-item-${questions.trueFalse.id}');
    await tapKey(tester, 'exam-save-group');
    // The save is asynchronous and reports through a snack bar.
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));

    expect(bank.saveCount, 1);
    expect(bank.entries, hasLength(1));
    expect(
      bank.entries.single.selection['trueFalse'],
      contains(questions.trueFalse.id),
    );
    expect(find.textContaining('حُفظت المجموعة'), findsOneWidget);

    // A second start from the stored bank restores that selection; pumping a
    // new screen replaces the previous tree entirely.
    final reopening = MemoryExamQuestionBankRepository(bank.entries);
    await pumpComposer(tester, bank: reopening);
    await tapKey(tester, 'exam-open-bank');
    await tester.pumpAndSettle();
    expect(find.text('المجموعات المحفوظة'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey<String>('exam-bank-entry-${bank.entries.single.id}')));
    await tester.pumpAndSettle();

    await tapKey(tester, 'exam-next');
    await tapKey(tester, 'exam-next');
    expect(
      tester.widget<CheckboxListTile>(key('exam-item-${questions.trueFalse.id}')).value,
      isTrue,
    );
  });

  testWidgets('the two section headings are editable and reach the file',
      (tester) async {
    final exports = <({Uint8List bytes, String name})>[];
    final state = await pumpComposer(
      tester,
      exporter: (Uint8List bytes, String name) async {
        exports.add((bytes: bytes, name: name));
        return ExamExportResult(message: 'تم تجهيز الملف', path: '/tmp/$name', shared: true);
      },
    );

    await tapKey(tester, 'exam-next'); // Header step.
    await tester.enterText(key('exam-school'), 'متوسطة النخبة للبنين');
    await tester.enterText(key('exam-teacher'), 'فائز محمد عبد النبي');
    await tester.pump();
    await tapKey(tester, 'exam-next'); // Theory step.
    expect(key('exam-theory-header'), findsOneWidget);
    await tester.enterText(key('exam-theory-header'), 'المادة النظرية / اجب عن سؤالين فقط');
    await tester.pump();

    final questions = firstQuestions(state);
    await tapKey(tester, 'exam-item-${questions.trueFalse.id}');
    await tapKey(tester, 'exam-theory-next');
    await tapKey(tester, 'exam-theory-next');
    await tapKey(tester, 'exam-next'); // Practical step.
    expect(key('exam-practical-header'), findsOneWidget);
    await tester.enterText(key('exam-practical-header'), 'المادة العملية : اجب عن سؤالين فقط');
    await tester.pump();
    await chooseDrawing(tester, 0, state.visibleDrawings.first);
    await tapKey(tester, 'exam-next'); // Review step.
    await tapKey(tester, 'exam-export');
    await tester.pumpAndSettle();

    expect(exports, hasLength(1));
    final xml = documentXmlOf(exports.single.bytes);
    expect(xml, contains('المادة النظرية / اجب عن سؤالين فقط'));
    expect(xml, contains('( 30 درجة )'));
    expect(xml, contains('لكل سؤال ( 15 درجة )'));
    expect(xml, contains('المادة العملية : اجب عن سؤالين فقط ( 70 درجة )'));
    expectWellFormedXml(xml);

    // The preview shows exactly the same headings as the file.
    final preview = tester.widget<SelectableText>(key('exam-preview')).data!;
    expect(preview, contains('( 30 درجة ) لكل سؤال ( 15 درجة )'));
    expect(preview, contains('( 70 درجة )'));
  });

  for (final double width in <double>[320, 360, 390]) {
    testWidgets('fits a ${width.toInt()} pixel phone at the largest text scale', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpComposer(tester, size: Size(width, 800));
      expect(tester.takeException(), isNull);
      expect(findFlexOverflows(tester), isEmpty);
      for (final String step in <String>[
        'exam-step-1',
        'exam-step-2',
        'exam-step-3',
        'exam-step-4',
      ]) {
        await tapKey(tester, step);
        expect(tester.takeException(), isNull);
        expect(findFlexOverflows(tester), isEmpty, reason: 'overflow on $step');
      }
    });
  }
}
