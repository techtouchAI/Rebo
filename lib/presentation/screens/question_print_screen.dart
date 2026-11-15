import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../data/local/question_pdf.dart';
import '../../domain/models/library.dart';
import '../../domain/services/question_print_plan.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// The optional callback makes the platform print operation replaceable in UI
/// tests; production uses [QuestionPrinter].
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

  Future<void> _print(QuestionPrintPlan plan, String gradeTitle) async {
    if (plan.isEmpty || _printing) {
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
    final plan = QuestionPrintPlan.fromSelection(units, _selectedIds);

    return Scaffold(
      appBar: AppBar(
        title: const Text('طباعة الأسئلة'),
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
                    title: 'أسئلة الوحدات',
                    subtitle: 'تُعرض هنا حسب الوحدة؛ وتُجمع في الطباعة حسب نوع السؤال.',
                    accent: scheme.primary,
                  ),
                  for (final unit in units)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _UnitQuestions(
                        key: ValueKey<String>('preview-unit-${unit.id}'),
                        unit: unit,
                        selected: _selectedIds.contains(unit.id),
                      ),
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
        onPrint: () => _print(plan, state.gradeTitle),
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
                Text('أسئلة $gradeTitle', style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'الأسئلة فقط دون الإجابات. في الورقة: الصح والخطأ، ثم الاختيارات، ثم التعداد.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'ورق A4 • خط ١٢ • العناوين ١٤',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.secondary),
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

class _UnitQuestions extends StatelessWidget {
  const _UnitQuestions({super.key, required this.unit, required this.selected});

  final LearningUnit unit;
  final bool selected;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: Text(unit.title, style: theme.textTheme.titleLarge)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                selected ? 'محددة' : 'غير محددة',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: selected ? scheme.secondary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          for (final kind in printableQuestionKinds) _UnitQuestionKind(unit: unit, kind: kind),
        ],
      ),
    );
  }
}

class _UnitQuestionKind extends StatelessWidget {
  const _UnitQuestionKind({required this.unit, required this.kind});

  final LearningUnit unit;
  final QuestionKind kind;

  @override
  Widget build(BuildContext context) {
    final questions = questionsOfKind(unit, kind);
    if (questions.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(kind.printHeading, style: theme.textTheme.titleMedium),
        for (var i = 0; i < questions.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              formatPrintableQuestion(questions[i], i + 1),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                height: 1.6,
              ),
            ),
          ),
      ],
    );
  }
}

class _PrintBar extends StatelessWidget {
  const _PrintBar({required this.plan, required this.printing, required this.onPrint});

  final QuestionPrintPlan plan;
  final bool printing;
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
                          : '${toArabicDigits('${plan.units.length}')} وحدة • '
                              '${toArabicDigits('${plan.questionCount}')} سؤالاً',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    key: const ValueKey<String>('print-questions-button'),
                    onPressed: plan.isEmpty || printing ? null : onPrint,
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
