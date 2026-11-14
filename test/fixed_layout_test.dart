import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/core/widgets/equal_columns_grid.dart';
import 'package:mirsam/core/widgets/meta_pill.dart';
import 'package:mirsam/core/widgets/single_line_row.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/presentation/screens/home_screen.dart';
import 'package:mirsam/presentation/screens/settings_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';
import 'package:mirsam/presentation/state/app_state.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

/// Regression tests for the layouts that must not depend on the text scale.
const Size phone = Size(390, 844);
const Size narrowPhone = Size(360, 640);

/// Both ends of the supported range plus the default.
const List<double> scales = <double>[
  AppState.MinTextScale,
  1.0,
  AppState.MaxTextScale,
];

void useTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// On-screen rectangle of [element], transforms (scaling) included.
Rect rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
}

/// Number of widgets matched by [finder] on each visual row, top to bottom.
List<int> countsPerRow(Finder finder) {
  final perRow = <int, int>{};
  for (final element in finder.evaluate()) {
    final row = rectOf(element).center.dy.round();
    perRow[row] = (perRow[row] ?? 0) + 1;
  }
  return (perRow.keys.toList()..sort()).map((int row) => perRow[row]!).toList(growable: false);
}

void expectNoOverflow(WidgetTester tester, String name) {
  expect(tester.takeException(), isNull, reason: 'exception on $name');
  expect(findFlexOverflows(tester), isEmpty, reason: 'layout overflow on $name');
}

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  group('text scale range', () {
    test('goes from 50% to 120% in 10% steps', () {
      expect(AppState.MinTextScale, 0.5);
      expect(AppState.MaxTextScale, 1.2);
      expect(AppState.textScaleDivisions, 7);
    });

    test('a scale saved by an older version is brought back into the range', () {
      final state = buildState(
        library: library,
        progress: ReadingProgress(gradeId: testGrade, textScale: 1.5),
      );
      expect(state.textScale, AppState.MaxTextScale);
    });

    test('stepping down from the default reaches the minimum without drift', () async {
      final state = buildState(library: library);
      for (int i = 0; i < 10; i++) {
        await state.setTextScale(state.textScale - AppState.TextScaleStep);
      }
      expect(state.textScale, AppState.MinTextScale);
      for (int i = 0; i < 10; i++) {
        await state.setTextScale(state.textScale + AppState.TextScaleStep);
      }
      expect(state.textScale, AppState.MaxTextScale);
    });

    testWidgets('the settings slider accepts a legacy out-of-range value',
        (WidgetTester tester) async {
      await pumpScreen(
        tester,
        const SettingsScreen(embedded: true),
        progress: ReadingProgress(gradeId: testGrade, textScale: 1.5),
      );
      expect(tester.takeException(), isNull);
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.min, AppState.MinTextScale);
      expect(slider.max, AppState.MaxTextScale);
      expect(slider.value, AppState.MaxTextScale);
    });
  });

  group('home screen', () {
    testWidgets('no longer shows the hero text nor the duplicate search button',
        (WidgetTester tester) async {
      await pumpScreen(tester, const HomeScreen(), size: phone);

      expect(find.text('لوحة تتكوّن من معرفة ولون'), findsNothing);
      expect(find.textContaining('محتوى التربية الفنية للمرحلة المتوسطة'), findsNothing);
      expect(find.text('ابحث في المحتوى'), findsNothing);
      // The fixed search action of the header and the progress stay.
      expect(find.byTooltip('بحث'), findsOneWidget);
      expect(find.text('تقدّمك في الاستكشاف'), findsOneWidget);
    });

    for (final size in <Size>[narrowPhone, phone]) {
      for (final scale in scales) {
        testWidgets('the four figures share one row at ${size.width.round()}px ×$scale',
            (WidgetTester tester) async {
          useTextScale(tester, scale);
          await pumpScreen(tester, const HomeScreen(), size: size);
          expectNoOverflow(tester, 'home');

          const labels = <String>['وحدات', 'موضوعات', 'أسئلة', 'لوحات'];
          final grid = find.byType(EqualColumnsGrid);
          expect(grid, findsOneWidget);
          final centres = <Offset>[];
          for (final label in labels) {
            final finder = find.descendant(of: grid, matching: find.text(label));
            expect(finder, findsOneWidget, reason: label);
            // One line only: the label is never taller than a single line.
            final paragraph = tester.renderObject<RenderBox>(finder);
            expect(paragraph.size.height, lessThan(30), reason: '$label wraps');
            centres.add(rectOf(finder.evaluate().single).center);
          }
          expect(
            centres.map((Offset centre) => centre.dy.round()).toSet(),
            hasLength(1),
            reason: 'the figures are not on one row',
          );
          expect(
            centres.map((Offset centre) => centre.dx.round()).toSet(),
            hasLength(labels.length),
          );
        });
      }
    }
  });

  group('unit screen', () {
    // Every unit of every grade, not only the one in the screenshots.
    testWidgets('header pills and glossary terms keep their fixed rows in every unit',
        (WidgetTester tester) async {
      for (final unit in library.units) {
        for (final scale in <double>[AppState.MinTextScale, AppState.MaxTextScale]) {
          useTextScale(tester, scale);
          await pumpScreen(
            tester,
            UnitScreen(unitId: unit.id),
            size: const Size(390, 30000),
          );
          final name = '${unit.id} ×$scale';
          expectNoOverflow(tester, name);

          final lines = find.byType(SingleLineRow);
          expect(lines, findsNWidgets(2), reason: name);
          expect(
            find.descendant(of: lines.first, matching: find.byType(MetaPill)),
            findsOneWidget,
            reason: 'the grade has its own line in $name',
          );
          final meta = find.descendant(of: lines.last, matching: find.byType(MetaPill));
          expect(countsPerRow(meta), <int>[3], reason: 'meta pills wrap in $name');
          final line = rectOf(lines.last.evaluate().single);
          for (final element in meta.evaluate()) {
            final rect = rectOf(element);
            expect(rect.left, greaterThanOrEqualTo(line.left - 0.5), reason: name);
            expect(rect.right, lessThanOrEqualTo(line.right + 0.5), reason: name);
          }

          final count = unit.glossaryIds.map(library.termById).whereType<GlossaryTerm>().length;
          final grid = find.byType(EqualColumnsGrid);
          if (count == 0) {
            expect(grid, findsNothing, reason: name);
            continue;
          }
          final cells = find.descendant(of: grid, matching: find.byType(InkWell));
          expect(cells, findsNWidgets(count), reason: name);
          final expected = <int>[
            for (int left = count; left > 0; left -= 3) left >= 3 ? 3 : left,
          ];
          expect(countsPerRow(cells), expected, reason: 'terms are not three per row in $name');
        }
      }
    });

    testWidgets('the header pills have the same size at every text scale',
        (WidgetTester tester) async {
      final heights = <double>{};
      for (final scale in scales) {
        useTextScale(tester, scale);
        await pumpScreen(tester, const UnitScreen(unitId: 'g1-u1'), size: phone);
        heights.add(tester.getSize(find.byType(SingleLineRow).last).height);
      }
      expect(heights, hasLength(1));
    });
  });

  group('shared widgets', () {
    testWidgets('EqualColumnsGrid keeps incomplete rows aligned', (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 320,
              child: EqualColumnsGrid(
                columns: 3,
                children: <Widget>[
                  for (int i = 0; i < 5; i++) SizedBox(key: ValueKey<int>(i), height: 20),
                ],
              ),
            ),
          ),
        ),
      );
      final widths = <double>{
        for (int i = 0; i < 5; i++) tester.getSize(find.byKey(ValueKey<int>(i))).width,
      };
      expect(widths, hasLength(1));
      expect(widths.single, closeTo((320 - 16) / 3, 0.01));
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(3))).dx,
        tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dx,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey<int>(3))).dy,
        greaterThan(tester.getTopLeft(find.byKey(const ValueKey<int>(0))).dy),
      );
    });

    testWidgets('SingleLineRow shrinks instead of wrapping or overflowing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 120,
              child: SingleLineRow(
                children: <Widget>[
                  for (int i = 0; i < 4; i++) SizedBox(key: ValueKey<int>(i), width: 100, height: 20),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final line = tester.getRect(find.byType(SingleLineRow));
      expect(line.width, 120);
      final rects = <Rect>[
        for (int i = 0; i < 4; i++) tester.getRect(find.byKey(ValueKey<int>(i))),
      ];
      expect(rects.map((Rect rect) => rect.center.dy.round()).toSet(), hasLength(1));
      for (final rect in rects) {
        expect(rect.left, greaterThanOrEqualTo(line.left - 0.5));
        expect(rect.right, lessThanOrEqualTo(line.right + 0.5));
      }
    });
  });
}
