import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import '../../state/exam_composer_state.dart';
import 'exam_panel_parts.dart';

/// Last step: the summary, the preview of the printed paper and the missing
/// fields, so the export never produces a half-filled file.
class ExamReviewPanel extends StatelessWidget {
  const ExamReviewPanel({
    super.key,
    required this.state,
    required this.paper,
  });

  final ExamComposerState state;
  final ExamPaper? paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ExamPaper? paper = this.paper;
    final List<String> issues = state.issues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'ملخص الامتحان',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _row(context, 'المدرسة', state.schoolName.trim().isEmpty ? '—' : state.schoolName),
              _row(context, 'الصف والشعبة', _classLabel()),
              _row(
                context,
                'الامتحان',
                '${state.term.label} • ${state.round.label}',
              ),
              _row(context, 'السنة الدراسية', state.academicYear),
              _row(context, 'المدرس', state.teacherName.trim().isEmpty ? '—' : state.teacherName),
              _row(
                context,
                'المحتوى',
                '${toArabicDigits('${state.theoryItemCount}')} عنصراً نظرياً • '
                    '${toArabicDigits('${state.practicalCount}')} سؤالاً عملياً',
              ),
              _row(context, 'الدرجات', _degreesLabel()),
            ],
          ),
        ),
        if (issues.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          ExamPanelCard(
            title: 'ما يزال ناقصاً',
            accent: theme.colorScheme.error,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final String issue in issues)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(bottom: AppSpacing.xs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Icon(Icons.error_outline, size: 18, color: theme.colorScheme.error),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(issue, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'معاينة الورقة',
          subtitle: 'هذا نص الملف الذي سيُصدَّر، بترتيب الورقة الرسمية.',
          child: paper == null
              ? Text(
                  'أكمل البيانات والأسئلة لعرض المعاينة.',
                  style: theme.textTheme.bodyMedium,
                )
              : SelectableText(
                  examPaperAsPlainText(paper),
                  key: const ValueKey<String>('exam-preview'),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ExamPanelCard(
          title: 'ملف وورد',
          child: Text(
            paper == null
                ? 'يُصدَّر الملف بعد استكمال البيانات.'
                : 'اسم الملف: ${examPaperFileName(paper)}\n'
                      'يُصدَّر بترتيب النموذج الرسمي: الترويسة بجدول ثلاثة أعمدة، '
                      'ثم جدول الدرجات، ثم القسم النظري، ثم القسم العملي، '
                      'ثم تمنياتي واسم المدرس.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  String _classLabel() {
    final grade = state.gradeLabel.trim();
    final section = state.sectionName.trim();
    if (grade.isEmpty && section.isEmpty) {
      return '—';
    }
    if (section.isEmpty) {
      return grade;
    }
    return '$grade / شعبة $section';
  }

  String _degreesLabel() {
    final theory = state.theoryDegree;
    final practical = state.practicalDegree;
    final parts = <String>[
      if (theory != null) 'النظري ${toArabicDigits('$theory')}',
      if (practical != null) 'العملي ${toArabicDigits('$practical')}',
    ];
    return parts.isEmpty ? '—' : parts.join(' • ');
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
