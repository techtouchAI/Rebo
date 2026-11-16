import 'package:flutter/material.dart';

import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../state/exam_composer_state.dart';

/// Text controllers of the composer, owned by the screen.
///
/// Keeping them here — instead of inside the step widgets — means the typed
/// values survive moving back and forth between the five steps.
class ExamComposerControllers {
  ExamComposerControllers(ExamComposerState state)
      : school = TextEditingController(text: state.schoolName),
        grade = TextEditingController(text: state.gradeLabel),
        section = TextEditingController(text: state.sectionName),
        year = TextEditingController(text: state.academicYear),
        teacher = TextEditingController(text: state.teacherName),
        headerSize = TextEditingController(text: '${state.headerFontSize ?? ''}'),
        bodySize = TextEditingController(text: '${state.bodyFontSize ?? ''}'),
        headingSize = TextEditingController(text: '${state.headingFontSize ?? ''}'),
        lineSpacing = TextEditingController(
          text: '${state.lineSpacingPercent ?? ''}',
        ),
        theoryDegree = TextEditingController(text: '${state.theoryDegree ?? ''}'),
        practicalDegree = TextEditingController(text: '${state.practicalDegree ?? ''}'),
        theoryHeader = TextEditingController(text: state.theoryHeader),
        practicalHeader = TextEditingController(text: state.practicalHeader),
        answerLines = TextEditingController(
          text: '${state.answerLineCountOf(QuestionKind.open)}',
        ),
        practicalPrompts = <TextEditingController>[
          for (final ExamPracticalQuestion question in state.practical)
            TextEditingController(text: question.prompt),
        ],
        practicalDegrees = <TextEditingController>[
          for (final ExamPracticalQuestion question in state.practical)
            TextEditingController(text: '${question.degree}'),
        ] {
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      instructions[kind] = TextEditingController(text: state.instructionOf(kind));
      degrees[kind] = TextEditingController(text: '${state.degreeOf(kind) ?? ''}');
    }
  }

  final TextEditingController school;
  final TextEditingController grade;
  final TextEditingController section;
  final TextEditingController year;
  final TextEditingController teacher;
  final TextEditingController headerSize;
  final TextEditingController bodySize;
  final TextEditingController headingSize;
  final TextEditingController lineSpacing;
  final TextEditingController theoryDegree;
  final TextEditingController practicalDegree;
  final TextEditingController theoryHeader;
  final TextEditingController practicalHeader;
  final TextEditingController answerLines;
  final List<TextEditingController> practicalPrompts;
  final List<TextEditingController> practicalDegrees;
  final Map<QuestionKind, TextEditingController> instructions =
      <QuestionKind, TextEditingController>{};
  final Map<QuestionKind, TextEditingController> degrees =
      <QuestionKind, TextEditingController>{};

  /// Pushes the values of [state] back into the fields, after a saved group or
  /// a profile replaced them.
  void syncFrom(ExamComposerState state) {
    school.text = state.schoolName;
    grade.text = state.gradeLabel;
    section.text = state.sectionName;
    year.text = state.academicYear;
    teacher.text = state.teacherName;
    headerSize.text = '${state.headerFontSize ?? ''}';
    bodySize.text = '${state.bodyFontSize ?? ''}';
    headingSize.text = '${state.headingFontSize ?? ''}';
    lineSpacing.text = '${state.lineSpacingPercent ?? ''}';
    theoryDegree.text = '${state.theoryDegree ?? ''}';
    practicalDegree.text = '${state.practicalDegree ?? ''}';
    theoryHeader.text = state.theoryHeader;
    practicalHeader.text = state.practicalHeader;
    answerLines.text = '${state.answerLineCountOf(QuestionKind.open)}';
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      instructions[kind]?.text = state.instructionOf(kind);
      degrees[kind]?.text = '${state.degreeOf(kind) ?? ''}';
    }
    for (var i = 0; i < practicalPrompts.length; i++) {
      practicalPrompts[i].text = state.practical[i].prompt;
      practicalDegrees[i].text = '${state.practical[i].degree}';
    }
  }

  void dispose() {
    school.dispose();
    grade.dispose();
    section.dispose();
    year.dispose();
    teacher.dispose();
    headerSize.dispose();
    bodySize.dispose();
    headingSize.dispose();
    lineSpacing.dispose();
    theoryDegree.dispose();
    practicalDegree.dispose();
    theoryHeader.dispose();
    practicalHeader.dispose();
    answerLines.dispose();
    for (final TextEditingController controller in practicalPrompts) {
      controller.dispose();
    }
    for (final TextEditingController controller in practicalDegrees) {
      controller.dispose();
    }
    for (final TextEditingController controller in instructions.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in degrees.values) {
      controller.dispose();
    }
  }
}
