import 'package:flutter/material.dart';

import '../../domain/models/library.dart';
import '../screens/favorites_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/lesson_screen.dart';
import '../screens/lessons_screen.dart';
import '../screens/plate_viewer_screen.dart';
import '../screens/plates_screen.dart';
import '../screens/quiz_screen.dart';
import '../screens/search_screen.dart';
import '../screens/unit_screen.dart';

/// Central navigation helpers so that screens never build routes by hand.
abstract final class AppRoutes {
  static Future<void> openUnit(BuildContext context, LearningUnit unit) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => UnitScreen(unitId: unit.id)),
    );
  }

  static Future<void> openQuiz(BuildContext context, LearningUnit unit) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => QuizScreen(unitId: unit.id)),
    );
  }

  static Future<void> openLesson(BuildContext context, LessonPlan lesson) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => LessonScreen(lessonId: lesson.id)),
    );
  }

  static Future<void> openLessons(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const LessonsScreen()),
    );
  }

  static Future<void> openPlates(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const PlatesScreen()),
    );
  }

  static Future<void> openPlate(BuildContext context, Plate plate) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => PlateViewerScreen(plateId: plate.id)),
    );
  }

  static Future<void> openPlateById(BuildContext context, String plateId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => PlateViewerScreen(plateId: plateId)),
    );
  }

  static Future<void> openGlossary(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const GlossaryScreen()),
    );
  }

  static Future<void> openSearch(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const SearchScreen()),
    );
  }

  static Future<void> openFavorites(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const FavoritesScreen()),
    );
  }
}
