import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/presentation/screens/favorites_screen.dart';
import 'package:mirsam/presentation/screens/glossary_screen.dart';
import 'package:mirsam/presentation/screens/home_screen.dart';
import 'package:mirsam/presentation/screens/index_screen.dart';
import 'package:mirsam/presentation/screens/lesson_screen.dart';
import 'package:mirsam/presentation/screens/lessons_screen.dart';
import 'package:mirsam/presentation/screens/plate_viewer_screen.dart';
import 'package:mirsam/presentation/screens/plates_screen.dart';
import 'package:mirsam/presentation/screens/quiz_screen.dart';
import 'package:mirsam/presentation/screens/search_screen.dart';
import 'package:mirsam/presentation/screens/settings_screen.dart';
import 'package:mirsam/presentation/screens/unit_screen.dart';

import 'overflow_utils.dart';
import 'test_support.dart';

/// Every screen must fit a 360/390 logical pixel phone without any overflow.
const Size phone = Size(390, 844);

Future<void> expectFitsPhone(WidgetTester tester, Widget screen, String name) async {
  await pumpScreen(tester, screen, size: phone);
  final error = tester.takeException();
  final overflows = findFlexOverflows(tester);
  if (error != null || overflows.isNotEmpty) {
    debugPrint('LAYOUT-DIAG [$name] error=${error ?? 'none'}');
    for (final hit in overflows) {
      debugPrint('LAYOUT-DIAG [$name] $hit');
    }
  }
  expect(overflows, isEmpty, reason: 'layout overflow on $name');
  expect(error, isNull, reason: 'exception on $name');
}

void main() {
  setUpAll(ensureLibrary);

  testWidgets('home screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const HomeScreen(), 'home');
  });

  testWidgets('index screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const IndexScreen(), 'index');
  });

  testWidgets('favorites screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const FavoritesScreen(embedded: true), 'favorites');
  });

  testWidgets('settings screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const SettingsScreen(embedded: true), 'settings');
  });

  testWidgets('glossary screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const GlossaryScreen(), 'glossary');
  });

  testWidgets('plates gallery fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const PlatesScreen(), 'plates');
  });

  testWidgets('plate viewer fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const PlateViewerScreen(plateId: 'plate-08'), 'plate viewer');
  });

  testWidgets('lessons index fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const LessonsScreen(), 'lessons');
  });

  testWidgets('lesson plan fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const LessonScreen(lessonId: 'lesson-light'), 'lesson');
  });

  testWidgets('unit reader fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const UnitScreen(unitId: 'g1-u1'), 'unit');
  });

  testWidgets('quiz screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const QuizScreen(unitId: 'g1-u1'), 'quiz');
  });

  testWidgets('search screen fits a phone', (WidgetTester tester) async {
    await expectFitsPhone(tester, const SearchScreen(), 'search');
  });
}
