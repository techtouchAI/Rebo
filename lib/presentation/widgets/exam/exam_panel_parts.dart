import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';

/// Bordered block shared by the composer panels.
class ExamPanelCard extends StatelessWidget {
  const ExamPanelCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.accent,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = this.title;
    final subtitle = this.subtitle;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (title != null) ...<Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 18,
                  margin: const EdgeInsetsDirectional.only(end: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: accent ?? scheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            if (subtitle != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Text(subtitle, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
          child,
        ],
      ),
    );
  }
}

/// Numeric field for a point size or a mark, validated against [min]/[max].
class ExamNumberField extends StatelessWidget {
  const ExamNumberField({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.enabled = true,
    this.helperText,
    this.unit,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final int min;
  final int max;
  final bool enabled;
  final String? helperText;

  /// Optional unit shown before the range, e.g. `نقطة`.
  final String? unit;

  @override
  Widget build(BuildContext context) {
    final value = parseIntegerDigits(controller.text);
    final valid = value != null && value >= min && value <= max;
    final range = '${toArabicDigits('$min')}–${toArabicDigits('$max')}';
    final unit = this.unit;
    final helper = helperText ?? 'من $range${unit == null ? '' : ' $unit'}';
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        errorText: valid ? null : 'أدخل رقماً من $range',
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}
