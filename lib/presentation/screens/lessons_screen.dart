import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/meta_pill.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// Index of the practical lesson plans (theory + practice for each topic).
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final lessons = state.library.lessons;
    return Scaffold(
      appBar: AppBar(
        title: const Text('دروس تطبيقية'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'خطط الدروس الأسبوعية كما وردت في ملفات المنهج: الأهداف العامة والخاصة، '
                  'الوسائل التعليمية، المقدمة، العرض، والواجب البيتي — لكل درس حصة نظرية وأخرى عملية.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...lessons.map(
                  (LessonPlan lesson) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Material(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        onTap: () => AppRoutes.openLesson(context, lesson),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(lesson.title, style: theme.textTheme.headlineMedium),
                                  ),
                                  IconButton(
                                    tooltip: 'حفظ في المفضلة',
                                    onPressed: () => state.toggleFavorite(lesson.id),
                                    icon: Icon(
                                      state.isFavorite(lesson.id) ? Icons.bookmark : Icons.bookmark_border,
                                      color: state.isFavorite(lesson.id)
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(lesson.summary, style: theme.textTheme.bodyMedium),
                              const SizedBox(height: AppSpacing.md),
                              Wrap(
                                spacing: AppSpacing.sm,
                                runSpacing: AppSpacing.sm,
                                children: lesson.plans
                                    .map((LessonSession plan) => MetaPill(
                                          label: plan.label,
                                          icon: plan.isTheory ? Icons.menu_book_outlined : Icons.brush_outlined,
                                          color: plan.isTheory ? scheme.secondary : scheme.tertiary,
                                        ))
                                    .toList(growable: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
