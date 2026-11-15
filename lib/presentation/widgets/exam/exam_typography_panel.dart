import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// First step of the composer: typeface and point sizes of the exported file.
class ExamTypographyPanel extends StatelessWidget {
  const ExamTypographyPanel({
    super.key,
    required this.state,
    required this.controllers,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'نوع الخط وحجمه',
          subtitle: 'تُطبَّق على ملف وورد عند التصدير، ولا تغيّر خط التطبيق.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              DropdownButtonFormField<ExamPaperFont>(
                key: const ValueKey<String>('exam-font'),
                initialValue: state.font,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'نوع الخط',
                  border: OutlineInputBorder(),
                ),
                items: <DropdownMenuItem<ExamPaperFont>>[
                  for (final ExamPaperFont font in ExamPaperFont.values)
                    DropdownMenuItem<ExamPaperFont>(
                      value: font,
                      child: Text(font.label, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (ExamPaperFont? font) {
                  if (font != null) {
                    state.setFont(font);
                  }
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              _sizes(),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        _preview(context),
      ],
    );
  }

  Widget _sizes() {
    final fields = <Widget>[
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-header-size'),
        label: 'حجم خط الترويسة',
        controller: controllers.headerSize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setHeaderFontSize(
          _sizeOf(controllers.headerSize),
        ),
      ),
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-body-size'),
        label: 'حجم خط الأسئلة',
        controller: controllers.bodySize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setBodyFontSize(_sizeOf(controllers.bodySize)),
      ),
      ExamNumberField(
        fieldKey: const ValueKey<String>('exam-heading-size'),
        label: 'حجم خط العناوين',
        controller: controllers.headingSize,
        unit: 'نقطة',
        min: ExamPaperTypography.minFontSize,
        max: ExamPaperTypography.maxFontSize,
        onChanged: () => state.setHeadingFontSize(
          _sizeOf(controllers.headingSize),
        ),
      ),
    ];
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 560) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (var i = 0; i < fields.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: AppSpacing.md),
                Expanded(child: fields[i]),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (var i = 0; i < fields.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              fields[i],
            ],
          ],
        );
      },
    );
  }

  Widget _preview(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final typography = state.typography ?? const ExamPaperTypography();
    return ExamPanelCard(
      title: 'معاينة الأحجام',
      subtitle: 'الحجم يظهر كما سيُطبع؛ نوع الخط يظهر داخل ملف وورد.',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'اسئلة امتحانات ${state.term.label}',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: typography.headerFontSize.toDouble(),
              ),
            ),
            Text(
              'المادة النظرية / اجب عن سؤالين فقط',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: typography.headingFontSize.toDouble(),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '1- ضع علامة صح امام العبارة الصحيحة',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: typography.bodyFontSize.toDouble(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static int? _sizeOf(TextEditingController controller) =>
      parseIntegerDigits(controller.text);
}
