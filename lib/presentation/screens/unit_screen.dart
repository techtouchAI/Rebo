import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/meta_pill.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/illustration_figure.dart';
import '../widgets/units/unit_sections.dart';

/// Reader of a single curriculum unit.
class UnitScreen extends StatefulWidget {
  const UnitScreen({super.key, required this.unitId});

  final String unitId;

  @override
  State<UnitScreen> createState() => _UnitScreenState();
}

class _UnitScreenState extends State<UnitScreen> {
  ScrollController? _controller;
  AppState? _state;
  bool _initialised = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialised) {
      return;
    }
    _initialised = true;
    _state = AppScope.read(context);
    final offset = _state!.scrollOffsetOf(widget.unitId);
    _controller = ScrollController(initialScrollOffset: offset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = _state;
      if (state != null && mounted) {
        state.markRead(widget.unitId);
      }
    });
  }

  @override
  void dispose() {
    final controller = _controller;
    final state = _state;
    if (controller != null && state != null && controller.hasClients) {
      state.saveScrollOffset(widget.unitId, controller.offset);
    }
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final unit = state.library.unitById(widget.unitId);
    if (unit == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('وحدة غير موجودة')),
        body: const Center(child: Text('تعذّر العثور على هذه الوحدة في المحتوى.')),
      );
    }
    final theme = Theme.of(context);
    final accent = AppColors.fromAccent(unit.accent, theme.brightness == Brightness.dark);
    final order = state.library.readingOrder;
    final position = order.indexOf(unit.id);
    final previous = position > 0 ? state.library.unitById(order[position - 1]) : null;
    final next = position >= 0 && position < order.length - 1
        ? state.library.unitById(order[position + 1])
        : null;
    final isFavorite = state.isFavorite(unit.id);
    final terms = unit.glossaryIds
        .map(state.library.termById)
        .whereType<GlossaryTerm>()
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(unit.displayTitle, style: theme.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            onPressed: () => state.toggleFavorite(unit.id),
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
          ),
          IconButton(
            tooltip: 'نسخ نص الوحدة للمشاركة',
            onPressed: () => _copyUnit(state, unit),
            icon: const Icon(Icons.ios_share),
          ),
          PopupMenuButton<String>(
            tooltip: 'خيارات',
            onSelected: (String value) {
              if (value == 'quiz' && unit.questions.isNotEmpty) {
                AppRoutes.openQuiz(context, unit);
              } else if (value == 'glossary') {
                AppRoutes.openGlossary(context);
              } else if (value == 'toggle_read') {
                state.markRead(unit.id, read: !state.isRead(unit.id));
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (unit.questions.isNotEmpty)
                const PopupMenuItem<String>(value: 'quiz', child: Text('اختبر فهمك')),
              const PopupMenuItem<String>(value: 'glossary', child: Text('المصطلحات الفنية')),
              PopupMenuItem<String>(
                value: 'toggle_read',
                child: Text(state.isRead(unit.id) ? 'تعليم كغير مقروءة' : 'تعليم كمقروءة'),
              ),
            ],
          ),
        ],
      ),
      body: PatternFreeScroll(
        child: ListView(
          controller: _controller,
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[
            AppPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _UnitHeader(unit: unit, accent: accent),
                  const SizedBox(height: AppSpacing.xl),
                  if (unit.figures.isNotEmpty) ...<Widget>[
                    SectionHeader(
                      title: 'رسوم توضيحية',
                      subtitle: 'تكوينات بصرية مرتبطة بموضوعات الوحدة',
                      accent: accent,
                    ),
                    ...unit.figures.map(
                      (Figure figure) => Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: IllustrationFigure(figure: figure, accent: accent),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  SectionHeader(
                    title: 'موضوعات الوحدة',
                    subtitle: '${toArabicDigits('${unit.topics.length}')} موضوعاً — ${unit.template.label}',
                    accent: accent,
                  ),
                  UnitSections(unit: unit, accent: accent),
                  if (unit.plate != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'لوحة من دليل المعلم',
                      accent: AppColors.ochre,
                    ),
                    _PlateCard(unit: unit),
                  ],
                  if (terms.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    SectionHeader(
                      title: 'مصطلحات الوحدة',
                      subtitle: 'تعريفات كما وردت في المصدر',
                      accent: colorsSecondary(context),
                    ),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: terms
                          .map((GlossaryTerm term) => ActionChip(
                                avatar: const Icon(Icons.translate, size: 16),
                                label: Text(term.term),
                                onPressed: () => _showTerm(term),
                              ))
                          .toList(growable: false),
                    ),
                  ],
                  if (unit.questions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    _QuizCallToAction(unit: unit, state: state, accent: accent),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _PrevNextBar(previous: previous, next: next),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color colorsSecondary(BuildContext context) => Theme.of(context).colorScheme.secondary;

  Future<void> _copyUnit(AppState state, LearningUnit unit) async {
    final text = state.shareTextOfUnit(unit);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ نص الوحدة — يمكنك مشاركته الآن')),
    );
  }

  void _showTerm(GlossaryTerm term) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(term.term, style: theme.textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.md),
              Text(term.definition, style: theme.textTheme.bodyLarge),
            ],
          ),
        );
      },
    );
  }
}

/// Wrapper used to keep code readable where no pattern is needed.
class PatternFreeScroll extends StatelessWidget {
  const PatternFreeScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _UnitHeader extends StatelessWidget {
  const _UnitHeader({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.04),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              MetaPill(label: unit.isIntroduction ? 'مدخل' : unit.grade, color: accent, filled: true),
              MetaPill(label: unit.numberLabel, color: scheme.secondary),
              MetaPill(label: unit.template.label, icon: Icons.dashboard_customize_outlined, color: scheme.tertiary),
              MetaPill(
                label: readingTimeLabel(unit.searchableText),
                icon: Icons.schedule,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            unit.isIntroduction ? unit.title : '${unit.numberLabel}: ${unit.displayTitle}',
            style: theme.textTheme.displayMedium?.copyWith(fontSize: 30),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            unit.summary,
            style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PlateCard extends StatelessWidget {
  const _PlateCard({required this.unit});

  final LearningUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plate = unit.plate!;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final plates = AppScope.read(context).library.plates;
          final match = plates.where((Plate item) => item.asset == plate.asset);
          if (match.isNotEmpty) {
            AppRoutes.openPlate(context, match.first);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Image.asset(
                  plate.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(plate.caption, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(plate.source, style: theme.textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizCallToAction extends StatelessWidget {
  const _QuizCallToAction({required this.unit, required this.state, required this.accent});

  final LearningUnit unit;
  final AppState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = state.quizScoreOf(unit.id);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.quiz_outlined, color: accent, size: 30),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('اختبر فهمك', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  '${toArabicDigits('${unit.questions.length}')} سؤالاً من أسئلة الوحدة في المصدر'
                  '${score == null ? '' : ' — أفضل نتيجة: ${toArabicDigits('$score')}'}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton(
            onPressed: () => AppRoutes.openQuiz(context, unit),
            child: const Text('ابدأ'),
          ),
        ],
      ),
    );
  }
}

class _PrevNextBar extends StatelessWidget {
  const _PrevNextBar({this.previous, this.next});

  final LearningUnit? previous;
  final LearningUnit? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        if (previous != null)
          Expanded(
            child: _NavCard(
              label: 'الوحدة السابقة',
              title: previous!.displayTitle,
              icon: Icons.arrow_forward,
              onTap: () => _replaceWith(context, previous!),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSpacing.md),
        if (next != null)
          Expanded(
            child: _NavCard(
              label: 'الوحدة التالية',
              title: next!.displayTitle,
              icon: Icons.arrow_back,
              alignEnd: true,
              onTap: () => _replaceWith(context, next!),
            ),
          )
        else
          const Spacer(),
        if (previous == null && next == null)
          Text('آخر عنصر', style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }

  void _replaceWith(BuildContext context, LearningUnit unit) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (BuildContext context) => UnitScreen(unitId: unit.id)),
    );
  }
}

class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.label,
    required this.title,
    required this.icon,
    required this.onTap,
    this.alignEnd = false,
  });

  final String label;
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            textDirection: alignEnd ? TextDirection.rtl : TextDirection.ltr,
            children: <Widget>[
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(label, style: theme.textTheme.labelMedium),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
