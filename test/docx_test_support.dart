import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/docx/stored_zip_writer.dart';
import 'package:mirsam/domain/models/exam_paper.dart';
import 'package:mirsam/domain/models/library.dart';

/// Reads a ZIP archive written by [buildStoredZip] independently of the writer:
/// it walks the central directory, checks every CRC and fails on a compressed
/// entry, so a broken archive can never pass the tests silently.
Map<String, List<int>> readStoredZip(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var endOfCentralDirectory = -1;
  for (var i = bytes.length - 22; i >= 0; i--) {
    if (data.getUint32(i, Endian.little) == 0x06054b50) {
      endOfCentralDirectory = i;
      break;
    }
  }
  expect(endOfCentralDirectory, isNonNegative, reason: 'end of central directory');
  final count = data.getUint16(endOfCentralDirectory + 10, Endian.little);
  expect(count, greaterThan(0));
  var offset = data.getUint32(endOfCentralDirectory + 16, Endian.little);
  final entries = <String, List<int>>{};
  for (var i = 0; i < count; i++) {
    expect(data.getUint32(offset, Endian.little), 0x02014b50, reason: 'central header $i');
    final method = data.getUint16(offset + 10, Endian.little);
    final crc = data.getUint32(offset + 16, Endian.little);
    final size = data.getUint32(offset + 24, Endian.little);
    final nameLength = data.getUint16(offset + 28, Endian.little);
    final extraLength = data.getUint16(offset + 30, Endian.little);
    final commentLength = data.getUint16(offset + 32, Endian.little);
    final localOffset = data.getUint32(offset + 42, Endian.little);
    final name = utf8.decode(bytes.sublist(offset + 46, offset + 46 + nameLength));
    expect(method, 0, reason: '$name must be stored uncompressed');
    final localNameLength = data.getUint16(localOffset + 26, Endian.little);
    final localExtraLength = data.getUint16(localOffset + 28, Endian.little);
    final start = localOffset + 30 + localNameLength + localExtraLength;
    final content = bytes.sublist(start, start + size);
    expect(crc32(content), crc, reason: 'CRC of $name');
    entries[name] = content;
    offset += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

/// The `word/document.xml` part of a `.docx` file produced by the builder.
String documentXmlOf(Uint8List bytes) {
  final entries = readStoredZip(bytes);
  final document = entries['word/document.xml'];
  expect(document, isNotNull, reason: 'the package must contain word/document.xml');
  return utf8.decode(document!);
}

/// Minimal XML well-formedness check: balanced tags, no stray angle brackets
/// and no invalid entities inside the text nodes.
void expectWellFormedXml(String xml) {
  final tag = RegExp(
    r'<\?.*?\?>|<!--.*?-->|</([A-Za-z0-9:_-]+)\s*>|<([A-Za-z0-9:_-]+)([^>]*?)(/?)>',
    dotAll: true,
  );
  final stack = <String>[];
  var consumed = 0;
  for (final match in tag.allMatches(xml)) {
    final text = xml.substring(consumed, match.start);
    expect(
      text.contains('<') || text.contains('>'),
      isFalse,
      reason: 'stray angle bracket before ${match.group(0)}',
    );
    expect(
      RegExp(r'&(?!(amp|lt|gt|quot|apos|#\d+);)').hasMatch(text),
      isFalse,
      reason: 'unescaped ampersand before ${match.group(0)}',
    );
    consumed = match.end;
    final raw = match.group(0)!;
    if (raw.startsWith('<?') || raw.startsWith('<!--')) {
      continue;
    }
    final close = match.group(1);
    final open = match.group(2);
    if (close != null) {
      expect(stack.isNotEmpty && stack.last == close, isTrue, reason: 'unbalanced </$close>');
      stack.removeLast();
    } else if (open != null && match.group(4) != '/') {
      stack.add(open);
    }
  }
  expect(stack, isEmpty, reason: 'unclosed tags: $stack');
}

/// A complete paper with the wording of the official document.
ExamPaper buildSamplePaper({
  String school = 'متوسطة النخبة للبنين',
  String teacher = 'فائز محمد عبد النبي',
  String section = 'أ',
  String year = '2025 – 2026',
  ExamTerm term = ExamTerm.midYear,
  ExamRound round = ExamRound.first,
  ExamPaperTypography typography = const ExamPaperTypography(),
}) {
  return ExamPaper(
    info: ExamPaperInfo(
      schoolName: school,
      gradeLabel: 'الأول المتوسط',
      sectionName: section,
      term: term,
      round: round,
      academicYear: year,
      teacherName: teacher,
    ),
    typography: typography,
    theory: const <ExamTheoryQuestion>[
      ExamTheoryQuestion(
        kind: QuestionKind.trueFalse,
        instruction: 'ضع علامة صح امام العبارة الصحيحة وعلامة خطأ امام العبارة الخاطئة لثلاث فقط :',
        degree: 6,
        items: <ExamTheoryItem>[
          ExamTheoryItem(
            id: 'q-tf-1',
            kind: QuestionKind.trueFalse,
            prompt: 'تمتاز صفائح النحاس بخفة الوزن .',
          ),
          ExamTheoryItem(
            id: 'q-tf-2',
            kind: QuestionKind.trueFalse,
            prompt: 'اعمال الخشب من الاعمال المسرحية .',
          ),
        ],
      ),
      ExamTheoryQuestion(
        kind: QuestionKind.choice,
        instruction: 'اختر الاجابة الصحيحة ما بين الاقواس :',
        degree: 4,
        items: <ExamTheoryItem>[
          ExamTheoryItem(
            id: 'q-mc-1',
            kind: QuestionKind.choice,
            prompt: 'النحت البارز هو عمل شكل من الطين على',
            options: <String>['قاعده', 'الهواء', 'القصب'],
          ),
        ],
      ),
      ExamTheoryQuestion(
        kind: QuestionKind.open,
        instruction: 'عدد ما يأتي :',
        degree: 15,
        items: <ExamTheoryItem>[
          ExamTheoryItem(
            id: 'q-op-1',
            kind: QuestionKind.open,
            prompt: 'عدد اثنين من ادوات النشر والقطع ؟',
          ),
        ],
      ),
    ],
    practical: const <ExamPracticalQuestion>[
      ExamPracticalQuestion(
        prompt: 'ارسم موضوع «تصميم غلاف كتاب» مستخدماً الواناً مناسبة ؟',
        degree: 35,
        drawingId: 'drawing-01',
        drawingTitle: 'تصميم غلاف كتاب',
      ),
      ExamPracticalQuestion(prompt: 'استخدم الالوان في رسم احد انواع الزخرفة ؟', degree: 35),
    ],
    theoryDegree: 10,
    practicalDegree: 70,
  );
}
