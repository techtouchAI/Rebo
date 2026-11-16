/// Models of the exam paper written in the application and exported to a Word
/// file.
///
/// The document structure follows the official paper of the project
/// (`الاول.docx`): a three-column header, the grade table, the theoretical
/// section (true/false, choice, enumeration), the practical section and the
/// closing line with the teacher's name. Nothing here knows about Flutter or
/// about the DOCX package; the exporter in `data/local/docx` consumes these
/// objects.
library;

import '../../core/utils/arabic_text.dart';
import 'library.dart';

/// Word-safe Arabic typefaces offered for the exported document.
///
/// The DOCX stores the family name; Word renders it with the installed family
/// of the same name, so every choice is either a Windows Arabic family or the
/// free Amiri face the project already bundles.
enum ExamPaperFont {
  traditionalArabic('Traditional Arabic', 'تقليدي'),
  simplifiedArabic('Simplified Arabic', 'مبسّط'),
  sakkalMajalla('Sakkal Majalla', 'سكّال مجلّة'),
  arial('Arial', 'آريال'),
  timesNewRoman('Times New Roman', 'تايمز نيو رومان'),
  amiri('Amiri', 'أميري');

  const ExamPaperFont(this.family, this.label);

  /// The family name written into the DOCX run properties.
  final String family;

  /// Arabic label of the composer.
  final String label;
}

/// Typography of the exported paper, in points.
///
/// These sizes belong to the file only: they never change the reading settings
/// of the application. The DOCX stores half-points, hence the `* 2` getters.
class ExamPaperTypography {
  const ExamPaperTypography({
    this.font = ExamPaperFont.traditionalArabic,
    this.headerFontSize = defaultHeaderFontSize,
    this.bodyFontSize = defaultBodyFontSize,
    this.headingFontSize = defaultHeadingFontSize,
    this.lineSpacingPercent = defaultLineSpacingPercent,
  });

  /// Matches the official paper: 12 pt header, 14 pt questions, 16 pt section
  /// titles and the `multiple 1.15` spacing Word writes for `line: 360`.
  static const int defaultHeaderFontSize = 12;
  static const int defaultBodyFontSize = 14;
  static const int defaultHeadingFontSize = 16;
  static const int minFontSize = 8;
  static const int maxFontSize = 32;

  /// Line spacing as a percentage of the default. The project starts from a
  /// tightened 55 % so a full paper fits the page; 100 % restores the official
  /// spacing of the source document.
  static const int defaultLineSpacingPercent = 55;
  static const int minLineSpacingPercent = 50;
  static const int maxLineSpacingPercent = 200;

  /// `w:line` value of the default spacing (240ths of a line, `auto` rule).
  static const int baseLineTwips = 360;

  final ExamPaperFont font;
  final int headerFontSize;
  final int bodyFontSize;
  final int headingFontSize;
  final int lineSpacingPercent;

  static bool isValidFontSize(int? size) =>
      size != null &&
      size >= minFontSize &&
      size <= maxFontSize;

  static bool isValidLineSpacing(int? percent) =>
      percent != null &&
      percent >= minLineSpacingPercent &&
      percent <= maxLineSpacingPercent;

  bool get isValid =>
      isValidFontSize(headerFontSize) &&
      isValidFontSize(bodyFontSize) &&
      isValidFontSize(headingFontSize) &&
      isValidLineSpacing(lineSpacingPercent);

  int get headerHalfPoints => headerFontSize * 2;
  int get bodyHalfPoints => bodyFontSize * 2;
  int get headingHalfPoints => headingFontSize * 2;

  /// The `w:line` of the tightened or widened text, in 240ths of a line.
  int get lineTwips => (baseLineTwips * lineSpacingPercent / 100).round();

  /// True when the user kept the default spacing, so the document matches the
  /// official paper exactly.
  bool get usesDefaultLineSpacing => lineSpacingPercent == defaultLineSpacingPercent;

  /// The separator lines are drawn two points above the section titles, as in
  /// the official paper.
  int get ruleHalfPoints => (headingFontSize + 2).clamp(minFontSize, maxFontSize) * 2;

  ExamPaperTypography copyWith({
    ExamPaperFont? font,
    int? headerFontSize,
    int? bodyFontSize,
    int? headingFontSize,
    int? lineSpacingPercent,
  }) {
    return ExamPaperTypography(
      font: font ?? this.font,
      headerFontSize: headerFontSize ?? this.headerFontSize,
      bodyFontSize: bodyFontSize ?? this.bodyFontSize,
      headingFontSize: headingFontSize ?? this.headingFontSize,
      lineSpacingPercent: lineSpacingPercent ?? this.lineSpacingPercent,
    );
  }
}

/// Which exam of the school year is being written.
enum ExamTerm {
  midYear('نصف السنة', 'اسئلة امتحانات نصف السنة'),
  endOfYear('آخر السنة', 'اسئلة امتحانات نهاية السنة');

  const ExamTerm(this.label, this.documentTitle);

  /// Label shown in the composer.
  final String label;

  /// First line of the header table.
  final String documentTitle;
}

/// The round of the exam, printed next to the exam title.
enum ExamRound {
  first('الدور الأول'),
  second('الدور الثاني');

  const ExamRound(this.label);

  final String label;
}

/// The written fields of the header and of the closing line.
class ExamPaperInfo {
  const ExamPaperInfo({
    required this.schoolName,
    required this.gradeLabel,
    required this.sectionName,
    required this.term,
    required this.round,
    required this.academicYear,
    required this.teacherName,
  });

  final String schoolName;

  /// Printed as `الصف : <gradeLabel> / الشعبة : <sectionName>`.
  final String gradeLabel;
  final String sectionName;
  final ExamTerm term;
  final ExamRound round;
  final String academicYear;
  final String teacherName;

  String get school => schoolName.trim();

  String get classLine {
    final grade = gradeLabel.trim();
    final section = sectionName.trim();
    if (section.isEmpty) {
      return 'الصف : $grade / الشعبة :';
    }
    return 'الصف : $grade / الشعبة : $section';
  }

  String get examTitleLine => '${term.documentTitle} / ${round.label}';

  String get yearLine => 'للعام الدراسي ${academicYear.trim()}';

  /// Fields the teacher must fill before the file is exported.
  List<String> get missingFields {
    return <String>[
      if (school.isEmpty) missingSchool,
      if (gradeLabel.trim().isEmpty) missingGrade,
      if (academicYear.trim().isEmpty) missingYear,
      if (teacherName.trim().isEmpty) missingTeacher,
    ];
  }

  bool get isComplete => missingFields.isEmpty;

  ExamPaperInfo copyWith({
    String? schoolName,
    String? gradeLabel,
    String? sectionName,
    ExamTerm? term,
    ExamRound? round,
    String? academicYear,
    String? teacherName,
  }) {
    return ExamPaperInfo(
      schoolName: schoolName ?? this.schoolName,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      sectionName: sectionName ?? this.sectionName,
      term: term ?? this.term,
      round: round ?? this.round,
      academicYear: academicYear ?? this.academicYear,
      teacherName: teacherName ?? this.teacherName,
    );
  }

  static const String missingSchool = 'أدخل اسم المدرسة';
  static const String missingGrade = 'أدخل الصف';
  static const String missingYear = 'أدخل السنة الدراسية';
  static const String missingTeacher = 'أدخل اسم المدرس';
}

/// One statement or question taken from the documented curriculum questions.
class ExamTheoryItem {
  const ExamTheoryItem({
    required this.id,
    required this.kind,
    required this.prompt,
    this.options = const <String>[],
  });

  /// Identifier of the source question, so a selection survives a rebuild.
  final String id;
  final QuestionKind kind;
  final String prompt;
  final List<String> options;

  /// Builds an item from a documented question.
  ///
  /// [id] defaults to the question id, but callers that select across units
  /// must pass the globally unique option id (question ids repeat per unit).
  factory ExamTheoryItem.fromQuestion(Question question, {String? id}) {
    return ExamTheoryItem(
      id: id ?? question.id,
      kind: question.kind,
      prompt: question.prompt,
      options: List<String>.unmodifiable(question.options),
    );
  }
}

/// One of the three theoretical questions of the paper.
///
/// The instruction is editable text; the degree is the mark printed next to it.
class ExamTheoryQuestion {
  const ExamTheoryQuestion({
    required this.kind,
    required this.instruction,
    required this.degree,
    required this.items,
    this.answerLineCount = defaultAnswerLineCount,
  });

  static const int defaultAnswerLineCount = 2;
  static const int maxAnswerLineCount = 6;

  final QuestionKind kind;
  final String instruction;
  final int degree;
  final List<ExamTheoryItem> items;

  /// Blank numbered lines printed after an enumeration question.
  final int answerLineCount;

  bool get isEmpty => items.isEmpty;

  ExamTheoryQuestion copyWith({
    String? instruction,
    int? degree,
    List<ExamTheoryItem>? items,
    int? answerLineCount,
  }) {
    return ExamTheoryQuestion(
      kind: kind,
      instruction: instruction ?? this.instruction,
      degree: degree ?? this.degree,
      items: items ?? this.items,
      answerLineCount: answerLineCount ?? this.answerLineCount,
    );
  }

  /// The three kinds always appear in this order in the paper.
  static const List<QuestionKind> kinds = <QuestionKind>[
    QuestionKind.trueFalse,
    QuestionKind.choice,
    QuestionKind.open,
  ];
}

/// One question of the practical section.
///
/// It is either a prepared drawing topic of the curriculum ([drawingId] is set)
/// or a question written by the teacher. The prompt stays editable in both
/// cases.
class ExamPracticalQuestion {
  const ExamPracticalQuestion({
    required this.prompt,
    required this.degree,
    this.drawingId,
    this.drawingTitle,
  });

  final String prompt;
  final int degree;
  final String? drawingId;
  final String? drawingTitle;

  bool get isEmpty => prompt.trim().isEmpty;

  ExamPracticalQuestion copyWith({
    String? prompt,
    int? degree,
    String? drawingId,
    String? drawingTitle,
  }) {
    return ExamPracticalQuestion(
      prompt: prompt ?? this.prompt,
      degree: degree ?? this.degree,
      drawingId: drawingId ?? this.drawingId,
      drawingTitle: drawingTitle ?? this.drawingTitle,
    );
  }
}

/// A complete exam paper, ready to be exported.
class ExamPaper {
  const ExamPaper({
    required this.info,
    required this.typography,
    required this.theory,
    required this.practical,
    required this.theoryDegree,
    required this.practicalDegree,
    this.theoryHeader = defaultTheoryHeader,
    this.practicalHeader = defaultPracticalHeader,
  });

  static const String defaultTheoryHeader = 'المادة النظرية / اجب عن سؤالين فقط';
  static const String defaultPracticalHeader = 'المادة العملية : اجب عن سؤالين فقط';

  /// Filler of the printable line under the theory heading, exactly as in the
  /// requested layout: `____( 30 درجة ) لكل سؤال ( 15 درجة )`.
  static const String degreeRule = '____________';

  static const int minDegree = 0;
  static const int maxDegree = 100;

  final ExamPaperInfo info;
  final ExamPaperTypography typography;

  /// Theoretical questions in the official order, without the empty ones.
  final List<ExamTheoryQuestion> theory;

  /// Practical questions in order, without the empty ones.
  final List<ExamPracticalQuestion> practical;

  final int theoryDegree;
  final int practicalDegree;
  final String theoryHeader;
  final String practicalHeader;

  /// The theory heading as printed, on its own line:
  /// `المادة النظرية / اجب عن سؤالين فقط ____( 30 درجة ) لكل سؤال ( 15 درجة )`.
  String get theoryHeadingLine {
    final header = theoryHeader.trim();
    final buffer = StringBuffer()
      ..write(header.isEmpty ? defaultTheoryHeader : header)
      ..write(' $degreeRule( $theoryDegree درجة )');
    final perQuestion = theoryPerQuestionDegree;
    if (perQuestion != null) {
      buffer.write(' لكل سؤال ( $perQuestion درجة )');
    }
    return buffer.toString();
  }

  /// The theory heading exactly as typed by the teacher, without the rule and
  /// the degrees; the editor edits this part.
  String get theoryHeadingText => theoryHeader.trim().isEmpty
      ? defaultTheoryHeader
      : theoryHeader.trim();

  /// Degree of every theoretical question; null when the total cannot be split
  /// evenly between the two questions the paper asks for.
  int? get theoryPerQuestionDegree {
    if (theoryQuestionCount <= 0) {
      return null;
    }
    final split = theoryDegree ~/ theoryQuestionCount;
    return theoryDegree % theoryQuestionCount == 0 ? split : null;
  }

  /// Number of theoretical questions actually written, not the number of items.
  int get theoryQuestionCount => theory.length;

  /// The practical heading as printed, e.g. `المادة العملية : اجب عن سؤالين فقط ( 70 درجة )`.
  String get practicalHeadingLine {
    final header = practicalHeader.trim();
    final base = header.isEmpty ? defaultPracticalHeader : header;
    return '$base ( $practicalDegree درجة )';
  }

  List<ExamTheoryItem> get theoryItems => <ExamTheoryItem>[
    for (final ExamTheoryQuestion question in theory) ...question.items,
  ];

  int get theoryItemCount => theoryItems.length;

  int get practicalCount => practical.length;

  bool get hasTheory => theoryItemCount > 0;

  bool get hasPractical => practical.isNotEmpty;

  int get questionCount => theory.where((ExamTheoryQuestion item) => !item.isEmpty).length + practical.length;

  /// A copy with the parts that change while the teacher edits the paper.
  ExamPaper copyWith({
    ExamPaperInfo? info,
    ExamPaperTypography? typography,
    List<ExamTheoryQuestion>? theory,
    List<ExamPracticalQuestion>? practical,
    int? theoryDegree,
    int? practicalDegree,
    String? theoryHeader,
    String? practicalHeader,
  }) {
    return ExamPaper(
      info: info ?? this.info,
      typography: typography ?? this.typography,
      theory: theory ?? this.theory,
      practical: practical ?? this.practical,
      theoryDegree: theoryDegree ?? this.theoryDegree,
      practicalDegree: practicalDegree ?? this.practicalDegree,
      theoryHeader: theoryHeader ?? this.theoryHeader,
      practicalHeader: practicalHeader ?? this.practicalHeader,
    );
  }

  static bool isValidDegree(int? degree) =>
      degree != null && degree >= minDegree && degree <= maxDegree;

  /// Everything that still prevents a faithful export, in Arabic, so that the
  /// screen and the tests share one source of truth.
  List<String> get issues {
    final issues = <String>[...info.missingFields];
    if (!typography.isValid) {
      issues.add(invalidFontSizes);
    }
    if (!ExamPaperTypography.isValidLineSpacing(typography.lineSpacingPercent)) {
      issues.add(invalidLineSpacing);
    }
    if (!hasTheory) {
      issues.add(noTheory);
    }
    if (!hasPractical) {
      issues.add(noPractical);
    }
    if (!isValidDegree(theoryDegree) || !isValidDegree(practicalDegree)) {
      issues.add(invalidDegrees);
    }
    for (final ExamTheoryQuestion question in theory) {
      if (!isValidDegree(question.degree)) {
        issues.add(invalidDegrees);
        break;
      }
    }
    for (final ExamPracticalQuestion question in practical) {
      if (!isValidDegree(question.degree)) {
        issues.add(invalidDegrees);
        break;
      }
    }
    return List<String>.unmodifiable(issues);
  }

  bool get isComplete => issues.isEmpty;

  static const String noTheory = 'اختر سؤالاً نظرياً واحداً على الأقل';
  static const String noPractical = 'أضف سؤالاً عملياً واحداً على الأقل';
  static const String invalidDegrees = 'أدخل درجات صحيحة بين ٠ و ١٠٠';
  static const String invalidFontSizes = 'أدخل أحجام خط صحيحة';
  static const String invalidLineSpacing =
      'أدخل نسبة تباعد أسطر بين ${ExamPaperTypography.minLineSpacingPercent} و'
      ' ${ExamPaperTypography.maxLineSpacingPercent}';
}

/// `س1`, `س2`, … with Western digits, as in the official paper.
String examQuestionNumber(int index) => 'س${index + 1}';

/// Title of one theoretical question, e.g. `س2: اختر الاجابة الصحيحة …`.
String examQuestionTitle(ExamTheoryQuestion question, int index) {
  final instruction = question.instruction.trim();
  final prefix = '${examQuestionNumber(index)}:';
  return instruction.isEmpty ? prefix : '$prefix $instruction';
}

/// The instruction printed above the items of each kind, adapted to the number
/// of chosen items so that the wording of the paper stays correct.
String defaultTheoryInstruction(QuestionKind kind, int itemCount) {
  switch (kind) {
    case QuestionKind.trueFalse:
      final count = itemCount <= 0 ? '' : ' ل${_countWord(itemCount)} فقط';
      return 'ضع علامة صح امام العبارة الصحيحة وعلامة خطأ امام العبارة الخاطئة$count :';
    case QuestionKind.choice:
      return 'اختر الاجابة الصحيحة ما بين الاقواس :';
    case QuestionKind.open:
      return 'عدد ما يأتي :';
  }
}

/// Arabic label of a theoretical question kind.
String theoryKindLabel(QuestionKind kind) {
  switch (kind) {
    case QuestionKind.trueFalse:
      return 'الصح والخطأ';
    case QuestionKind.choice:
      return 'الاختيارات';
    case QuestionKind.open:
      return 'التعداد';
  }
}

/// Arabic-Indic count used inside the instruction wording.
String _countWord(int count) {
  const words = <int, String>{
    1: 'واحد',
    2: 'اثنين',
    3: 'ثلاث',
    4: 'أربع',
    5: 'خمس',
    6: 'ست',
    7: 'سبع',
    8: 'ثمان',
    9: 'تسع',
    10: 'عشر',
  };
  final word = words[count];
  return word ?? toArabicDigits('$count');
}

/// The default practical question of a prepared drawing topic.
String defaultPracticalPrompt(String drawingTitle) {
  final title = drawingTitle.trim();
  if (title.isEmpty) {
    return '';
  }
  return 'ارسم موضوع «$title» مستخدماً الواناً مناسبة ؟';
}

/// The academic year shown under the exam title, derived from the device date
/// (the school year starts in September).
String academicYearLabel(DateTime now) {
  final year = now.month >= 9 ? now.year : now.year - 1;
  return '$year – ${year + 1}';
}
