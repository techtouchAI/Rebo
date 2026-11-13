import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import 'landing_shell.dart';
import '../widgets/text_scale_controls.dart';

/// Saved units and lessons.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final units = state.favoriteUnits;
    final lessons = state.favoriteLessons;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (units.isEmpty && lessons.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.xxl),
            child: EmptyState(
              icon: Icons.bookmark_border,
              title: 'لا توجد عناصر محفوظة بعد',
              message: 'اضغط أيقونة الحفظ داخل أي وحدة أو درس لإضافته هنا.',
            ),
          ),
        if (units.isNotEmpty) ...<Widget>[
          SectionHeader(
            title: 'الوحدات المحفوظة',
            subtitle: '${units.length} وحدة',
          ),
          ...units.map(
            (LearningUnit unit) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => AppRoutes.openUnit(context, unit),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(unit.title, style: theme.textTheme.titleMedium),
                              Text(unit.grade, style: theme.textTheme.labelMedium),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'إزالة',
                          onPressed: () => state.toggleFavorite(unit.id),
                          icon: const Icon(Icons.bookmark_remove_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (lessons.isNotEmpty) ...<Widget>[
          SectionHeader(title: 'الدروس المحفوظة', subtitle: '${lessons.length} درس'),
          ...lessons.map(
            (LessonPlan lesson) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  onTap: () => AppRoutes.openLesson(context, lesson),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(Icons.edit_note_outlined, color: theme.colorScheme.tertiary),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(lesson.title, style: theme.textTheme.titleMedium),
                        ),
                        IconButton(
                          tooltip: 'إزالة',
                          onPressed: () => state.toggleFavorite(lesson.id),
                          icon: const Icon(Icons.bookmark_remove_outlined),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );

    if (!embedded) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('المفضلة'),
          actions: const <Widget>[TextScaleControls()],
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[AppPage(child: body)],
        ),
      );
    }
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          const AppPageHeader(title: 'المفضلة', subtitle: 'العناصر التي حفظتها للرجوع السريع'),
          AppPage(child: body),
        ],
      ),
    );
  }
}
