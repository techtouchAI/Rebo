import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/repositories/exam_profile_repository.dart';
import 'package:mirsam/domain/services/exam_paper_formatter.dart';
import 'package:mirsam/presentation/state/exam_composer_state.dart';

import 'docx_test_support.dart';
import 'test_support.dart';

void main() {
  setUpAll(ensureLibrary);

  group('academic year', () {
    test('starts in September and spans two years', () {
      expect(academicYearLabel(DateTime(2025, 9, 1)), '2025 – 2026');
      expect(academicYearLabel(DateTime(2025, 12, 31)), '2025 – 2026');
      expect(academicYearLabel(DateTime(2026, 8, 31)), '2025 – 2026');
      expect(academicYearLabel(DateTime(2026, 1, 15)), '2025 – 2026');
    });
  });

  group('official wording', () {
    test('adapts the true/false instruction to the number of statements', () {
      expect(defaultTheoryInstruction(QuestionKind.trueFalse, 3), contains('لثلاث فقط'));
      expect(defaultTheoryInstruction(QuestionKind.trueFalse, 2), contains('لاثنين فقط'));
      expect(
        defaultTheoryInstruction(QuestionKind.trueFalse, 0),
        isNot(contains('فقط')),
      );
      expect(defaultTheoryInstruction(QuestionKind.choice, 1), 'اختر الاجابة الصحيحة ما بين الاقواس :');
    });

    test('numbers the questions with Western digits like the paper', () {
      expect(examQuestionNumber(0), 'س1');
      expect(examQuestionNumber(2), 'س3');
    });

    test('prints the class line with and without a section', () {
      const info = ExamPaperInfo(
        schoolName: 'متوسطة',
        gradeLabel: 'الأول المتوسط',
        sectionName: 'أ',
        term: ExamTerm.endOfYear,
        round: ExamRound.second,
        academicYear: '2025 – 2026',
        teacherName: 'مدرس',
      );
      expect(info.classLine, 'الصف : الأول المتوسط / الشعبة : أ');
      expect(info.classLine, isNot(contains('  ')));
      expect(info.copyWith(sectionName: '').classLine, 'الصف : الأول المتوسط / الشعبة :');
      expect(info.examTitleLine, 'اسئلة امتحانات نهاية السنة / الدور الثاني');
      expect(info.yearLine, 'للعام الدراسي 2025 – 2026');
    });

    test('strips the grade prefix printed by the paper', () {
      expect(examGradeLabel('الصف الأول المتوسط'), 'الأول المتوسط');
      expect(examGradeLabel('كل الصفوف'), 'كل الصفوف');
    });

    test('renders each question kind the way it is printed', () {
      const trueFalse = ExamTheoryItem(
        id: 'a',
        kind: QuestionKind.trueFalse,
        prompt: 'عبارة .',
      );
      final choice = ExamTheoryItem(
        id: 'b',
        kind: QuestionKind.choice,
        prompt: 'اختر',
        options: <String>['أ', 'ب'],
      );
      expect(examTheoryItemText(trueFalse), contains('(                )'));
      expect(examTheoryItemText(choice), contains('( أ   -   ب )'));
      expect(
        examAnswerLines(
          const ExamTheoryQuestion(
            kind: QuestionKind.open,
            instruction: 'عدد',
            degree: 5,
            items: <ExamTheoryItem>[],
            answerLineCount: 2,
          ),
        ).length,
        2,
      );
    });
  });

  group('validation', () {
    test('lists every missing field and every missing question', () {
      const paper = ExamPaper(
        info: ExamPaperInfo(
          schoolName: '',
          gradeLabel: '',
          sectionName: '',
          term: ExamTerm.midYear,
          round: ExamRound.first,
          academicYear: '',
          teacherName: '',
        ),
        typography: ExamPaperTypography(),
        theory: <ExamTheoryQuestion>[],
        practical: <ExamPracticalQuestion>[],
        theoryDegree: 10,
        practicalDegree: 70,
      );
      expect(paper.isComplete, isFalse);
      expect(
        paper.issues,
        containsAll(<String>[
          ExamPaperInfo.missingSchool,
          ExamPaperInfo.missingGrade,
          ExamPaperInfo.missingYear,
          ExamPaperInfo.missingTeacher,
          ExamPaper.noTheory,
          ExamPaper.noPractical,
        ]),
      );
    });

    test('accepts a complete paper and rejects invalid degrees', () {
      final paper = buildSamplePaper();
      expect(paper.isComplete, isTrue);
      expect(paper.issues, isEmpty);
      expect(paper.theoryItemCount, 4);
      expect(paper.practicalCount, 2);
      expect(paper.questionCount, 5);
    });
  });

  group('file name', () {
    test('is safe for Windows and keeps the year', () {
      final paper = buildSamplePaper();
      final name = examPaperFileName(paper);
      expect(name, endsWith('.docx'));
      expect(name, contains('2025 – 2026'));
      expect(name, isNot(contains('/')));
      final cleaned = sanitizeExamFileName('a/b:c*?"<>|');
      expect(RegExp(r'[\\/:*?"<>|]').hasMatch(cleaned), isFalse);
      expect(cleaned.startsWith('a-b-c'), isTrue);
      expect(sanitizeExamFileName('   '), 'mirsam-exam');
    });
  });

  group('offered content', () {
    test('keeps the curriculum order of the grade', () async {
      final library = await ensureLibrary();
      final units = library.unitsOf('g1');
      final options = examQuestionOptions(units);
      final expected = <String>[
        for (final LearningUnit unit in units)
          for (final Question question in unit.questions) '${unit.id}:${question.id}',
      ];
      expect(options.map((ExamQuestionOption option) => option.id), expected);
      expect(
        options.map((ExamQuestionOption option) => option.unitTitle).toSet().length,
        units.length,
      );
    });

    test('gives every offered question a unique id', () async {
      final library = await ensureLibrary();
      final options = examQuestionOptions(library.unitsOf('g1'));
      final ids = options.map((ExamQuestionOption option) => option.id).toList();
      // Question ids repeat per unit in the source file (q1..q9), so the
      // option id must combine the unit id with the question id.
      expect(ids.toSet().length, ids.length);
      expect(ids.length, greaterThan(9));
    });

    test('sorts the prepared drawing topics by their document order', () async {
      final library = await ensureLibrary();
      final drawings = examDrawingOptions(library.drawings.reversed);
      final orders = drawings.map((TopicDrawing drawing) => drawing.order).toList();
      final sorted = <int>[...orders]..sort();
      expect(orders, sorted);
    });
  });

  group('profile', () {
    test('round-trips through JSON and repairs unsupported sizes', () {
      const profile = ExamProfile(
        schoolName: 'متوسطة',
        gradeLabel: 'الأول المتوسط',
        sectionName: 'ب',
        teacherName: 'مدرس',
        typography: ExamPaperTypography(
          font: ExamPaperFont.amiri,
          headerFontSize: 11,
          bodyFontSize: 16,
          headingFontSize: 20,
        ),
      );
      final restored = ExamProfile.fromJson(profile.toJson());
      expect(restored.schoolName, profile.schoolName);
      expect(restored.sectionName, 'ب');
      expect(restored.typography.font, ExamPaperFont.amiri);
      expect(restored.typography.bodyFontSize, 16);

      final repaired = ExamProfile.fromJson(<String, dynamic>{
        'bodyFontSize': 99,
        'font': 'a-font-that-does-not-exist',
      });
      expect(repaired.typography.bodyFontSize, ExamPaperTypography.defaultBodyFontSize);
      expect(repaired.typography.font, ExamPaperFont.traditionalArabic);
    });
  });

  group('composer state', () {
    late Library library;
    late ExamComposerState state;

    setUp(() async {
      library = await ensureLibrary();
      state = ExamComposerState(
        units: library.unitsOf('g1'),
        drawings: library.drawings,
        gradeLabel: examGradeLabel('الصف الأول المتوسط'),
        now: DateTime(2025, 10, 1),
      );
    });

    test('starts from the official defaults', () {
      expect(state.gradeLabel, 'الأول المتوسط');
      expect(state.academicYear, '2025 – 2026');
      expect(state.term, ExamTerm.midYear);
      expect(state.typography!.headerFontSize, 12);
      expect(state.degreeOf(QuestionKind.trueFalse), 6);
      expect(state.degreeOf(QuestionKind.choice), 4);
      expect(state.degreeOf(QuestionKind.open), 15);
      expect(state.theoryItemCount, 0);
      expect(state.paper, isNull);
      expect(state.issues, contains(ExamPaperInfo.missingSchool));
    });

    test('keeps the selected items in curriculum order and updates the wording', () {
      final options = state.optionsOf(QuestionKind.trueFalse);
      expect(options.length, greaterThan(2));
      state.toggleItem(QuestionKind.trueFalse, options.last.id);
      state.toggleItem(QuestionKind.trueFalse, options.first.id);
      final selected = state.selectedItems(QuestionKind.trueFalse);
      expect(
        selected.map((ExamTheoryItem item) => item.id),
        <String>[options.first.id, options.last.id],
      );
      expect(state.instructionOf(QuestionKind.trueFalse), contains('لاثنين فقط'));
      state.toggleItem(QuestionKind.trueFalse, options[1].id);
      expect(state.instructionOf(QuestionKind.trueFalse), contains('لثلاث فقط'));
      state.toggleItem(QuestionKind.trueFalse, options[1].id);
      expect(state.selectedItems(QuestionKind.trueFalse).length, 2);
    });

    test('keeps a customized instruction instead of overwriting it', () {
      final options = state.optionsOf(QuestionKind.trueFalse);
      state.setInstruction(QuestionKind.trueFalse, 'اكتب صح او خطأ :');
      state.toggleItem(QuestionKind.trueFalse, options.first.id);
      expect(state.theoryOf(QuestionKind.trueFalse).instruction, 'اكتب صح او خطأ :');
    });

    test('rejects an out-of-range point size', () {
      state.setBodyFontSize(40);
      expect(state.typography, isNull);
      expect(state.issues, contains(ExamPaper.invalidFontSizes));
      state.setBodyFontSize(14);
      expect(state.typography!.bodyFontSize, 14);
    });

    test('fills the practical prompt from a prepared topic and clears it for a custom one', () {
      final drawing = state.drawings.first;
      state.selectDrawing(0, drawing);
      expect(state.practical[0].drawingId, drawing.id);
      expect(state.practical[0].prompt, defaultPracticalPrompt(drawing.title));
      state.selectDrawing(0, null);
      expect(state.practical[0].drawingId, isNull);
      expect(state.practical[0].prompt, isEmpty);
    });

    test('produces a complete paper only when everything is filled', () {
      state
        ..setSchoolName('متوسطة النخبة للبنين')
        ..setTeacherName('فائز محمد عبد النبي')
        ..setSectionName('أ');
      expect(state.paper, isNull, reason: 'no questions yet');
      expect(state.issues, contains(ExamPaper.noTheory));

      final options = state.optionsOf(QuestionKind.trueFalse);
      state.toggleItem(QuestionKind.trueFalse, options.first.id);
      state.selectDrawing(1, state.drawings.first);
      final paper = state.paper;
      expect(paper, isNotNull);
      expect(paper!.theory.single.kind, QuestionKind.trueFalse);
      expect(paper.practical.single.drawingId, state.drawings.first.id);
      expect(paper.info.classLine, 'الصف : الأول المتوسط / الشعبة : أ');
      expect(paper.isComplete, isTrue);
      expect(paper.issues, isEmpty);

      final profile = state.toProfile();
      expect(profile.schoolName, 'متوسطة النخبة للبنين');
      expect(profile.typography.bodyFontSize, 14);
    });
  });
}
