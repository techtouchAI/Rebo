import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Third step: the three theoretical questions, one screen at a time, in the
/// official order (true/false → choice → enumeration).
class ExamTheoryPanel extends StatelessWidget {
  const ExamTheoryPanel({
    super.key,
    required this.state,
    required this.controllers,
    required this.index,
    required this.onIndexChanged,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  /// 0 = true/false, 1 = choice, 2 = enumeration.
  final int index;
  final ValueChanged<int> onIndexChanged;

  QuestionKind get kind => ExamTheoryQuestion.kinds[index];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final QuestionKind kind = this.kind;
    final List<ExamQuestionOption> options = state.optionsOf(kind);
    final Set<String> selected = state.selectionOf(kind);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (index == 0) ...<Widget>[
          _theoryHeadingCard(context),
          const SizedBox(height: AppSpacing.lg),
        ],
        _questionBar(context),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: '${examQuestionNumber(index)}: ${theoryKindLabel(kind)}',
          subtitle: 'نص السؤال والدرجة كما سيظهران في الورقة.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: ValueKey<String>('exam-instruction-${kind.name}'),
                controller: controllers.instructions[kind],
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'نص السؤال',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String value) => state.setInstruction(kind, value),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final degree = ExamNumberField(
                    fieldKey: ValueKey<String>('exam-degree-${kind.name}'),
                    label: 'درجة السؤال',
                    controller: controllers.degrees[kind]!,
                    onChanged: () => state.setDegree(
                      kind,
                      parseIntegerDigits(controllers.degrees[kind]!.text),
                    ),
                  );
                  if (kind != QuestionKind.open) {
                    return degree;
                  }
                  final lines = ExamNumberField(
                    fieldKey: const ValueKey<String>('exam-answer-lines'),
                    label: 'أسطر الإجابة',
                    controller: controllers.answerLines,
                    min: 1,
                    max: ExamTheoryQuestion.maxAnswerLineCount,
                    onChanged: () => state.setAnswerLineCount(
                      kind,
                      parseIntegerDigits(controllers.answerLines.text),
                    ),
                  );
                  if (constraints.maxWidth >= 480) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: degree),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: lines),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      degree,
                      const SizedBox(height: AppSpacing.md),
                      lines,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'محتوى السؤال',
          subtitle: options.isEmpty
              ? 'لا توجد أسئلة من هذا النوع في هذا الصف.'
              : '${toArabicDigits('${selected.length}')} محدداً من '
                    '${toArabicDigits('${options.length}')}',
          child: options.isEmpty
              ? const EmptyState(
                  icon: Icons.quiz_outlined,
                  title: 'لا توجد أسئلة متاحة',
                  message: 'اختر صفاً آخر من الشاشة الرئيسية لعرض أسئلته.',
                )
              : Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Column(
                    children: <Widget>[
                      for (var i = 0; i < options.length; i++) ...<Widget>[
                        if (i > 0) const Divider(height: 1),
                        CheckboxListTile(
                          key: ValueKey<String>('exam-item-${options[i].id}'),
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.contains(options[i].id),
                          title: Text(
                            options[i].question.prompt,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            _subtitle(options[i]),
                            style: theme.textTheme.labelSmall,
                          ),
                          onChanged: (bool? value) => _toggle(kind, options[i].id),
                        ),
                      ],
                    ],
                  ),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _navigation(context),
      ],
    );
  }

  void _toggle(QuestionKind kind, String id) {
    state.toggleItem(kind, id);
    if (!state.isInstructionCustomized(kind)) {
      final TextEditingController? controller = controllers.instructions[kind];
      final text = state.instructionOf(kind);
      if (controller != null && controller.text != text) {
        controller.text = text;
      }
    }
  }

  static String _subtitle(ExamQuestionOption option) {
    final Question question = option.question;
    if (question.kind == QuestionKind.choice && question.options.isNotEmpty) {
      return '${option.unitTitle} • ${question.options.join(' / ')}';
    }
    return option.unitTitle;
  }

  /// The printable heading of the theoretical section; the teacher can edit
  /// its wording, the degrees stay next to it.
  Widget _theoryHeadingCard(BuildContext context) {
    return ExamPanelCard(
      title: 'عنوان المادة النظرية',
      subtitle:
          'يُطبع: نصك، ثم ____________ والدرجات. إجمالي النظري '
          '${toArabicDigits('${state.theoryDegree ?? 0}')} درجة.',
      child: TextField(
        key: const ValueKey<String>('exam-theory-header'),
        controller: controllers.theoryHeader,
        maxLines: null,
        decoration: const InputDecoration(
          labelText: 'نص العنوان',
          border: OutlineInputBorder(),
        ),
        onChanged: state.setTheoryHeader,
      ),
    );
  }

  Widget _questionBar(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      children: <Widget>[
        for (var i = 0; i < ExamTheoryQuestion.kinds.length; i++)
          ChoiceChip(
            key: ValueKey<String>('exam-theory-tab-$i'),
            selected: i == index,
            label: Text(
              '${examQuestionNumber(i)} ${theoryKindLabel(ExamTheoryQuestion.kinds[i])}',
            ),
            onSelected: (_) {
              if (i != index) {
                onIndexChanged(i);
              }
            },
          ),
        Padding(
          padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
          child: Text(
            '${toArabicDigits('${index + 1}')} / '
            '${toArabicDigits('${ExamTheoryQuestion.kinds.length}')}',
            style: theme.textTheme.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _navigation(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.xs,
      alignment: WrapAlignment.spaceBetween,
      children: <Widget>[
        if (index > 0)
          OutlinedButton.icon(
            key: const ValueKey<String>('exam-theory-previous'),
            onPressed: () => onIndexChanged(index - 1),
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: const Text('السؤال السابق'),
          ),
        if (index < ExamTheoryQuestion.kinds.length - 1)
          FilledButton.tonalIcon(
            key: const ValueKey<String>('exam-theory-next'),
            onPressed: () => onIndexChanged(index + 1),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('السؤال التالي'),
          ),
      ],
    );
  }
}
