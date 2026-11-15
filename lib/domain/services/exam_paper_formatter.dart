/// Text rendering shared by the Word exporter, the review panel and the tests.
///
/// Keeping the wording and the numbering in one place guarantees that the
/// preview the teacher reads is exactly what the exported file contains.
library;

import '../models/exam_paper.dart';
import '../models/library.dart';

/// One documented question offered by the composer, with its unit title.
class ExamQuestionOption {
  const ExamQuestionOption({
    required this.question,
    required this.unitId,
    required this.unitTitle,
  });

  final Question question;
  final String unitId;
  final String unitTitle;

  String get id => question.id;
}

/// Offered questions of every kind, in curriculum order: units in their
/// document order, questions in the order of the source file.
List<ExamQuestionOption> examQuestionOptions(Iterable<LearningUnit> units) {
  final options = <ExamQuestionOption>[];
  for (final LearningUnit unit in _orderedUnits(units)) {
    for (final Question question in unit.questions) {
      options.add(
        ExamQuestionOption(question: question, unitId: unit.id, unitTitle: unit.title),
      );
    }
  }
  return List<ExamQuestionOption>.unmodifiable(options);
}

/// Same ordering rule as the printing plan: keep the sections in the order they
/// appear in the library, then sort by unit number.
List<LearningUnit> _orderedUnits(Iterable<LearningUnit> units) {
  final list = units.toList(growable: false);
  final sectionOrder = <String, int>{};
  for (final LearningUnit unit in list) {
    sectionOrder.putIfAbsent(unit.sectionId, () => sectionOrder.length);
  }
  final decorated = <_IndexedUnit>[
    for (var i = 0; i < list.length; i++) _IndexedUnit(list[i], i),
  ];
  decorated.sort((_IndexedUnit a, _IndexedUnit b) {
    final section =
        sectionOrder[a.unit.sectionId]!.compareTo(sectionOrder[b.unit.sectionId]!);
    if (section != 0) {
      return section;
    }
    final order = a.unit.order.compareTo(b.unit.order);
    return order != 0 ? order : a.index.compareTo(b.index);
  });
  return <LearningUnit>[for (final _IndexedUnit item in decorated) item.unit];
}

class _IndexedUnit {
  const _IndexedUnit(this.unit, this.index);

  final LearningUnit unit;
  final int index;
}

/// Prepared drawing topics, in document order.
List<TopicDrawing> examDrawingOptions(Iterable<TopicDrawing> drawings) {
  final list = drawings.toList(growable: true)
    ..sort((TopicDrawing a, TopicDrawing b) {
      final order = a.order.compareTo(b.order);
      return order != 0 ? order : a.id.compareTo(b.id);
    });
  return List<TopicDrawing>.unmodifiable(list);
}

/// The text of one theoretical item, exactly as it appears on the paper.
String examTheoryItemText(ExamTheoryItem item) {
  final prompt = item.prompt.trim();
  switch (item.kind) {
    case QuestionKind.trueFalse:
      return '$prompt        (                )';
    case QuestionKind.choice:
      if (item.options.isEmpty) {
        return prompt;
      }
      return '$prompt   ( ${item.options.map((String option) => option.trim()).join('   -   ')} )';
    case QuestionKind.open:
      return prompt;
  }
}

/// Blank numbered answer lines of an enumeration question.
List<String> examAnswerLines(ExamTheoryQuestion question) {
  return <String>[
    for (var i = 0; i < question.answerLineCount; i++)
      '${i + 1}- ${'.' * 46}',
  ];
}

/// The whole paper as readable text: used by the review panel.
String examPaperAsPlainText(ExamPaper paper) {
  final buffer = StringBuffer();
  final info = paper.info;
  buffer
    ..writeln('ادارة')
    ..writeln(info.school)
    ..writeln(info.examTitleLine)
    ..writeln(info.yearLine)
    ..writeln('التربية الفنية')
    ..writeln('الاسم :')
    ..writeln(info.classLine)
    ..writeln('الرقم الامتحاني :')
    ..writeln()
    ..writeln('${paper.theoryHeader} ( ${paper.theoryDegree} درجة )');

  var theoryIndex = 0;
  for (final ExamTheoryQuestion question in paper.theory) {
    if (question.isEmpty) {
      continue;
    }
    theoryIndex++;
    buffer.writeln(examTheoryHeading(question, theoryIndex));
    var itemIndex = 0;
    for (final ExamTheoryItem item in question.items) {
      itemIndex++;
      buffer.writeln('$itemIndex- ${examTheoryItemText(item)}');
      if (item.kind == QuestionKind.open) {
        for (final String line in examAnswerLines(question)) {
          buffer.writeln(line);
        }
      }
    }
    buffer.writeln();
  }

  buffer.writeln('${paper.practicalHeader} ( ${paper.practicalDegree} درجة )');
  for (var i = 0; i < paper.practical.length; i++) {
    final ExamPracticalQuestion question = paper.practical[i];
    buffer.writeln('${examQuestionNumber(i)}: ${question.prompt.trim()}   ( ${question.degree} درجة )');
  }
  buffer
    ..writeln()
    ..writeln('تمنياتي لكم بالتوفيق والنجاح')
    ..writeln('مدرس المادة')
    ..writeln(info.teacherName.trim());
  return buffer.toString();
}

/// `س1: <instruction>   ( 6 درجة )`
String examTheoryHeading(ExamTheoryQuestion question, int index) {
  return '${examQuestionTitle(question, index)}   ( ${question.degree} درجة )';
}

/// File name of the exported document, safe on Android and Windows.
String examPaperFileName(ExamPaper paper) {
  final info = paper.info;
  final grade = info.gradeLabel.trim().isEmpty ? 'امتحان' : info.gradeLabel.trim();
  final raw = 'امتحان ${info.term.label} - $grade - ${info.academicYear.trim()}';
  return '${sanitizeExamFileName(raw)}.docx';
}

/// Removes the characters Windows forbids in file names and collapses spaces.
String sanitizeExamFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[\\/:*?"<>|\u0000-\u001f]'), '-')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  return cleaned.isEmpty ? 'mirsam-exam' : cleaned;
}

/// The grade label printed in the header: `الصف الأول المتوسط` becomes
/// `الأول المتوسط`, as in the official paper.
String examGradeLabel(String gradeTitle) {
  final title = gradeTitle.trim();
  if (title.startsWith('الصف ')) {
    return title.substring('الصف '.length).trim();
  }
  return title;
}
