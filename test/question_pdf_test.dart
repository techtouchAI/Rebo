import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/services.dart' show CachingAssetBundle, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/question_pdf.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/question_print_settings.dart';
import 'package:mirsam/domain/services/question_print_plan.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'test_support.dart';

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

/// Decode text runs written by the pinned PDF library and its embedded font
/// maps. This inspects actual generated pages, not just the print plan.
Future<List<String>> pdfTextRuns(pw.Document document) async {
  final content = latin1.decode(await document.save());
  final characterMaps = <int, List<int>>{
    for (final font in document.document.fonts.whereType<PdfTtfFont>())
      font.objser: font.unicodeCMap.cmap,
  };
  final runs = <String>[];
  final operators = RegExp(r'/F(\d+)\s+\d+(?:\.\d+)?\s+Tf[^\[]*\[<([0-9A-Fa-f]+)>\]TJ');
  for (final match in operators.allMatches(content)) {
    final map = characterMaps[int.parse(match.group(1)!)]!;
    final encoded = match.group(2)!;
    runs.add(
      String.fromCharCodes(<int>[
        for (var i = 0; i < encoded.length; i += 4)
          map[int.parse(encoded.substring(i, i + 4), radix: 16)],
      ]),
    );
  }
  return runs;
}

/// Inspect the actual PDF text positions and glyph metrics. The regular font
/// is used only by the top-level body text, whose coordinates are page-relative
/// in the pinned PDF library. Headings may have additional PDF transforms.
Future<void> expectBodyGlyphsWithinPrintArea(pw.Document document, String family) async {
  final content = latin1.decode(await document.save());
  final font = document.document.fonts.whereType<PdfTtfFont>().singleWhere(
    (item) => item.fontName == '$family-Regular',
  );
  final operators = RegExp(
    r'/F(\d+)\s+(\d+(?:\.\d+)?)\s+Tf\s+[-\d.]+\s+Tc\s+'
    r'([-\d.]+)\s+[-\d.]+\s+Td\s+\[<([0-9A-Fa-f]+)>\]TJ',
  );
  var checkedRuns = 0;
  for (final match in operators.allMatches(content)) {
    if (int.parse(match.group(1)!) != font.objser) {
      continue;
    }
    checkedRuns++;
    final size = double.parse(match.group(2)!);
    var x = double.parse(match.group(3)!);
    final encoded = match.group(4)!;
    for (var i = 0; i < encoded.length; i += 4) {
      final rune = font.unicodeCMap.cmap[int.parse(encoded.substring(i, i + 4), radix: 16)];
      final metrics = font.glyphMetrics(rune);
      // Leave a practical 5 mm clearance on either side for paper printers.
      expect(x + metrics.left * size, greaterThanOrEqualTo(5 * PdfPageFormat.mm));
      expect(
        x + metrics.right * size,
        lessThanOrEqualTo(PdfPageFormat.a4.width - 5 * PdfPageFormat.mm),
      );
      // PDF encodes glyph advances in thousandths of an em.
      x += (metrics.advanceWidth * 1000).toInt() / 1000 * size;
    }
  }
  expect(checkedRuns, greaterThan(0), reason: 'No body text was found in the generated PDF');
}

LearningUnit sentinelUnit(String id, int order) {
  return LearningUnit(
    id: id,
    sectionId: 'test-grade',
    title: 'UNITNAME$id',
    displayTitle: 'UNITNAME$id',
    grade: 'Test grade',
    order: order,
    template: PresentationTemplate.concept,
    accent: 'primary',
    topics: const <Topic>[],
    figures: const <Figure>[],
    questions: <Question>[
      Question(
        id: 'open$id',
        kind: QuestionKind.open,
        prompt: 'OPEN$id',
        textAnswer: '١- ANSWERA$id\n٢- ANSWERB$id',
      ),
      Question(
        id: 'choice$id',
        kind: QuestionKind.choice,
        prompt: 'CHOICE$id',
        options: <String>['OPTIONA$id', 'OPTIONB$id'],
        answerIndex: 1,
      ),
      Question(
        id: 'true$id',
        kind: QuestionKind.trueFalse,
        prompt: 'TRUE$id',
        boolAnswer: id != 'TWO',
        answerSupport: 'CORRECTION$id',
      ),
    ],
  );
}

LearningUnit longQuestionUnit({required bool longAnswer}) {
  final longText = List<String>.filled(3000, 'عناصر').join(' ');
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
        prompt: longAnswer ? 'عدد العناصر' : longText,
        textAnswer: longAnswer ? longText : 'الإجابة',
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
    fontData = <String, ByteData>{};
    for (final font in QuestionPrintFont.values) {
      fontData[font.regularAsset] = await rootBundle.load(font.regularAsset);
      fontData[font.boldAsset] = await rootBundle.load(font.boldAsset);
    }
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

      expect(bundle.requested, <String>[
        QuestionPrintFont.plex.regularAsset,
        QuestionPrintFont.plex.boldAsset,
      ]);
      expect(document.document.pdfPageList.pages, isNotEmpty);
      expect(await document.save(), isNotEmpty);
    });
  }

  for (final missing in <String>[
    QuestionPrintFont.plex.regularAsset,
    QuestionPrintFont.plex.boldAsset,
  ]) {
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
        missing == QuestionPrintFont.plex.regularAsset
            ? <String>[QuestionPrintFont.plex.regularAsset]
            : <String>[QuestionPrintFont.plex.regularAsset, QuestionPrintFont.plex.boldAsset],
      );
    });
  }

  test('every non-empty unit selection generates A4 pages with the default sizes', () async {
    for (final grade in <String>['g1', 'g2', 'g3']) {
      final units = library.unitsOf(grade);
      for (var mask = 1; mask < (1 << units.length); mask++) {
        final selectedIds = <String>{
          for (var i = 0; i < units.length; i++)
            if ((mask & (1 << i)) != 0) units[i].id,
        };
        final plan = QuestionPrintPlan.fromSelection(units, selectedIds);
        final document = await const QuestionPdfBuilder(
          compress: false,
        ).build(plan, gradeTitle: units.first.grade);
        final pages = document.document.pdfPageList.pages;
        expect(pages, isNotEmpty, reason: '$grade/$selectedIds at the default settings');
        for (final page in pages) {
          expect(page.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.001));
          expect(page.pageFormat.height, closeTo(PdfPageFormat.a4.height, 0.001));
        }
        final contents = latin1.decode(await document.save());
        expect(contents, startsWith('%PDF-'));
        final sizes = RegExp(
          r'/F\d+\s+(\d+(?:\.\d+)?)\s+Tf',
        ).allMatches(contents).map((match) => double.parse(match.group(1)!)).toSet();
        expect(sizes, <double>{12, 14}, reason: '$grade/$selectedIds');
      }
    }
  });

  for (final font in QuestionPrintFont.values) {
    test('embeds both $font weights and renders all curriculum glyphs', () async {
      for (final grade in <String>['g1', 'g2', 'g3']) {
        final units = library.unitsOf(grade);
        final settings = QuestionPrintSettings(font: font, bodyFontSize: 18, headingFontSize: 24);
        final plan = QuestionPrintPlan.fromSelection(
          units,
          units.map((unit) => unit.id).toSet(),
          settings: settings,
        );
        final document = await const QuestionPdfBuilder(
          compress: false,
        ).build(plan, gradeTitle: units.first.grade);
        final contents = latin1.decode(await document.save());
        final sizes = RegExp(
          r'/F\d+\s+(\d+(?:\.\d+)?)\s+Tf',
        ).allMatches(contents).map((match) => double.parse(match.group(1)!)).toSet();
        expect(sizes, <double>{18, 24});

        final fonts = document.document.fonts.whereType<PdfTtfFont>().toList();
        expect(fonts, hasLength(2));
        expect(
          fonts.map((item) => item.fontName),
          containsAll(<String>['${font.family}-Regular', '${font.family}-Bold']),
        );
        final sourceText = <String>[
          'أسئلة الامتحان - ${units.first.grade}',
          for (final section in plan.sections) ...<String>[
            section.kind.printHeading,
            for (final group in section.groups)
              for (final question in group.questions) formatPrintableQuestion(question, 1),
          ],
        ].join();
        final whitespace = RegExp(r'\s');
        for (final item in fonts) {
          final missingSource = sourceText.runes.where(
            (rune) =>
                !whitespace.hasMatch(String.fromCharCode(rune)) &&
                (item.font.charToGlyphIndexMap[rune] ?? 0) == 0,
          );
          expect(
            missingSource,
            isEmpty,
            reason: '$grade has unsupported input in ${item.fontName}',
          );
          final missingDrawn = item.unicodeCMap.cmap.where(
            (rune) => rune != 0 && (item.font.charToGlyphIndexMap[rune] ?? 0) == 0,
          );
          expect(
            missingDrawn,
            isEmpty,
            reason: '$grade has missing shaped glyphs in ${item.fontName}',
          );
          final isolatedYeh = 'ﻱ'.runes.single;
          expect(item.glyphMetrics(isolatedYeh).advanceWidth, greaterThan(0));
        }
      }
    });
  }

  test('largest and mixed font sizes leave room for RTL glyphs near paper edges', () async {
    for (final font in QuestionPrintFont.values) {
      for (final grade in <String>['g1', 'g2', 'g3']) {
        final units = library.unitsOf(grade);
        for (final (body, heading) in <(int, int)>[(32, 8), (8, 32), (32, 32)]) {
          final plan = QuestionPrintPlan.fromSelection(
            units,
            units.map((unit) => unit.id).toSet(),
            settings: QuestionPrintSettings(
              font: font,
              bodyFontSize: body,
              headingFontSize: heading,
            ),
          );
          final document = await const QuestionPdfBuilder(
            compress: false,
          ).build(plan, gradeTitle: units.first.grade);
          await expectBodyGlyphsWithinPrintArea(document, font.family);
        }
      }
    }
  });

  test('PDF contains selected questions and answers in type order, but no unit titles', () async {
    final first = sentinelUnit('ONE', 1);
    final second = sentinelUnit('TWO', 2);
    final unselected = sentinelUnit('THREE', 3);
    final plan = QuestionPrintPlan.fromSelection(
      <LearningUnit>[unselected, second, first],
      <String>{first.id, second.id},
    );
    final document = await const QuestionPdfBuilder(
      compress: false,
    ).build(plan, gradeTitle: first.grade);
    final runs = await pdfTextRuns(document);
    final expected = <String>['TRUEONE', 'TRUETWO', 'CHOICEONE', 'CHOICETWO', 'OPENONE', 'OPENTWO'];
    final positions = expected.map(runs.indexOf).toList();
    for (var i = 0; i < positions.length; i++) {
      expect(positions[i], greaterThanOrEqualTo(0), reason: '${expected[i]} was not printed');
      if (i > 0) expect(positions[i], greaterThan(positions[i - 1]));
    }
    expect(
      runs,
      containsAll(<String>[
        'OPTIONAONE',
        'OPTIONBONE',
        'OPTIONATWO',
        'OPTIONBTWO',
        'CORRECTIONTWO',
      ]),
    );
    for (final item in <String>['ANSWERAONE', 'ANSWERBONE', 'ANSWERATWO', 'ANSWERBTWO']) {
      final run = runs.singleWhere((run) => run.contains(item));
      expect(run, contains('-'), reason: 'The enumeration marker must stay with its first word');
    }
    // The right choice appears once among the options and again as the answer.
    expect(runs.where((run) => run == 'OPTIONBONE'), hasLength(2));
    expect(runs.where((run) => run == 'OPTIONBTWO'), hasLength(2));
    for (final run in runs) {
      expect(run, isNot(contains('THREE')));
      expect(run, isNot(contains('UNITNAME')));
    }
  });

  for (final longAnswer in <bool>[false, true]) {
    test(
      'an exceptionally long ${longAnswer ? 'answer' : 'question'} continues without clipping',
      () async {
        final unit = longQuestionUnit(longAnswer: longAnswer);
        final plan = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{unit.id});
        final document = await const QuestionPdfBuilder(
          compress: false,
        ).build(plan, gradeTitle: unit.grade);
        expect(document.document.pdfPageList.pages.length, greaterThan(1));
        for (final page in document.document.pdfPageList.pages) {
          expect(page.pageFormat.width, closeTo(PdfPageFormat.a4.width, 0.001));
          expect(page.pageFormat.height, closeTo(PdfPageFormat.a4.height, 0.001));
        }
        final runs = await pdfTextRuns(document);
        // The library writes shaped RTL glyphs in visual order. All 3,000 words
        // must survive pagination, not merely create multiple pages.
        expect(runs.where((run) => run.contains('ﺮﺻﺎﻨﻋ')), hasLength(3000));
      },
    );
  }

  test('rejects an empty selection or invalid sizes before loading assets', () async {
    final unit = library.unitsOf('g1').first;
    final empty = QuestionPrintPlan.fromSelection(<LearningUnit>[unit], <String>{});
    final bundle = _FontAssetBundle(<String, ByteData>{}, synchronous: true);
    await expectLater(
      const QuestionPdfBuilder().build(empty, gradeTitle: unit.grade, assetBundle: bundle),
      throwsArgumentError,
    );
    for (final settings in <QuestionPrintSettings>[
      const QuestionPrintSettings(bodyFontSize: 7),
      const QuestionPrintSettings(headingFontSize: 33),
    ]) {
      final plan = QuestionPrintPlan.fromSelection(
        <LearningUnit>[unit],
        <String>{unit.id},
        settings: settings,
      );
      await expectLater(
        const QuestionPdfBuilder().build(plan, gradeTitle: unit.grade, assetBundle: bundle),
        throwsArgumentError,
      );
    }
    expect(bundle.requested, isEmpty);
  });
}
