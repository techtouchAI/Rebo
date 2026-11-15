import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/question_pdf.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'test_support.dart';

const _regularFontAsset = 'assets/fonts/IBMPlexSansArabic-Regular.ttf';
const _boldFontAsset = 'assets/fonts/IBMPlexSansArabic-Bold.ttf';

/// Delivers real font data either immediately or in a later microtask.
class _FontAssetBundle extends CachingAssetBundle {
  _FontAssetBundle(this.fonts, {required this.synchronous});

  final Map<String, ByteData> fonts;
  final bool synchronous;
  final List<String> requested = <String>[];

  @override
  Future<ByteData> load(String key) {
    requested.add(key);
    final data = fonts[key];
    if (data == null) {
      return Future<ByteData>.error(StateError('Missing asset: $key'));
    }
    return synchronous ? SynchronousFuture<ByteData>(data) : Future<ByteData>.value(data);
  }
}

/// Decode the text runs written by the pinned PDF library and its embedded
/// font maps. This examines the generated page, not just the print plan.
Future<List<String>> pdfTextRuns(pw.Document document) async {
  final content = latin1.decode(await document.save());
  final characterMaps = <int, List<int>>{
    for (final font in document.document.fonts.whereType<PdfTtfFont>())
      font.objser: font.unicodeCMap.cmap,
  };
  final runs = <String>[];
  final operators = RegExp(
    r'/F(\d+)\s+\d+(?:\.\d+)?\s+Tf[^\[]*\[<([0-9A-Fa-f]+)>\]TJ',
  );
  for (final match in operators.allMatches(content)) {
    final map = characterMaps[int.parse(match.group(1)!)]!;
    final encoded = match.group(2)!;
    runs.add(String.fromCharCodes(<int>[
      for (var i = 0; i < encoded.length; i += 4)
        map[int.parse(encoded.substring(i, i + 4), radix: 16)],
    ]));
  }
  return runs;
}

LearningUnit sentinelUnit(String id, int order) {
  return LearningUnit(
    id: id,
    sectionId: 'test-grade',
    title: 'Unit$id',
    displayTitle: 'Unit$id',
    grade: 'Test grade',
    order: order,
    template: PresentationTemplate.concept,
    accent: 'primary',
    topics: const <Topic>[],
    figures: const <Figure>[],
    questions: <Question>[
      Question(id: 'open$id', kind: QuestionKind.open, prompt: 'OPEN$id', textAnswer: 'ANSWER$id'),
      Question(
        id: 'choice$id',
        kind: QuestionKind.choice,
        prompt: 'CHOICE$id',
        options: <String>['OPTIONA$id', 'OPTIONB$id'],
        answerIndex: 1,
        answerSupport: 'EXPLANATION$id',
      ),
      Question(
        id: 'true$id',
        kind: QuestionKind.trueFalse,
        prompt: 'TRUE$id',
        boolAnswer: true,
        answerSupport: 'SECRET$id',
      ),
    ],
  );
}

LearningUnit longQuestionUnit() {
  return LearningUnit(
    id: 'long-unit',
    sectionId: 'test-grade',
    title: 'الوحدة الأولى',
    displayTitle: 'الوحدة الأولى',
    grade: 'صف تجريبي',
    order: 1,
    template: PresentationTemplate.concept,
    accent: 'primary',
    topics: const <Topic>[],
    figures: const <Figure>[],
    questions: <Question>[
      Question(
        id: 'long',
        kind: QuestionKind.open,
        prompt: List<String>.filled(3000, 'عناصر').join(' '),
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Library library;
  late Map<String, ByteData> fontData;

  setUpAll(() async {
    library = await ensureLibrary();
    fontData = <String, ByteData>{
      _regularFontAsset: await rootBundle.load(_regularFontAsset),
      _boldFontAsset: await rootBundle.load(_boldFontAsset),
    };
  });

  for (final synchronous in <bool>[true, false]) {
    test('loads fonts delivered ${synchronous ? 'synchronously' : 'asynchronously'}', () async {
      final unit = library.unitsOf('g1').first;
      final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});
      final bundle = _FontAssetBundle(fontData, synchronous: synchronous);

      final document = await const QuestionPdfBuilder().build(
        plan,
        gradeTitle: unit.grade,
        assetBundle: bundle,
      );

      expect(bundle.requested, <String>[_regularFontAsset, _boldFontAsset]);
      expect(document.document.pdfPageList.pages, hasLength(1));
      expect(await document.save(), isNotEmpty);
    });
  }

  for (final missing in <String>[_regularFontAsset, _boldFontAsset]) {
    test('propagates a failure to load $missing', () async {
      final unit = library.unitsOf('g1').first;
      final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});
      final available = Map<String, ByteData>.of(fontData)..remove(missing);
      final bundle = _FontAssetBundle(available, synchronous: true);

      await expectLater(
        const QuestionPdfBuilder().build(plan, gradeTitle: unit.grade, assetBundle: bundle),
        throwsA(isA<StateError>()),
      );
      expect(
        bundle.requested,
        missing == _regularFontAsset
            ? <String>[_regularFontAsset]
            : <String>[_regularFontAsset, _boldFontAsset],
      );
    });
  }

  test('every non-empty unit selection fits on A4 at the requested sizes', () async {
    for (final grade in <String>['g1', 'g2', 'g3']) {
      final units = library.unitsOf(grade);
      for (var mask = 1; mask < (1 << units.length); mask++) {
        final selectedIds = <String>{
          for (var i = 0; i < units.length; i++)
            if ((mask & (1 << i)) != 0) units[i].id,
        };
        final plan = QuestionPrintPlan.fromSelection(units, selectedIds);
        final document = await const QuestionPdfBuilder(compress: false).build(
          plan,
          gradeTitle: units.first.grade,
        );
        final pages = document.document.pdfPageList.pages;
        expect(pages, hasLength(1), reason: '$grade with $selectedIds should fit');
        expect(pages.single.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.001));
        expect(pages.single.pageFormat.height, closeTo(PdfPageFormat.a4.height, 0.001));

        final bytes = await document.save();
        final contents = latin1.decode(bytes);
        expect(contents, startsWith('%PDF-'));
        // Inspect actual PDF text operators, not just the builder's constants.
        final fontSizes = RegExp(r'/F\d+\s+(\d+(?:\.\d+)?)\s+Tf')
            .allMatches(contents)
            .map((match) => double.parse(match.group(1)!))
            .toSet();
        expect(fontSizes, <double>{12, 14});
        final fonts = document.document.fonts.whereType<PdfTtfFont>().toList();
        expect(fonts, hasLength(2));
        expect(fonts.map((font) => font.fontName), containsAll(<String>[
          'IBMPlexSansArabic-Regular', 'IBMPlexSansArabic-Bold',
        ]));
        final sourceText = <String>[
          'أسئلة ${units.first.grade}',
          for (final section in plan.sections) ...<String>[
            section.kind.printHeading,
            for (final group in section.groups) ...<String>[
              group.unit.title,
              for (final question in group.questions) formatPrintableQuestion(question, 1),
            ],
          ],
        ].join();
        final whitespace = RegExp(r'\s');
        for (final font in fonts) {
          final missingSourceGlyphs = sourceText.runes.where(
            (rune) =>
                !whitespace.hasMatch(String.fromCharCode(rune)) &&
                (font.font.charToGlyphIndexMap[rune] ?? 0) == 0,
          );
          expect(missingSourceGlyphs, isEmpty, reason: '$grade has unsupported input in ${font.fontName}');
          expect(font.isRuneSupported('ع'.runes.single), isTrue);
          expect(font.isRuneSupported('ﺧ'.runes.single), isTrue);
          // The PDF library shapes Arabic before drawing. Some fonts lack an
          // isolated yeh, which would silently turn «أي» into a missing glyph.
          final isolatedYeh = 'ﻱ'.runes.single;
          expect(font.isRuneSupported(isolatedYeh), isTrue);
          expect(font.glyphMetrics(isolatedYeh).advanceWidth, greaterThan(0));
          final missingGlyphs = font.unicodeCMap.cmap.where(
            (rune) => rune != 0 && (font.font.charToGlyphIndexMap[rune] ?? 0) == 0,
          );
          expect(missingGlyphs, isEmpty, reason: '$grade has missing glyphs in ${font.fontName}');
        }
      }
    }
  });

  test('the PDF contains only selected questions, grouped by kind with no answers', () async {
    final first = sentinelUnit('ONE', 1);
    final second = sentinelUnit('TWO', 2);
    final unselected = sentinelUnit('THREE', 3);
    final plan = QuestionPrintPlan.fromSelection(
      <LearningUnit>[unselected, second, first],
      <String>{first.id, second.id},
    );
    final document = await const QuestionPdfBuilder(compress: false).build(
      plan,
      gradeTitle: first.grade,
    );
    final runs = await pdfTextRuns(document);
    final expected = <String>['TRUEONE', 'TRUETWO', 'CHOICEONE', 'CHOICETWO', 'OPENONE', 'OPENTWO'];
    final positions = expected.map(runs.indexOf).toList();
    for (var i = 0; i < positions.length; i++) {
      expect(positions[i], greaterThanOrEqualTo(0), reason: '${expected[i]} was not printed');
      if (i > 0) {
        expect(positions[i], greaterThan(positions[i - 1]));
      }
    }
    expect(runs, containsAll(<String>['OPTIONAONE', 'OPTIONBONE', 'OPTIONATWO', 'OPTIONBTWO']));
    for (final run in runs) {
      expect(run, isNot(contains('THREE')));
      expect(run, isNot(contains('ANSWER')));
      expect(run, isNot(contains('EXPLANATION')));
      expect(run, isNot(contains('SECRET')));
    }
  });

  test('an exceptionally long question continues onto additional A4 pages', () async {
    final unit = longQuestionUnit();
    final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});
    final document = await const QuestionPdfBuilder(compress: false).build(plan, gradeTitle: unit.grade);
    expect(document.document.pdfPageList.pages.length, greaterThan(1));
    for (final page in document.document.pdfPageList.pages) {
      expect(page.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.001));
      expect(page.pageFormat.height, closeTo(PdfPageFormat.a4.height, 0.001));
    }
    final runs = await pdfTextRuns(document);
    // The library writes shaped RTL glyphs in visual order. Every one of the
    // 3,000 words must survive pagination, not merely create multiple pages.
    expect(runs.where((run) => run == 'ﺮﺻﺎﻨﻋ'), hasLength(3000));
  });

  test('rejects an empty print selection before loading any assets', () async {
    final plan = QuestionPrintPlan.fromSelection(library.unitsOf('g1'), <String>{});
    final bundle = _FontAssetBundle(<String, ByteData>{}, synchronous: true);
    await expectLater(
      const QuestionPdfBuilder().build(
        plan,
        gradeTitle: 'الصف الأول المتوسط',
        assetBundle: bundle,
      ),
      throwsArgumentError,
    );
    expect(bundle.requested, isEmpty);
  });
}
