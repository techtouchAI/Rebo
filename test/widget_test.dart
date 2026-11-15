import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/core/utils/arabic_text.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/presentation/screens/grade_picker_screen.dart';
import 'package:mirsam/presentation/screens/home_screen.dart';
import 'package:mirsam/presentation/screens/settings_screen.dart';
import 'package:mirsam/presentation/screens/glossary_screen.dart';
import 'package:mirsam/presentation/screens/index_screen.dart';
import 'package:mirsam/presentation/screens/lesson_screen.dart';
import 'package:mirsam/presentation/screens/quiz_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';
import 'package:mirsam/presentation/widgets/unit_switcher_bar.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

void main() {
  setUpAll(ensureLibrary);

  testWidgets('home screen renders the identity and its sections', (WidgetTester tester) async {
    await pumpApplication(tester);

    expect(find.textContaining('مِرسم'), findsWidgets);
    expect(find.textContaining('التربية الفنية'), findsWidgets);
    expect(find.text('أقسام التطبيق'), findsOneWidget);
  });

  testWidgets('the whole application is laid out right to left', (WidgetTester tester) async {
    await pumpApplication(tester);

    final directionality = tester.widget<Directionality>(find.byType(Directionality).first);
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('the unit reader switches between the four units of the grade',
      (WidgetTester tester) async {
    await pumpScreen(
      tester,
      const UnitScreen(unitId: 'g1-u2'),
      size: const Size(900, 1400),
    );

    // The bar lists the units of the grade, numbered, current one included.
    final bar = find.byType(UnitSwitcherBar);
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.byType(InkWell)), findsWidgets);

    final labels = <String>[
      '${toArabicDigits('1')}. التعبير الفني',
      '${toArabicDigits('2')}. التصميم والزخرفة',
      '${toArabicDigits('3')}. التشكيل الفني والهندسي',
      '${toArabicDigits('4')}. التذوق الفني وتاريخ الفن',
    ];

    // The bar scrolls horizontally and builds its chips lazily, so the last
    // chip is scrolled into view before it is tapped.
    final lane = find.descendant(of: bar, matching: find.byType(Scrollable));
    expect(lane, findsOneWidget);
    final target = find.descendant(of: bar, matching: find.text(labels.last));
    await tester.scrollUntilVisible(target, 120, scrollable: lane);
    await tester.pump();

    await tester.tap(target);
    // The screen replaces itself; let the route transition finish frame by
    // frame (`pumpAndSettle` would be unsafe inside an app with timers).
    for (int frame = 0; frame < 12; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The reader replaced itself with the fourth unit, and the bar now marks
    // that unit as the current one.
    expect(find.byType(UnitScreen), findsOneWidget);
    final header = tester.widget<UnitScreen>(find.byType(UnitScreen));
    expect(header.unitId, 'g1-u4');
    final newBar = tester.widget<UnitSwitcherBar>(find.byType(UnitSwitcherBar));
    expect(newBar.current.id, 'g1-u4');
    expect(newBar.units.length, 4);
  });

  testWidgets('the settings page switches the reading font', (WidgetTester tester) async {
    final state = await pumpApplication(tester);
    await tapDestination(tester, 'الإعدادات');

    await tester.tap(find.text('القاهرة').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.font, AppFont.cairo);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme!.textTheme.bodyLarge!.fontFamily, 'Cairo');
  });

  testWidgets('the practical lesson page shows only the presentation and the homework',
      (WidgetTester tester) async {
    await pumpScreen(tester, const LessonScreen(lessonId: 'lesson-light'), size: const Size(900, 2000));

    expect(find.text('العرض'), findsOneWidget);
    expect(find.textContaining('واجب'), findsWidgets);
    expect(find.text('الأهداف العامة'), findsNothing);
    expect(find.text('الأهداف الخاصة'), findsNothing);
    expect(find.text('الوسائل التعليمية'), findsNothing);
    expect(find.text('المقدمة'), findsNothing);
    expect(find.text('الحصة العملية'), findsNothing);
  });

  testWidgets('the index lists the chosen grade and its units', (WidgetTester tester) async {
    await pumpApplication(tester);
    await tapDestination(tester, 'الفهرس');

    expect(find.byType(IndexScreen), findsOneWidget);
    expect(find.textContaining('الصف الأول المتوسط'), findsWidgets);
    expect(find.textContaining('الوحدة الأولى: التعبير الفني'), findsWidgets);
    // Nothing from the other two grades may leak into the index.
    expect(find.textContaining('الصف الثاني المتوسط'), findsNothing);
    expect(find.textContaining('الصف الثالث المتوسط'), findsNothing);
    expect(find.textContaining('الوحدة الثالثة: التشكيل المجسم'), findsNothing);
  });

  testWidgets('first launch asks for the grade and nothing else is shown',
      (WidgetTester tester) async {
    await pumpApplication(tester, progress: ReadingProgress());

    expect(find.byType(GradePickerScreen), findsOneWidget);
    expect(find.textContaining('الصف الأول المتوسط'), findsOneWidget);
    expect(find.textContaining('الصف الثاني المتوسط'), findsOneWidget);
    expect(find.textContaining('الصف الثالث المتوسط'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('picking a grade opens the app limited to that grade', (WidgetTester tester) async {
    final state = await pumpApplication(tester, progress: ReadingProgress());

    await tester.tap(find.textContaining('الصف الثاني المتوسط'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(state.gradeId, 'g2');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('الصف الثاني المتوسط'), findsWidgets);
    expect(find.textContaining('الصف الأول المتوسط'), findsNothing);

    await tapDestination(tester, 'الفهرس');
    expect(find.textContaining('الوحدة الأولى: التعبير الفني والهندسي'), findsWidgets);
    expect(find.textContaining('الوحدة الثالثة: التشكيل المجسم'), findsWidgets);
  });

  testWidgets('the grade can be changed again from the settings page',
      (WidgetTester tester) async {
    final state = await pumpApplication(tester);
    await tapDestination(tester, 'الإعدادات');

    await tester.tap(find.textContaining('الصف الثالث المتوسط').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(state.gradeId, 'g3');
    expect(state.visibleUnits.every((LearningUnit unit) => unit.sectionId == 'g3'), isTrue);
  });

  testWidgets('every screen offers text size controls', (WidgetTester tester) async {
    await pumpApplication(tester);
    expect(find.byTooltip('تكبير الخط'), findsOneWidget);
    expect(find.byTooltip('تصغير الخط'), findsOneWidget);

    await pumpScreen(tester, const GlossaryScreen());
    expect(find.byTooltip('تكبير الخط'), findsOneWidget);

    await pumpScreen(tester, const UnitScreen(unitId: 'g1-u1'), size: const Size(390, 844));
    expect(find.byTooltip('تكبير الخط'), findsOneWidget);

    await pumpScreen(tester, const SettingsScreen(embedded: true));
    expect(find.byTooltip('تكبير الخط'), findsOneWidget);
  });

  testWidgets('opening a unit shows its content', (WidgetTester tester) async {
    await pumpApplication(tester);
    await tapDestination(tester, 'الفهرس');

    await tester.tap(
      find
          .descendant(
            of: find.byType(IndexScreen),
            matching: find.textContaining('الوحدة الأولى: التعبير الفني'),
          )
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(UnitScreen), findsOneWidget);
    expect(find.textContaining('التعبير الفني'), findsWidgets);
  });

  testWidgets('opening a unit records it as read and keeps the progress',
      (WidgetTester tester) async {
    final state = await pumpApplication(tester);
    await tapDestination(tester, 'الفهرس');
    await tester.tap(
      find
          .descendant(
            of: find.byType(IndexScreen),
            matching: find.textContaining('الوحدة الأولى: التعبير الفني'),
          )
          .first,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(state.isRead('g1-u1'), isTrue);
    expect(state.lastReadUnitId, 'g1-u1');
  });

  testWidgets('search finds a curriculum topic', (WidgetTester tester) async {
    await pumpScreen(tester, const SearchScreen(), size: const Size(900, 1200));

    expect(find.byType(SearchScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'الزخرفة');
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.textContaining('نتيجة'), findsWidgets);
    expect(find.textContaining('التصميم والزخرفة'), findsWidgets);
  });

  testWidgets('the glossary lists the technical terms with their sources',
      (WidgetTester tester) async {
    await pumpScreen(tester, const GlossaryScreen());

    expect(find.byType(GlossaryScreen), findsOneWidget);
    expect(find.text('المنظور'), findsWidgets);
    expect(find.textContaining('تعريفات مختصرة'), findsOneWidget);
  });

  testWidgets('the quiz screen accepts an answer and reports progress',
      (WidgetTester tester) async {
    await pumpScreen(tester, const QuizScreen(unitId: 'g1-u1'), size: const Size(900, 2400));

    expect(find.byType(QuizScreen), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('صح').first, 250, scrollable: scrollable);
    await tester.tap(find.text('صح').first);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('عرض النتيجة'), 250, scrollable: scrollable);
    await tester.tap(find.text('عرض النتيجة'));
    await tester.pump();

    expect(find.textContaining('أجبت عن'), findsWidgets);
  });

  testWidgets('the favorites tab starts with an empty state', (WidgetTester tester) async {
    await pumpApplication(tester);
    await tapDestination(tester, 'المفضلة');

    expect(find.textContaining('لا توجد عناصر محفوظة'), findsOneWidget);
  });

  testWidgets('dark mode can be switched from the settings page', (WidgetTester tester) async {
    final state = await pumpApplication(tester);
    await tapDestination(tester, 'الإعدادات');

    await tester.tap(find.text('ليلي').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(state.themeMode, ThemeMode.dark);
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);
  });

  testWidgets('the favorites survive a restart through the repository',
      (WidgetTester tester) async {
    final memory = ReadingProgress(favorites: <String>{'g1-u1'}, gradeId: testGrade);
    await pumpApplication(tester, progress: memory);
    await tapDestination(tester, 'المفضلة');

    expect(find.textContaining('الوحدات المحفوظة'), findsOneWidget);
  });

  testWidgets('the shell switches to a navigation bar on a phone', (WidgetTester tester) async {
    await pumpApplication(tester, size: const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    final error = tester.takeException();
    final overflows = findFlexOverflows(tester);
    if (error != null || overflows.isNotEmpty) {
      reportLayoutDiagnostic('[shell] error=${error ?? 'none'}');
      for (final hit in overflows) {
        reportLayoutDiagnostic('[shell] $hit');
      }
    }
    expect(overflows, isEmpty, reason: 'shell overflow');
    expect(error, isNull, reason: 'shell exception');
  });

  testWidgets('the shell switches to a navigation rail on a desktop window',
      (WidgetTester tester) async {
    await pumpApplication(tester, size: const Size(1600, 1000));

    expect(find.byType(NavigationRail), findsOneWidget);
  });
}
