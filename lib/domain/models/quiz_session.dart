import 'library.dart';

/// Pure grading logic for a unit quiz.
///
/// Kept outside the widget layer so that the scoring rules of the source
/// questions can be tested without building any UI.
class QuizSession {
  QuizSession(this.questions);

  final List<Question> questions;

  final Map<String, bool> _trueFalse = <String, bool>{};
  final Map<String, int> _choices = <String, int>{};
  final Set<String> _revealed = <String>{};

  bool get isEmpty => questions.isEmpty;

  /// Questions that can be graded automatically (true/false and single choice).
  List<Question> get gradable =>
      questions.where((Question question) => question.isGradable).toList(growable: false);

  List<Question> get open =>
      questions.where((Question question) => question.kind == QuestionKind.open).toList(growable: false);

  void answerTrueFalse(Question question, bool value) {
    _trueFalse[question.id] = value;
  }

  void answerChoice(Question question, int index) {
    _choices[question.id] = index;
  }

  void reveal(Question question) {
    _revealed.add(question.id);
  }

  bool isRevealed(Question question) => _revealed.contains(question.id);

  bool? trueFalseAnswer(Question question) => _trueFalse[question.id];

  int? choiceAnswer(Question question) => _choices[question.id];

  bool isAnswered(Question question) {
    switch (question.kind) {
      case QuestionKind.trueFalse:
        return _trueFalse[question.id] != null;
      case QuestionKind.choice:
        return _choices[question.id] != null;
      case QuestionKind.open:
        return _revealed.contains(question.id);
    }
  }

  bool isCorrect(Question question) {
    switch (question.kind) {
      case QuestionKind.trueFalse:
        return question.boolAnswer != null && _trueFalse[question.id] == question.boolAnswer;
      case QuestionKind.choice:
        return question.answerIndex != null && _choices[question.id] == question.answerIndex;
      case QuestionKind.open:
        return false;
    }
  }

  int get correctCount => gradable.where(isCorrect).length;

  int get answeredCount => gradable.where(isAnswered).length;

  /// Null until every automatically graded question has an answer.
  int? get score {
    if (gradable.isEmpty) {
      return null;
    }
    if (answeredCount < gradable.length) {
      return null;
    }
    return correctCount;
  }

  /// True when the last selection of a choice question has no documented
  /// answer in the source summary; such a question is never graded.
  bool isUndocumentedChoice(Question question) =>
      question.kind == QuestionKind.choice && question.answerIndex == null;

  void reset() {
    _trueFalse.clear();
    _choices.clear();
    _revealed.clear();
  }
}
