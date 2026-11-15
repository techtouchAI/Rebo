import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/models/exam_paper.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Second step: the fields printed in the header and in the closing line.
class ExamInfoPanel extends StatelessWidget {
  const ExamInfoPanel({
    super.key,
    required this.state,
    required this.controllers,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'المدرسة والصف',
          subtitle: 'تُطبع في أعلى الورقة كما في النموذج الرسمي.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('exam-school'),
                controller: controllers.school,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المدرسة',
                  hintText: 'متوسطة …',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setSchoolName,
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final grade = TextField(
                    key: const ValueKey<String>('exam-grade'),
                    controller: controllers.grade,
                    decoration: const InputDecoration(
                      labelText: 'الصف',
                      hintText: 'الأول المتوسط',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: state.setGradeLabel,
                  );
                  final section = TextField(
                    key: const ValueKey<String>('exam-section'),
                    controller: controllers.section,
                    decoration: const InputDecoration(
                      labelText: 'الشعبة',
                      hintText: 'أ',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: state.setSectionName,
                  );
                  if (constraints.maxWidth >= 480) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(child: grade),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: section),
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      grade,
                      const SizedBox(height: AppSpacing.md),
                      section,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'نوع الامتحان',
          subtitle: 'الشطر الأول من عنوان الورقة.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final ExamTerm term in ExamTerm.values)
                    ChoiceChip(
                      key: ValueKey<String>('exam-term-${term.name}'),
                      label: Text(term.label),
                      selected: state.term == term,
                      onSelected: (_) => state.setTerm(term),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final ExamRound round in ExamRound.values)
                    ChoiceChip(
                      key: ValueKey<String>('exam-round-${round.name}'),
                      label: Text(round.label),
                      selected: state.round == round,
                      onSelected: (_) => state.setRound(round),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                key: const ValueKey<String>('exam-year'),
                controller: controllers.year,
                decoration: const InputDecoration(
                  labelText: 'السنة الدراسية',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setAcademicYear,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'السنة مأخوذة من تاريخ الهاتف تلقائياً، ويمكن تعديلها.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'اسم المدرس',
          subtitle: 'يُطبع في أسفل الورقة، ويُحفظ لملء الامتحان القادم تلقائياً.',
          child: TextField(
            key: const ValueKey<String>('exam-teacher'),
            controller: controllers.teacher,
            decoration: const InputDecoration(
              labelText: 'اسم المدرس',
              border: OutlineInputBorder(),
            ),
            onChanged: state.setTeacherName,
          ),
        ),
      ],
    );
  }
}
