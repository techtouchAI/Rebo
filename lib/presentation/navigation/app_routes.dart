import 'package:flutter/material.dart';

import '../../domain/models/library.dart';
import '../screens/drawings_screen.dart';
import '../screens/drawing_viewer_screen.dart';
import '../screens/exam_composer_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/glossary_screen.dart';
import '../screens/lesson_screen.dart';
import '../screens/lessons_screen.dart';
import '../screens/plate_viewer_screen.dart';
import '../screens/plates_screen.dart';
import '../screens/question_print_screen.dart';
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

  static Future<void> openExamComposer(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const ExamComposerScreen()),
    );
  }

  static Future<void> openQuestionPrinting(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const QuestionPrintScreen()),
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

  static Future<void> openDrawings(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => const DrawingsScreen()),
    );
  }

  static Future<void> openDrawing(BuildContext context, TopicDrawing drawing) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DrawingViewerScreen(drawingId: drawing.id),
      ),
    );
  }

  static Future<void> openDrawingById(BuildContext context, String drawingId) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DrawingViewerScreen(drawingId: drawingId),
      ),
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
