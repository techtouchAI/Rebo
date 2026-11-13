import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/presentation/screens/glossary_screen.dart';
import 'package:mirsam/presentation/screens/index_screen.dart';
import 'package:mirsam/presentation/screens/quiz_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';

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

  testWidgets('the index lists every grade and its units', (WidgetTester tester) async {
    await pumpApplication(tester);
    await tapDestination(tester, 'الفهرس');

    expect(find.byType(IndexScreen), findsOneWidget);
    expect(find.textContaining('الصف الأول المتوسط'), findsWidgets);
    expect(find.textContaining('الوحدة الأولى: التعبير الفني'), findsWidgets);
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
    final memory = ReadingProgress(favorites: <String>{'g1-u1'});
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
