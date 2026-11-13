import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/library.dart';
import '../../domain/models/quiz_session.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// Unit self-assessment built only from the questions of the source document.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.unitId});

  final String unitId;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizSession? _session;
  bool _submitted = false;

  QuizSession _sessionFor(LearningUnit unit) => _session ??= QuizSession(unit.questions);

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unit = state.library.unitById(widget.unitId);
    if (unit == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('الوحدة غير موجودة')));
    }
    final theme = Theme.of(context);
    final session = _sessionFor(unit);
    final gradable = session.gradable;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اختبر فهمك'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(unit.title, style: theme.textTheme.headlineLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'أسئلة الوحدة كما وردت في ملخص التربية الفنية. الأسئلة الموضوعية تُصحّح تلقائياً، '
                  'وأسئلة التعداد تُكشف إجاباتها بعد المحاولة.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_submitted)
                  _ScoreCard(
                    correct: session.correctCount,
                    total: gradable.length,
                    answered: session.answeredCount,
                    score: session.score,
                    onRetry: () => setState(() {
                      session.reset();
                      _submitted = false;
                    }),
                  ),
                const SizedBox(height: AppSpacing.md),
                for (int i = 0; i < unit.questions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _QuestionCard(
                      index: i + 1,
                      question: unit.questions[i],
                      selectedChoice: session.choiceAnswer(unit.questions[i]),
                      selectedBool: session.trueFalseAnswer(unit.questions[i]),
                      revealed: session.isRevealed(unit.questions[i]),
                      submitted: _submitted,
                      onChoice: (int value) => setState(
                        () => session.answerChoice(unit.questions[i], value),
                      ),
                      onBool: (bool value) => setState(
                        () => session.answerTrueFalse(unit.questions[i], value),
                      ),
                      onReveal: () => setState(
                        () => session.reveal(unit.questions[i]),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _submitted = true);
                    final score = session.score;
                    if (score != null) {
                      state.recordQuizScore(unit.id, score);
                    }
                  },
                  icon: const Icon(Icons.fact_check_outlined),
                  label: const Text('عرض النتيجة'),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.correct,
    required this.total,
    required this.answered,
    required this.score,
    required this.onRetry,
  });

  final int correct;
  final int total;
  final int answered;
  final int? score;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.emoji_events_outlined, size: 34, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  score == null
                      ? 'أجبت عن ${toArabicDigits('$answered')} من ${toArabicDigits('$total')} سؤالاً موضوعياً'
                      : 'نتيجتك: ${toArabicDigits('$correct')} من ${toArabicDigits('$total')}',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                Text(
                  score == null
                      ? 'أكمل بقية الأسئلة الموضوعية لعرض النتيجة.'
                      : 'تُحتسب كل إجابة صحيحة بنقطة واحدة.',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('إعادة')),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selectedChoice,
    required this.selectedBool,
    required this.revealed,
    required this.submitted,
    required this.onChoice,
    required this.onBool,
    required this.onReveal,
  });

  final int index;
  final Question question;
  final int? selectedChoice;
  final bool? selectedBool;
  final bool revealed;
  final bool submitted;
  final ValueChanged<int> onChoice;
  final ValueChanged<bool> onBool;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text('${toArabicDigits('$index')}', style: theme.textTheme.labelLarge),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(question.prompt, style: theme.textTheme.titleMedium),
              ),
              if (question.kind == QuestionKind.open)
                Text('تعداد', style: theme.textTheme.labelMedium),
              if (question.kind == QuestionKind.choice && question.answerIndex == null)
                Text('مراجعة', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (question.kind == QuestionKind.trueFalse)
            Row(
              children: <Widget>[
                _ChoiceButton(
                  label: 'صح',
                  selected: selectedBool == true,
                  correct: submitted || revealed ? question.boolAnswer == true : null,
                  onTap: () => onBool(true),
                ),
                const SizedBox(width: AppSpacing.sm),
                _ChoiceButton(
                  label: 'خطأ',
                  selected: selectedBool == false,
                  correct: submitted || revealed ? question.boolAnswer == false : null,
                  onTap: () => onBool(false),
                ),
              ],
            ),
          if (question.kind == QuestionKind.choice)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _OptionButton(
                      label: question.options[i],
                      selected: selectedChoice == i,
                      correct: (submitted || revealed) ? question.answerIndex == i : null,
                      onTap: () => onChoice(i),
                    ),
                  ),
                if (submitted && question.answerIndex == null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      'لم يذكر ملخص الوحدة الإجابة صراحةً؛ يُترك السؤال للمناقشة داخل الصف.',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
              ],
            ),
          if (question.kind == QuestionKind.open) ...<Widget>[
            if (revealed || submitted)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  question.answerText.isEmpty
                      ? 'لا توجد إجابة مدونة لهذا السؤال.'
                      : 'الإجابة: ${question.answerText}',
                  style: theme.textTheme.bodyLarge,
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: onReveal,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('أظهر الإجابة'),
              ),
          ],
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool? correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color background = Colors.transparent;
    if (selected) {
      border = scheme.primary;
      background = scheme.primary.withValues(alpha: 0.1);
    }
    if (correct == true) {
      border = const Color(0xFF2E7D32);
      background = const Color(0xFF2E7D32).withValues(alpha: 0.12);
    } else if (correct == false && selected) {
      border = scheme.error;
      background = scheme.error.withValues(alpha: 0.1);
    }
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.sm),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: border),
          ),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.selected,
    required this.correct,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool? correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Color border = scheme.outlineVariant;
    Color background = Colors.transparent;
    IconData? icon;
    if (selected) {
      border = scheme.primary;
      background = scheme.primary.withValues(alpha: 0.08);
      icon = Icons.radio_button_checked;
    } else {
      icon = Icons.radio_button_unchecked;
    }
    if (correct == true) {
      border = const Color(0xFF2E7D32);
      background = const Color(0xFF2E7D32).withValues(alpha: 0.1);
      icon = Icons.check_circle_outline;
    } else if (correct == false && selected) {
      border = scheme.error;
      background = scheme.error.withValues(alpha: 0.08);
      icon = Icons.cancel_outlined;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          border: Border.all(color: border),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: border),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}
