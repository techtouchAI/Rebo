import 'package:flutter/foundation.dart';

import '../../domain/models/exam_paper.dart';
import '../../domain/models/exam_question_bank.dart';
import '../../domain/models/library.dart';
import '../../domain/repositories/exam_profile_repository.dart';
import '../../domain/services/exam_paper_formatter.dart';

/// Mutable draft of the exam paper while the teacher writes it.
///
/// The draft owns every editable value of the composer: the typography, the
/// header fields, the three theoretical selections and the three practical
/// slots. [paper] returns an immutable [ExamPaper] only when the draft is
/// complete, so the screen, the exporter and the tests share one validation.
class ExamComposerState extends ChangeNotifier {
  ExamComposerState({
    required Iterable<LearningUnit> units,
    required Iterable<TopicDrawing> drawings,
    required String gradeLabel,
    DateTime? now,
    ExamProfile profile = const ExamProfile(),
  })  : options = examQuestionOptions(units),
        drawings = examDrawingOptions(drawings),
        _now = now ?? DateTime.now() {
    this.gradeLabel = profile.gradeLabel.trim().isNotEmpty ? profile.gradeLabel : gradeLabel;
    schoolName = profile.schoolName;
    sectionName = profile.sectionName;
    teacherName = profile.teacherName;
    academicYear = academicYearLabel(_now);
    final savedTypography = profile.typography;
    font = savedTypography.font;
    headerFontSize = savedTypography.headerFontSize;
    bodyFontSize = savedTypography.bodyFontSize;
    headingFontSize = savedTypography.headingFontSize;
    lineSpacingPercent = savedTypography.lineSpacingPercent;
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      _selected[kind] = <String>{};
      _instructions[kind] = defaultTheoryInstruction(kind, 0);
      _answerLines[kind] = ExamTheoryQuestion.defaultAnswerLineCount;
      _customizedInstructions[kind] = false;
    }
    _degrees[QuestionKind.trueFalse] = defaultTheoryQuestionDegree;
    _degrees[QuestionKind.choice] = defaultTheoryQuestionDegree;
    _degrees[QuestionKind.open] = defaultTheoryQuestionDegree;
    practical = <ExamPracticalQuestion>[
      for (var i = 0; i < practicalSlotCount; i++)
        const ExamPracticalQuestion(prompt: '', degree: defaultPracticalDegree),
    ];
  }

  static const int practicalSlotCount = 3;
  static const int defaultPracticalDegree = 35;
  /// The requested layout: 30 marks for the theory split into two questions of
  /// 15 marks each, and 70 marks for the practical section.
  static const int defaultTheoryDegree = 30;
  static const int defaultTheoryQuestionDegree = 15;
  static const int defaultTheoryQuestionCount = 2;
  static const int defaultPracticalTotal = 70;

  /// Questions documented in the curriculum, in source order.
  final List<ExamQuestionOption> options;

  /// Prepared drawing topics offered by the practical section.
  final List<TopicDrawing> drawings;

  final DateTime _now;

  // ------------------------------------------------------------ typography ---

  ExamPaperFont font = ExamPaperFont.traditionalArabic;
  int? headerFontSize = ExamPaperTypography.defaultHeaderFontSize;
  int? bodyFontSize = ExamPaperTypography.defaultBodyFontSize;
  int? headingFontSize = ExamPaperTypography.defaultHeadingFontSize;

  /// Line spacing as a percentage; 100 % keeps the official layout.
  int? lineSpacingPercent = ExamPaperTypography.defaultLineSpacingPercent;

  /// Null while one of the sizes or the spacing is empty or out of range.
  ExamPaperTypography? get typography {
    final header = headerFontSize;
    final body = bodyFontSize;
    final heading = headingFontSize;
    final spacing = lineSpacingPercent;
    if (!ExamPaperTypography.isValidFontSize(header) ||
        !ExamPaperTypography.isValidFontSize(body) ||
        !ExamPaperTypography.isValidFontSize(heading) ||
        !ExamPaperTypography.isValidLineSpacing(spacing)) {
      return null;
    }
    return ExamPaperTypography(
      font: font,
      headerFontSize: header!,
      bodyFontSize: body!,
      headingFontSize: heading!,
      lineSpacingPercent: spacing!,
    );
  }

  void setFont(ExamPaperFont value) {
    if (font == value) {
      return;
    }
    font = value;
    notifyListeners();
  }

  void setHeaderFontSize(int? value) {
    if (headerFontSize == value) {
      return;
    }
    headerFontSize = value;
    notifyListeners();
  }

  void setBodyFontSize(int? value) {
    if (bodyFontSize == value) {
      return;
    }
    bodyFontSize = value;
    notifyListeners();
  }

  void setHeadingFontSize(int? value) {
    if (headingFontSize == value) {
      return;
    }
    headingFontSize = value;
    notifyListeners();
  }

  void setLineSpacingPercent(int? value) {
    if (lineSpacingPercent == value) {
      return;
    }
    lineSpacingPercent = value;
    notifyListeners();
  }

  /// Restores the official spacing (100 %) with one tap.
  void resetLineSpacing() =>
      setLineSpacingPercent(ExamPaperTypography.officialLineSpacingPercent);

  // ------------------------------------------------------------------ info ---

  String schoolName = '';
  String gradeLabel = '';
  String sectionName = '';
  String teacherName = '';
  String academicYear = '';
  ExamTerm term = ExamTerm.midYear;
  ExamRound round = ExamRound.first;

  /// The academic year proposed by the device clock, e.g. `2025 – 2026`.
  String get suggestedAcademicYear => academicYearLabel(_now);

  void setSchoolName(String value) {
    schoolName = value;
    notifyListeners();
  }

  void setGradeLabel(String value) {
    gradeLabel = value;
    notifyListeners();
  }

  void setSectionName(String value) {
    sectionName = value;
    notifyListeners();
  }

  void setTeacherName(String value) {
    teacherName = value;
    notifyListeners();
  }

  void setAcademicYear(String value) {
    academicYear = value;
    notifyListeners();
  }

  void setTerm(ExamTerm value) {
    if (term == value) {
      return;
    }
    term = value;
    notifyListeners();
  }

  void setRound(ExamRound value) {
    if (round == value) {
      return;
    }
    round = value;
    notifyListeners();
  }

  // ---------------------------------------------------------------- theory ---

  final Map<QuestionKind, Set<String>> _selected = <QuestionKind, Set<String>>{};
  final Map<QuestionKind, int?> _degrees = <QuestionKind, int?>{};
  final Map<QuestionKind, String> _instructions = <QuestionKind, String>{};
  final Map<QuestionKind, int> _answerLines = <QuestionKind, int>{};
  final Map<QuestionKind, bool> _customizedInstructions = <QuestionKind, bool>{};

  int? theoryDegree = defaultTheoryDegree;
  int? practicalDegree = defaultPracticalTotal;

  /// Editable captions; they keep the official wording until the teacher
  /// changes them.
  String theoryHeader = ExamPaper.defaultTheoryHeader;
  String practicalHeader = ExamPaper.defaultPracticalHeader;

  List<ExamQuestionOption> optionsOf(QuestionKind kind) => <ExamQuestionOption>[
    for (final ExamQuestionOption option in options)
      if (option.question.kind == kind) option,
  ];

  Set<String> selectionOf(QuestionKind kind) =>
      Set<String>.unmodifiable(_selected[kind] ?? const <String>{});

  bool isSelected(QuestionKind kind, String id) =>
      (_selected[kind] ?? const <String>{}).contains(id);

  bool isInstructionCustomized(QuestionKind kind) =>
      _customizedInstructions[kind] ?? false;

  String instructionOf(QuestionKind kind) =>
      _instructions[kind] ?? defaultTheoryInstruction(kind, selectionOf(kind).length);

  int? degreeOf(QuestionKind kind) => _degrees[kind];

  int answerLineCountOf(QuestionKind kind) =>
      _answerLines[kind] ?? ExamTheoryQuestion.defaultAnswerLineCount;

  void toggleItem(QuestionKind kind, String id) {
    final selection = _selected.putIfAbsent(kind, () => <String>{});
    if (!selection.remove(id)) {
      selection.add(id);
    }
    if (!isInstructionCustomized(kind)) {
      _instructions[kind] = defaultTheoryInstruction(kind, selection.length);
    }
    notifyListeners();
  }

  void setDegree(QuestionKind kind, int? degree) {
    _degrees[kind] = degree;
    notifyListeners();
  }

  void setInstruction(QuestionKind kind, String instruction, {bool customized = true}) {
    _instructions[kind] = instruction;
    _customizedInstructions[kind] = customized;
    notifyListeners();
  }

  void setAnswerLineCount(QuestionKind kind, int? count) {
    final safe = (count ?? ExamTheoryQuestion.defaultAnswerLineCount)
        .clamp(1, ExamTheoryQuestion.maxAnswerLineCount);
    _answerLines[kind] = safe;
    notifyListeners();
  }

  void setTheoryDegree(int? degree) {
    theoryDegree = degree;
    notifyListeners();
  }

  void setPracticalDegree(int? degree) {
    practicalDegree = degree;
    notifyListeners();
  }

  void setTheoryHeader(String value) {
    if (theoryHeader == value) {
      return;
    }
    theoryHeader = value;
    notifyListeners();
  }

  void setPracticalHeader(String value) {
    if (practicalHeader == value) {
      return;
    }
    practicalHeader = value;
    notifyListeners();
  }

  /// Restores both captions to the official wording.
  void resetHeaders() {
    theoryHeader = ExamPaper.defaultTheoryHeader;
    practicalHeader = ExamPaper.defaultPracticalHeader;
    notifyListeners();
  }

  /// The items of one kind, in curriculum order (the order of the source file).
  List<ExamTheoryItem> selectedItems(QuestionKind kind) {
    final selection = _selected[kind] ?? const <String>{};
    return <ExamTheoryItem>[
      for (final ExamQuestionOption option in options)
        if (option.question.kind == kind && selection.contains(option.id))
          ExamTheoryItem.fromQuestion(option.question, id: option.id),
    ];
  }

  ExamTheoryQuestion theoryOf(QuestionKind kind) {
    final items = selectedItems(kind);
    return ExamTheoryQuestion(
      kind: kind,
      instruction: isInstructionCustomized(kind)
          ? instructionOf(kind)
          : defaultTheoryInstruction(kind, items.length),
      degree: _degrees[kind] ?? ExamPaper.minDegree,
      items: List<ExamTheoryItem>.unmodifiable(items),
      answerLineCount: answerLineCountOf(kind),
    );
  }

  List<ExamTheoryQuestion> get theoryQuestions => <ExamTheoryQuestion>[
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) theoryOf(kind),
  ];

  int get theoryItemCount =>
      ExamTheoryQuestion.kinds.fold<int>(0, (int sum, QuestionKind kind) => sum + selectedItems(kind).length);

  // ------------------------------------------------------------- practical ---

  late List<ExamPracticalQuestion> practical;

  void selectDrawing(int index, TopicDrawing? drawing) {
    if (index < 0 || index >= practical.length) {
      return;
    }
    if (drawing == null) {
      practical[index] = ExamPracticalQuestion(
        prompt: '',
        degree: practical[index].degree,
      );
    } else {
      practical[index] = ExamPracticalQuestion(
        prompt: defaultPracticalPrompt(drawing.title),
        degree: practical[index].degree,
        drawingId: drawing.id,
        drawingTitle: drawing.title,
      );
    }
    notifyListeners();
  }

  void setPracticalPrompt(int index, String prompt) {
    if (index < 0 || index >= practical.length) {
      return;
    }
    practical[index] = practical[index].copyWith(prompt: prompt);
    notifyListeners();
  }

  void setPracticalSlotDegree(int index, int? degree) {
    if (index < 0 || index >= practical.length) {
      return;
    }
    practical[index] = practical[index].copyWith(degree: degree ?? ExamPaper.minDegree);
    notifyListeners();
  }

  int get practicalCount =>
      practical.where((ExamPracticalQuestion question) => !question.isEmpty).length;

  // ----------------------------------------------------------------- paper ---

  ExamPaper buildPaperWith(ExamPaperTypography paperTypography) {
    return ExamPaper(
      info: ExamPaperInfo(
        schoolName: schoolName,
        gradeLabel: gradeLabel,
        sectionName: sectionName,
        term: term,
        round: round,
        academicYear: academicYear,
        teacherName: teacherName,
      ),
      typography: paperTypography,
      theory: <ExamTheoryQuestion>[
        for (final ExamTheoryQuestion question in theoryQuestions)
          if (!question.isEmpty) question,
      ],
      practical: <ExamPracticalQuestion>[
        for (final ExamPracticalQuestion question in practical)
          if (!question.isEmpty) question,
      ],
      theoryDegree: theoryDegree ?? -1,
      practicalDegree: practicalDegree ?? -1,
      theoryHeader: theoryHeader,
      practicalHeader: practicalHeader,
    );
  }

  /// A complete paper, or null while something is still missing.
  ExamPaper? get paper {
    final current = typography;
    if (current == null) {
      return null;
    }
    final built = buildPaperWith(current);
    return built.isComplete ? built : null;
  }

  /// Everything that still prevents the export, ready for the bottom bar.
  List<String> get issues {
    final current = typography;
    if (current == null) {
      // Report the spacing on its own so the bottom bar points at the field
      // that is actually empty.
      if (!ExamPaperTypography.isValidLineSpacing(lineSpacingPercent)) {
        if (ExamPaperTypography.isValidFontSize(headerFontSize) &&
            ExamPaperTypography.isValidFontSize(bodyFontSize) &&
            ExamPaperTypography.isValidFontSize(headingFontSize)) {
          return const <String>[ExamPaper.invalidLineSpacing];
        }
      }
      return const <String>[ExamPaper.invalidFontSizes];
    }
    return buildPaperWith(current).issues;
  }

  // ----------------------------------------------------------- question bank ---

  /// The current selection as a bank entry, ready to be stored.
  ///
  /// Empty kinds are left out so the stored group stays compact; the ids are
  /// the unique option ids (`unit:question`) produced by the formatter.
  ExamQuestionBankEntry toBankEntry({
    required String id,
    required String title,
    DateTime? savedAt,
  }) {
    return ExamQuestionBankEntry(
      id: id,
      title: title,
      savedAt: savedAt ?? DateTime.now(),
      selection: <String, List<String>>{
        for (final QuestionKind kind in ExamTheoryQuestion.kinds)
          if (selectionOf(kind).isNotEmpty) kind.name: selectionOf(kind).toList(growable: false),
      },
      practicalPrompts: <String>[
        for (final ExamPracticalQuestion question in practical)
          if (!question.isEmpty) question.prompt.trim(),
      ],
      theoryDegree: theoryDegree ?? ExamQuestionBankEntry.defaultTheoryDegree,
      practicalDegree: practicalDegree ?? ExamQuestionBankEntry.defaultPracticalDegree,
      theoryHeader: theoryHeader,
      practicalHeader: practicalHeader,
    );
  }

  /// Restores a stored group; ids that no longer exist in the curriculum are
  /// ignored instead of breaking the paper.
  void applyBankEntry(ExamQuestionBankEntry entry) {
    final known = <String>{
      for (final ExamQuestionOption option in options) option.id,
    };
    for (final QuestionKind kind in ExamTheoryQuestion.kinds) {
      _selected[kind] = <String>{
        for (final String id in entry.selection[kind.name] ?? const <String>[])
          if (known.contains(id)) id,
      };
      if (!isInstructionCustomized(kind)) {
        _instructions[kind] = defaultTheoryInstruction(kind, _selected[kind]!.length);
      }
    }
    for (var i = 0; i < practical.length; i++) {
      final prompt = i < entry.practicalPrompts.length ? entry.practicalPrompts[i] : '';
      practical[i] = ExamPracticalQuestion(
        prompt: prompt,
        degree: practical[i].degree,
        drawingId: practical[i].drawingId,
        drawingTitle: practical[i].drawingTitle,
      );
    }
    theoryDegree = entry.theoryDegree;
    practicalDegree = entry.practicalDegree;
    theoryHeader = entry.theoryHeader;
    practicalHeader = entry.practicalHeader;
    notifyListeners();
  }

  /// The profile saved after a successful export.
  ExamProfile toProfile() {
    final current = typography ?? const ExamPaperTypography();
    return ExamProfile(
      schoolName: schoolName,
      gradeLabel: gradeLabel,
      sectionName: sectionName,
      teacherName: teacherName,
      typography: current,
    );
  }
}
