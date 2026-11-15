import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/local/question_pdf.dart';
import '../../domain/models/question_print_settings.dart';
import '../../domain/services/question_print_plan.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// The optional callback makes the platform print operation replaceable in UI
/// tests; production uses [QuestionPrinter]. The plan includes print settings.
typedef PrintQuestions = Future<void> Function(QuestionPrintPlan plan, String gradeTitle);

class QuestionPrintScreen extends StatefulWidget {
  const QuestionPrintScreen({super.key, this.printQuestions});

  final PrintQuestions? printQuestions;

  @override
  State<QuestionPrintScreen> createState() => _QuestionPrintScreenState();
}

class _QuestionPrintScreenState extends State<QuestionPrintScreen> {
  Set<String> _selectedIds = <String>{};
  String? _selectionGrade;
  bool _initialized = false;
  bool _printing = false;
  QuestionPrintFont _font = QuestionPrintFont.plex;
  final _bodySize = TextEditingController(text: '${QuestionPrintSettings.defaultBodyFontSize}');
  final _headingSize = TextEditingController(
    text: '${QuestionPrintSettings.defaultHeadingFontSize}',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppScope.of(context);
    if (!_initialized || _selectionGrade != state.gradeId) {
      _selectionGrade = state.gradeId;
      _selectedIds = printableUnits(state.visibleUnits).map((unit) => unit.id).toSet();
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _bodySize.dispose();
    _headingSize.dispose();
    super.dispose();
  }

  QuestionPrintSettings? get _settings {
    final body = _parseFontSize(_bodySize.text);
    final heading = _parseFontSize(_headingSize.text);
    if (!QuestionPrintSettings.isValidFontSize(body) ||
        !QuestionPrintSettings.isValidFontSize(heading)) {
      return null;
    }
    return QuestionPrintSettings(font: _font, bodyFontSize: body!, headingFontSize: heading!);
  }

  Future<void> _print(QuestionPrintPlan plan, String gradeTitle) async {
    if (plan.isEmpty || !plan.settings.isValid || _printing) {
      return;
    }
    setState(() => _printing = true);
    try {
      await (widget.printQuestions ?? QuestionPrinter.print)(plan, gradeTitle);
    } catch (error, stackTrace) {
      debugPrint('Question printing failed: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تعذّرت الطباعة. تأكد من توفر خدمة الطباعة وحاول مرة أخرى.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _printing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final units = printableUnits(state.visibleUnits);
    final settings = _settings;
    final plan = QuestionPrintPlan.fromSelection(
      units,
      _selectedIds,
      settings: settings ?? const QuestionPrintSettings(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة أسئلة الامتحان'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                _PrintIntro(gradeTitle: state.gradeTitle),
                const SizedBox(height: AppSpacing.xl),
                if (units.isEmpty)
                  const EmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'لا توجد أسئلة للطباعة',
                    message: 'لا توجد وحدات تحتوي على أسئلة في هذا الصف.',
                  )
                else ...<Widget>[
                  SectionHeader(
                    title: 'اختر الوحدات',
                    subtitle: 'حدد وحدة واحدة أو أكثر، أو اطبع جميع الوحدات.',
                    accent: scheme.secondary,
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: _printing || plan.units.length == units.length
                            ? null
                            : () => setState(() {
                                _selectedIds = units.map((unit) => unit.id).toSet();
                              }),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('تحديد الكل'),
                      ),
                      TextButton(
                        onPressed: _printing || plan.isEmpty
                            ? null
                            : () => setState(_selectedIds.clear),
                        child: const Text('إلغاء التحديد'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      children: <Widget>[
                        for (var i = 0; i < units.length; i++) ...<Widget>[
                          if (i > 0) const Divider(height: 1),
                          CheckboxListTile(
                            key: ValueKey<String>('print-unit-${units[i].id}'),
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(units[i].title, style: theme.textTheme.titleMedium),
                            subtitle: Text(
                              '${toArabicDigits('${units[i].questions.length}')} سؤالاً',
                              style: theme.textTheme.labelMedium,
                            ),
                            value: _selectedIds.contains(units[i].id),
                            onChanged: _printing
                                ? null
                                : (bool? value) => setState(() {
                                    if (value == true) {
                                      _selectedIds.add(units[i].id);
                                    } else {
                                      _selectedIds.remove(units[i].id);
                                    }
                                  }),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'إعدادات الطباعة',
                    subtitle: 'تؤثر هذه الإعدادات على الورقة فقط، لا على خط التطبيق.',
                    accent: scheme.primary,
                  ),
                  _PrintSettings(
                    font: _font,
                    bodySize: _bodySize,
                    headingSize: _headingSize,
                    enabled: !_printing,
                    onFontChanged: (font) => setState(() => _font = font),
                    onSizeChanged: () => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _PrintBar(
        plan: plan,
        printing: _printing,
        settingsValid: settings != null,
        onPrint: () {
          // Capture both the current selection and validated typography for the
          // entire print operation, even if application state changes later.
          final currentSettings = _settings;
          if (currentSettings != null) {
            final currentPlan = QuestionPrintPlan.fromSelection(
              units,
              _selectedIds,
              settings: currentSettings,
            );
            _print(currentPlan, state.gradeTitle);
          }
        },
      ),
    );
  }
}

class _PrintIntro extends StatelessWidget {
  const _PrintIntro({required this.gradeTitle});

  final String gradeTitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.secondary.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.print_outlined, color: scheme.secondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('أسئلة الامتحان — $gradeTitle', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'تُطبع الأسئلة مع إجاباتها: الصح والخطأ، ثم الاختيارات، ثم التعداد، دون أسماء الوحدات.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'اختر A4 في إعدادات الطابعة. عند امتلاء الورقة تستكمل الأسئلة على صفحات إضافية دون تصغير الخط.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Accept Western, Arabic-Indic, and Eastern Arabic-Indic digits from either
/// mobile or desktop keyboards without depending on the current locale.
int? _parseFontSize(String text) => parseIntegerDigits(text);

class _PrintSettings extends StatelessWidget {
  const _PrintSettings({
    required this.font,
    required this.bodySize,
    required this.headingSize,
    required this.enabled,
    required this.onFontChanged,
    required this.onSizeChanged,
  });

  final QuestionPrintFont font;
  final TextEditingController bodySize;
  final TextEditingController headingSize;
  final bool enabled;
  final ValueChanged<QuestionPrintFont> onFontChanged;
  final VoidCallback onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = _FontSizeField(
      fieldKey: const ValueKey<String>('print-body-size'),
      label: 'حجم خط المحتوى',
      controller: bodySize,
      enabled: enabled,
      onChanged: onSizeChanged,
    );
    final heading = _FontSizeField(
      fieldKey: const ValueKey<String>('print-heading-size'),
      label: 'حجم خط العناوين',
      controller: headingSize,
      enabled: enabled,
      onChanged: onSizeChanged,
    );
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
          DropdownButtonFormField<QuestionPrintFont>(
            key: const ValueKey<String>('print-font'),
            initialValue: font,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'نوع الخط', border: OutlineInputBorder()),
            items: <DropdownMenuItem<QuestionPrintFont>>[
              for (final choice in QuestionPrintFont.values)
                DropdownMenuItem<QuestionPrintFont>(
                  value: choice,
                  child: Text(choice.label, style: TextStyle(fontFamily: choice.family)),
                ),
            ],
            onChanged: enabled
                ? (choice) {
                    if (choice != null) onFontChanged(choice);
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 520) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(child: body),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(child: heading),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  body,
                  const SizedBox(height: AppSpacing.md),
                  heading,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FontSizeField extends StatelessWidget {
  const _FontSizeField({
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final valid = QuestionPrintSettings.isValidFontSize(_parseFontSize(controller.text));
    final range =
        '${toArabicDigits('${QuestionPrintSettings.minFontSize}')}–'
        '${toArabicDigits('${QuestionPrintSettings.maxFontSize}')}';
    return TextField(
      key: fieldKey,
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      textDirection: TextDirection.ltr,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]')),
        LengthLimitingTextInputFormatter(QuestionPrintSettings.maxFontSize.toString().length),
      ],
      decoration: InputDecoration(
        labelText: label,
        helperText: 'بالنقاط ($range)',
        errorText: valid ? null : 'أدخل حجماً من $range نقطة',
        errorMaxLines: 2,
        border: const OutlineInputBorder(),
      ),
      onChanged: (_) => onChanged(),
    );
  }
}

class _PrintBar extends StatelessWidget {
  const _PrintBar({
    required this.plan,
    required this.printing,
    required this.settingsValid,
    required this.onPrint,
  });

  final QuestionPrintPlan plan;
  final bool printing;
  final bool settingsValid;
  final VoidCallback onPrint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.readingMaxWidth),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      plan.isEmpty
                          ? 'اختر وحدة للطباعة'
                          : !settingsValid
                          ? 'أدخل أحجام خط صحيحة'
                          : '${toArabicDigits('${plan.units.length}')} وحدة • '
                                '${toArabicDigits('${plan.questionCount}')} سؤالاً',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey<String>('print-questions-button'),
                    onPressed: plan.isEmpty || printing || !settingsValid ? null : onPrint,
                    icon: printing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.print_outlined, size: 20),
                    label: Text(printing ? 'جاري التحضير' : 'طباعة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
