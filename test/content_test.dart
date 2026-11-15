import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';

import 'test_support.dart';

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  group('content integrity', () {
    test('contains the nine curriculum units, the introduction and the theatre section', () {
      final gradeUnits = library.units
          .where((LearningUnit unit) => !unit.isIntroduction && !unit.isTheatre)
          .toList();
      expect(gradeUnits.length, 9);
      expect(library.units.where((LearningUnit unit) => unit.isIntroduction).length, 1);
      expect(library.units.where((LearningUnit unit) => unit.isTheatre).length, 1);
      expect(library.unitsOf('g1').length, 3);
      expect(library.unitsOf('g2').length, 3);
      expect(library.unitsOf('g3').length, 3);
    });

    test('every unit has topics, a template and its documented plates', () {
      const unitsWithPlates = <String>{
        'g1-u1',
        'g1-u2',
        'g1-u4',
        'g2-u4',
        'g3-u2',
        'g3-u4',
      };
      for (final unit in library.units) {
        expect(unit.topics, isNotEmpty, reason: '${unit.id} has no topics');
        expect(unit.title.trim(), isNotEmpty);
        expect(unit.displayTitle.trim(), isNotEmpty);
        if (unitsWithPlates.contains(unit.id)) {
          expect(unit.plates, isNotEmpty, reason: '${unit.id} has no plates');
        }
      }
    });

    test('keeps the expected volume of topics and questions', () {
      final topics = library.units.fold<int>(0, (sum, unit) => sum + unit.topics.length);
      final questions = library.units.fold<int>(0, (sum, unit) => sum + unit.questions.length);
      expect(topics, 37);
      expect(questions, 73);
    });

    test('no empty statements, no duplicated identifiers', () {
      final ids = <String>{};
      for (final unit in library.units) {
        expect(ids.add(unit.id), isTrue, reason: 'duplicate unit id ${unit.id}');
        for (final topic in unit.topics) {
          expect(topic.title.trim(), isNotEmpty);
          for (final bullet in topic.bullets) {
            expect(bullet.trim(), isNotEmpty, reason: '${unit.id}/${topic.id} empty bullet');
            expect(bullet.contains('{{'), isFalse);
          }
        }
        final questionIds = <String>{};
        for (final question in unit.questions) {
          expect(questionIds.add(question.id), isTrue);
          expect(question.prompt.trim(), isNotEmpty);
        }
      }
    });

    test('all choice answers point inside their option list with support', () {
      for (final unit in library.units) {
        for (final question in unit.questions.where((q) => q.kind == QuestionKind.choice)) {
          expect(question.options.length, greaterThanOrEqualTo(2));
          final index = question.answerIndex;
          expect(index, isNotNull, reason: '${unit.id}/${question.id} missing answerIndex');
          expect(index!, inInclusiveRange(0, question.options.length - 1));
          expect(question.answerSupport, isNotNull);
        }
      }
    });

    test('false true/false answers include their reason from the unified answer key', () {
      for (final unit in library.units) {
        for (final question in unit.questions.where(
          (q) => q.kind == QuestionKind.trueFalse && q.boolAnswer == false,
        )) {
          expect(
            question.answerSupport?.trim(),
            isNotEmpty,
            reason: '${unit.id}/${question.id} missing false-statement reason',
          );
        }
      }
    });

    test('the introduction carries the objectives and the teaching methods', () {
      final intro = library.units.firstWhere((LearningUnit unit) => unit.isIntroduction);
      final objectives = intro.topics.firstWhere((topic) => topic.listItems.isNotEmpty);
      expect(objectives.listItems.length, greaterThanOrEqualTo(10));
      final methods = intro.topics.where((topic) => topic.methods.isNotEmpty).toList();
      expect(methods.length, 2);
      final total = methods.fold<int>(0, (sum, topic) => sum + topic.methods.length);
      expect(total, greaterThanOrEqualTo(8));
    });

    test('practical lessons keep only the presentation and the home assignment', () {
      expect(library.lessons.length, 4);
      for (final lesson in library.lessons) {
        expect(lesson.plans.length, 1, reason: '${lesson.id} still has a second session');
        final plan = lesson.plans.first;
        expect(plan.subject.trim(), isNotEmpty);
        expect(plan.body, isNotEmpty);
        for (final block in plan.body) {
          expect(block.text.contains('الأهداف العامة'), isFalse);
          expect(block.text.contains('الوسائل التعليمية'), isFalse);
        }
      }
    });

    test('the theatre theme is a section of its own, not a plate', () {
      final theatre = library.units.firstWhere((LearningUnit unit) => unit.isTheatre);
      expect(theatre.topics.length, greaterThanOrEqualTo(5));
      expect(theatre.intro.trim(), isNotEmpty);
      expect(theatre.plate, isNull);
      expect(
        library.plates.where((Plate plate) => plate.unitId == theatre.id),
        isEmpty,
      );
      expect(library.sections.any((ContentSection s) => s.kind == 'theatre'), isTrue);
      expect(library.sections.any((ContentSection s) => s.kind == 'plates' && s.title.contains('دليل')), isFalse);
    });

    test('no page credits remain on plates', () {
      for (final plate in library.plates) {
        expect(plate.caption.contains('المصدر:'), isFalse, reason: plate.id);
      }
      for (final unit in library.units) {
        for (final plate in unit.plates) {
          expect(plate.caption.contains('المصدر:'), isFalse, reason: unit.id);
        }
      }
    });

    test('glossary terms point to existing units', () {
      expect(library.glossary.length, greaterThanOrEqualTo(20));
      for (final term in library.glossary) {
        expect(library.unitById(term.unitId), isNotNull, reason: term.term);
        expect(term.definition.trim(), isNotEmpty);
      }
    });

    test('every plate asset exists and has valid size', () {
      for (final plate in library.plates) {
        final file = File(plate.asset);
        expect(file.existsSync(), isTrue, reason: plate.asset);
        expect(file.lengthSync(), lessThan(260 * 1024), reason: '${plate.asset} unexpectedly large');
        expect(file.lengthSync(), greaterThan(10 * 1024), reason: '${plate.asset} unexpectedly small');
      }
      expect(library.plates.length, 10);
    });

    test('all referenced assets exist on disk', () {
      final paths = <String>{
        for (final unit in library.units)
          for (final figure in unit.figures) figure.asset,
        for (final lesson in library.lessons)
          for (final figure in lesson.figures) figure.asset,
        for (final plate in library.plates) plate.asset,
        for (final unit in library.units)
          for (final plate in unit.plates) plate.asset,
      };
      expect(paths.length, greaterThanOrEqualTo(20));
      for (final path in paths) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing asset $path');
        expect(file.lengthSync(), greaterThan(512), reason: 'suspicious asset $path');
      }
    });

    test('illustrations are well-formed vector files', () {
      final files = Directory('assets/illustrations')
          .listSync()
          .whereType<File>()
          .where((File file) => file.path.endsWith('.svg'));
      expect(files.length, greaterThanOrEqualTo(18));
      for (final file in files) {
        final content = file.readAsStringSync();
        expect(content.contains('<svg'), isTrue, reason: file.path);
        expect(content.contains('</svg>'), isTrue, reason: file.path);
        expect(content.contains('{{'), isFalse);
      }
    });

    test('the JSON payload is valid and complete', () {
      final raw = File('assets/content/curriculum.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect((decoded['units'] as List<dynamic>).length, library.units.length);
      expect(raw.contains('مِرسم'), isTrue);
    });
  });
}
