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
    test('contains the twelve curriculum units and the introduction', () {
      final gradeUnits = library.units.where((LearningUnit unit) => !unit.isIntroduction).toList();
      expect(gradeUnits.length, 12);
      expect(library.units.where((LearningUnit unit) => unit.isIntroduction).length, 1);
      expect(library.unitsOf('g1').length, 4);
      expect(library.unitsOf('g2').length, 4);
      expect(library.unitsOf('g3').length, 4);
    });

    test('every unit has topics, a template and a source plate', () {
      for (final unit in library.units) {
        expect(unit.topics, isNotEmpty, reason: '${unit.id} has no topics');
        expect(unit.title.trim(), isNotEmpty);
        expect(unit.displayTitle.trim(), isNotEmpty);
        if (!unit.isIntroduction) {
          expect(unit.plate, isNotNull, reason: '${unit.id} has no teacher guide plate');
        }
      }
    });

    test('keeps the expected volume of topics and questions', () {
      final topics = library.units.fold<int>(0, (sum, unit) => sum + unit.topics.length);
      final questions = library.units.fold<int>(0, (sum, unit) => sum + unit.questions.length);
      expect(topics, greaterThanOrEqualTo(70));
      expect(questions, greaterThanOrEqualTo(66));
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

    test('choice answers point inside their option list', () {
      for (final unit in library.units) {
        for (final question in unit.questions.where((q) => q.kind == QuestionKind.choice)) {
          expect(question.options.length, greaterThanOrEqualTo(2));
          final index = question.answerIndex;
          if (index != null) {
            expect(index, inInclusiveRange(0, question.options.length - 1));
            expect(question.answerSupport, isNotNull);
          }
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

    test('lesson plans keep theory and practice sessions', () {
      expect(library.lessons.length, 4);
      for (final lesson in library.lessons) {
        expect(lesson.plans.length, 2);
        expect(lesson.plans.any((plan) => plan.isTheory), isTrue);
        for (final plan in lesson.plans) {
          expect(plan.specificAims, isNotEmpty);
          expect(plan.subject.trim(), isNotEmpty);
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

    test('all referenced assets exist on disk', () {
      final paths = <String>{
        for (final unit in library.units)
          for (final figure in unit.figures) figure.asset,
        for (final lesson in library.lessons)
          for (final figure in lesson.figures) figure.asset,
        for (final plate in library.plates) plate.asset,
        for (final unit in library.units)
          if (unit.plate != null) unit.plate!.asset,
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
