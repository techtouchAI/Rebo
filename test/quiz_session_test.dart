import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/quiz_session.dart';

import 'test_support.dart';

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  QuizSession sessionOf(String unitId) => QuizSession(library.unitById(unitId)!.questions);

  test('open questions are never graded', () {
    final session = sessionOf('g1-u1');
    final open = session.open;
    expect(open, isNotEmpty);
    expect(session.gradable.any((Question q) => q.kind == QuestionKind.open), isFalse);
  });

  test('a full correct run scores every gradable question', () {
    final session = sessionOf('g1-u1');
    for (final question in session.gradable) {
      if (question.kind == QuestionKind.trueFalse) {
        session.answerTrueFalse(question, question.boolAnswer!);
      } else if (question.kind == QuestionKind.choice) {
        session.answerChoice(question, question.answerIndex!);
      }
    }
    expect(session.answeredCount, session.gradable.length);
    expect(session.correctCount, session.gradable.length);
    expect(session.score, session.gradable.length);
  });

  test('a wrong answer is counted as incorrect', () {
    final session = sessionOf('g1-u1');
    final first = session.gradable.first;
    if (first.kind == QuestionKind.trueFalse) {
      session.answerTrueFalse(first, !first.boolAnswer!);
    } else {
      session.answerChoice(first, (first.answerIndex! + 1) % first.options.length);
    }
    expect(session.isCorrect(first), isFalse);
    expect(session.correctCount, 0);
  });

  test('the score stays null until every gradable question is answered', () {
    final session = sessionOf('g1-u1');
    expect(session.score, isNull);
    final first = session.gradable.first;
    if (first.kind == QuestionKind.trueFalse) {
      session.answerTrueFalse(first, first.boolAnswer!);
    } else {
      session.answerChoice(first, first.answerIndex!);
    }
    expect(session.score, isNull);
    expect(session.answeredCount, 1);
  });

  test('an undocumented choice question is never marked wrong', () {
    const undocumented = Question(
      id: 'q-ungraded',
      kind: QuestionKind.choice,
      prompt: 'سؤال للمناقشة',
      options: <String>['أ', 'ب'],
      answerIndex: null,
    );
    final session = QuizSession(<Question>[undocumented]);
    session.answerChoice(undocumented, 0);
    expect(session.gradable, isEmpty);
    expect(session.score, isNull);
    expect(session.isCorrect(undocumented), isFalse);
  });

  test('every choice question in the unified booklet is gradable with evidence', () {
    for (final unit in library.units) {
      for (final question in unit.questions.where((Question q) => q.kind == QuestionKind.choice)) {
        expect(question.isGradable, isTrue, reason: '${unit.id}/${question.id}');
        expect(question.answerSupport, isNotNull, reason: '${unit.id}/${question.id}');
      }
    }
  });

  test('reset clears every answer', () {
    final session = sessionOf('g1-u1');
    final question = session.gradable.first;
    if (question.kind == QuestionKind.trueFalse) {
      session.answerTrueFalse(question, true);
    } else {
      session.answerChoice(question, 0);
    }
    session.reset();
    expect(session.answeredCount, 0);
    expect(session.isAnswered(question), isFalse);
  });
}
