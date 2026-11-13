import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/meta_pill.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/illustration_figure.dart';

/// Lesson plan reader with a tab per session (theory / practice).
class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final lesson = state.library.lessonById(widget.lessonId);
    if (lesson == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('الدرس غير موجود')));
    }
    _tabController ??= TabController(length: lesson.plans.length, vsync: this);
    final accent = AppColors.fromAccent(lesson.accent, theme.brightness == Brightness.dark);
    final isFavorite = state.isFavorite(lesson.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(lesson.title, style: theme.textTheme.titleLarge),
        actions: <Widget>[
          IconButton(
            tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
            onPressed: () => state.toggleFavorite(lesson.id),
            icon: Icon(isFavorite ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: accent,
          indicatorColor: accent,
          tabs: lesson.plans
              .map((LessonSession plan) => Tab(text: plan.label))
              .toList(growable: false),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: lesson.plans
            .map(
              (LessonSession plan) => ListView(
                padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
                children: <Widget>[
                  AppPage(
                    maxWidth: AppLayout.readingMaxWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.lg),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: <Widget>[
                            MetaPill(
                              label: plan.isTheory ? 'حصة نظرية' : 'حصة عملية',
                              icon: plan.isTheory ? Icons.menu_book_outlined : Icons.brush_outlined,
                              color: accent,
                              filled: true,
                            ),
                            MetaPill(label: lesson.title, color: theme.colorScheme.secondary),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(plan.subject, style: theme.textTheme.displayMedium?.copyWith(fontSize: 28)),
                        if (lesson.figures.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppSpacing.lg),
                          IllustrationFigure(
                            figure: lesson.figures.first,
                            accent: accent,
                            height: 220,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                        _PlanField(
                          title: 'الموضوع',
                          icon: Icons.label_outline,
                          accent: accent,
                          child: Text(plan.subject, style: theme.textTheme.bodyLarge),
                        ),
                        _PlanField(
                          title: 'الأهداف العامة',
                          icon: Icons.flag_outlined,
                          accent: accent,
                          child: Text(plan.generalAims, style: theme.textTheme.bodyLarge),
                        ),
                        _PlanField(
                          title: 'الأهداف الخاصة',
                          icon: Icons.checklist_outlined,
                          accent: accent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: plan.specificAims
                                .map((String aim) => Padding(
                                      padding: const EdgeInsets.only(bottom: 6),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Padding(
                                            padding: const EdgeInsets.only(top: 6, left: 4, right: 8),
                                            child: Icon(Icons.check_circle_outline, size: 16, color: accent),
                                          ),
                                          Expanded(
                                            child: Text(aim, style: theme.textTheme.bodyLarge),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(growable: false),
                          ),
                        ),
                        _PlanField(
                          title: 'الوسائل التعليمية',
                          icon: Icons.handyman_outlined,
                          accent: accent,
                          child: Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: plan.media
                                .split(RegExp(r'[–-]'))
                                .map((String item) => item.trim())
                                .where((String item) => item.isNotEmpty)
                                .map((String item) => Chip(label: Text(item)))
                                .toList(growable: false),
                          ),
                        ),
                        _PlanField(
                          title: 'المقدمة',
                          icon: Icons.play_circle_outline,
                          accent: accent,
                          child: Text(plan.introduction, style: theme.textTheme.bodyLarge),
                        ),
                        _PlanField(
                          title: 'العرض',
                          icon: Icons.article_outlined,
                          accent: accent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: plan.body
                                .map((LessonBlock block) => _BodyBlock(block: block, accent: accent))
                                .toList(growable: false),
                          ),
                        ),
                        if (plan.homework.isNotEmpty)
                          _PlanField(
                            title: 'واجب بيتي',
                            icon: Icons.home_work_outlined,
                            accent: theme.colorScheme.tertiary,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: plan.homework
                                  .map((String item) => Text(item, style: theme.textTheme.bodyLarge))
                                  .toList(growable: false),
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ],
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _PlanField extends StatelessWidget {
  const _PlanField({
    required this.title,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
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
            children: <Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.titleMedium?.copyWith(color: accent)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _BodyBlock extends StatelessWidget {
  const _BodyBlock({required this.block, required this.accent});

  final LessonBlock block;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    switch (block.kind) {
      case LessonBlockKind.heading:
        return Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
          child: Row(
            children: <Widget>[
              Container(width: 4, height: 18, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(block.text, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
        );
      case LessonBlockKind.bullet:
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 9, left: 2, right: 8),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: Text(block.text, style: theme.textTheme.bodyLarge)),
            ],
          ),
        );
      case LessonBlockKind.paragraph:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(block.text, style: theme.textTheme.bodyLarge),
        );
    }
  }
}
