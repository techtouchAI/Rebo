import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/docx/exam_docx_builder.dart';
import 'package:mirsam/domain/models/exam_paper.dart';

import 'docx_test_support.dart';

void main() {
  group('package structure', () {
    test('contains every part Word needs and is a valid stored archive', () {
      final bytes = ExamDocxBuilder.build(buildSamplePaper());
      final entries = readStoredZip(bytes);
      expect(
        entries.keys,
        containsAll(<String>[
          '[Content_Types].xml',
          '_rels/.rels',
          'docProps/core.xml',
          'docProps/app.xml',
          'word/document.xml',
          'word/_rels/document.xml.rels',
          'word/styles.xml',
          'word/settings.xml',
        ]),
      );
      for (final String part in entries.keys) {
        final xml = utf8.decode(entries[part]!);
        expectWellFormedXml(xml);
      }
      final contentTypes = utf8.decode(entries['[Content_Types].xml']!);
      expect(contentTypes, contains('/word/document.xml'));
      expect(contentTypes, contains('wordprocessingml.document.main+xml'));
      final rels = utf8.decode(entries['_rels/.rels']!);
      expect(rels, contains('Target="word/document.xml"'));
    });

    test('page setup and section direction follow the official paper', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      expect(xml, contains('<w:pgSz w:w="11906" w:h="16838"/>'));
      expect(xml, contains('<w:pgMar w:top="426" w:right="720" w:bottom="720" w:left="720"'));
      expect(xml, contains('<w:bidi/>'));
      expect(xml, contains('<w:rtlGutter/>'));
      expect(xml, contains('<w:docGrid w:linePitch="360"/>'));
    });
  });

  group('paper content', () {
    test('prints the header fields in the official order', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      final school = xml.indexOf('متوسطة النخبة للبنين');
      final title = xml.indexOf('اسئلة امتحانات نصف السنة / الدور الأول');
      final year = xml.indexOf('للعام الدراسي 2025 – 2026');
      final subject = xml.indexOf('التربية الفنية');
      final name = xml.indexOf('الاسم :');
      final classLine = xml.indexOf('الصف : الأول المتوسط / الشعبة : أ');
      final examNumber = xml.indexOf('الرقم الامتحاني :');
      for (final int index in <int>[school, title, year, subject, name, classLine, examNumber]) {
        expect(index, isNonNegative);
      }
      expect(school < title, isTrue);
      expect(title < year, isTrue);
      expect(year < subject, isTrue);
      expect(subject < name, isTrue);
      expect(name < classLine, isTrue);
      expect(classLine < examNumber, isTrue);
    });

    test('prints the grade table with its nine rows and the merged practical row', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      expect(xml, contains('<w:tblGrid><w:gridCol w:w="1334"/><w:gridCol w:w="1334"/>'));
      expect(xml, contains('رقم السؤال'));
      expect(xml, contains('الدرجة رقما'));
      expect(xml, contains('الدرجة كتابة'));
      expect(xml, contains('اسم المصحح'));
      expect(xml, contains('اسم المدقق'));
      expect(xml, contains('العملـــــي'));
      expect(xml, contains('<w:gridSpan w:val="5"/>'));
      expect(xml, contains('المجموع'));
      expect('<w:tr>'.allMatches(xml).length + '<w:tr '.allMatches(xml).length, 11);
    });

    test('keeps the theoretical then the practical sections in order', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      final theory = xml.indexOf('المادة النظرية / اجب عن سؤالين فقط');
      final trueFalse = xml.indexOf('س1: ضع علامة صح');
      final choice = xml.indexOf('س2: اختر الاجابة الصحيحة');
      final open = xml.indexOf('س3: عدد ما يأتي');
      final practical = xml.indexOf('المادة العملية : اجب عن سؤالين فقط ( 70 درجة )');
      final firstDrawing = xml.indexOf('ارسم موضوع «تصميم غلاف كتاب»');
      final secondDrawing = xml.indexOf('استخدم الالوان في رسم احد انواع الزخرفة');
      for (final int index in <int>[
        theory,
        trueFalse,
        choice,
        open,
        practical,
        firstDrawing,
        secondDrawing,
      ]) {
        expect(index, isNonNegative);
      }
      expect(theory < trueFalse, isTrue);
      expect(trueFalse < choice, isTrue);
      expect(choice < open, isTrue);
      expect(open < practical, isTrue);
      expect(practical < firstDrawing, isTrue);
      expect(firstDrawing < secondDrawing, isTrue);
    });

    test('renders every question kind the way the paper does', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      expect(xml, contains('1- تمتاز صفائح النحاس بخفة الوزن .'));
      expect(xml, contains('(                )'));
      expect(xml, contains('1- النحت البارز هو عمل شكل من الطين على'));
      expect(xml, contains('( قاعده   -   الهواء   -   القصب )'));
      expect(xml, contains('1- عدد اثنين من ادوات النشر والقطع ؟'));
      expect(xml, contains('2- '));
      expect(xml, contains(' ( 6 درجة )'));
      expect(xml, contains(' ( 4 درجة )'));
      expect(xml, contains(' ( 15 درجة )'));
    });

    test('ends with the wishes and the teacher name', () {
      final xml = documentXmlOf(ExamDocxBuilder.build(buildSamplePaper()));
      final wishes = xml.indexOf('تمنياتي لكم بالتوفيق والنجاح');
      final signature = xml.indexOf('مدرس المادة');
      final teacher = xml.indexOf('فائز محمد عبد النبي');
      expect(wishes, isNonNegative);
      expect(wishes < signature, isTrue);
      expect(signature < teacher, isTrue);
    });

    test('omits empty optional fields without breaking the layout', () {
      final paper = buildSamplePaper(section: '');
      final xml = documentXmlOf(ExamDocxBuilder.build(paper));
      expect(xml, contains('الصف : الأول المتوسط / الشعبة :'));
    });
  });

  group('typography', () {
    test('uses the selected family and the requested point sizes', () {
      final paper = buildSamplePaper(
        typography: const ExamPaperTypography(
          font: ExamPaperFont.amiri,
          headerFontSize: 10,
          bodyFontSize: 18,
          headingFontSize: 20,
        ),
      );
      final bytes = ExamDocxBuilder.build(paper);
      final document = documentXmlOf(bytes);
      expect(document, contains('w:cs="Amiri"'));
      expect(document, contains('<w:sz w:val="20"/><w:szCs w:val="20"/>'));
      expect(document, contains('<w:sz w:val="36"/><w:szCs w:val="36"/>'));
      expect(document, contains('<w:sz w:val="40"/><w:szCs w:val="40"/>'));
      final styles = utf8.decode(readStoredZip(bytes)['word/styles.xml']!);
      expect(styles, contains('w:cs="Amiri"'));
    });
  });

  group('safety', () {
    test('escapes user text instead of breaking the document', () {
      final paper = buildSamplePaper(
        school: 'مدرسة <النخبة> & "الرافدين"',
        teacher: "أ. علي 'حسن'",
      );
      final xml = documentXmlOf(ExamDocxBuilder.build(paper));
      expect(xml, contains('مدرسة &lt;النخبة&gt; &amp; &quot;الرافدين&quot;'));
      expect(xml, contains('أ. علي &apos;حسن&apos;'));
      expectWellFormedXml(xml);
    });

    test('collapses newlines typed in a custom question', () {
      final paper = buildSamplePaper().copyWithPracticalPrompt(
        'ارسم منظراً\nطبيعياً مستخدماً الألوان',
      );
      final xml = documentXmlOf(ExamDocxBuilder.build(paper));
      expect(xml, contains('ارسم منظراً طبيعياً مستخدماً الألوان'));
    });

    test('refuses to build an incomplete paper', () {
      final paper = buildSamplePaper(school: '');
      expect(paper.isComplete, isFalse);
      expect(() => ExamDocxBuilder.build(paper), throwsArgumentError);
    });
  });
}

extension on ExamPaper {
  /// Replaces the text of the first practical question; the tests keep the
  /// sample paper immutable everywhere else.
  ExamPaper copyWithPracticalPrompt(String prompt) {
    return ExamPaper(
      info: info,
      typography: typography,
      theory: theory,
      practical: <ExamPracticalQuestion>[
        ExamPracticalQuestion(
          prompt: prompt,
          degree: practical.first.degree,
          drawingId: practical.first.drawingId,
          drawingTitle: practical.first.drawingTitle,
        ),
        ...practical.skip(1),
      ],
      theoryDegree: theoryDegree,
      practicalDegree: practicalDegree,
    );
  }
}
