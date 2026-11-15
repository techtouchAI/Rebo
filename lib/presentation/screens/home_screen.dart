import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/equal_columns_grid.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import 'grade_picker_screen.dart';
import 'landing_shell.dart';

/// Landing page: progress, continue-reading, figures, sections and shortcuts.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final library = state.library;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPageHeader(
            title: 'مِرسم',
            subtitle: 'التربية الفنية • ${state.gradeTitle}',
            showBrand: true,
            actions: <Widget>[
              IconButton(
                tooltip: 'تغيير الصف',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const GradePickerScreen()),
                ),
                icon: const Icon(Icons.school_outlined),
              ),
              IconButton(
                tooltip: 'بحث',
                onPressed: () => AppRoutes.openSearch(context),
                icon: const Icon(Icons.search),
              ),
              IconButton(
                tooltip: state.themeMode == ThemeMode.light ? 'الوضع الليلي' : 'الوضع النهاري',
                onPressed: () {
                  final next = Theme.of(context).brightness == Brightness.dark
                      ? AppThemeMode.light
                      : AppThemeMode.dark;
                  state.setThemeMode(next);
                },
                icon: Icon(
                  Theme.of(context).brightness == Brightness.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ],
          ),
          AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const _ProgressPanel(),
                const SizedBox(height: AppSpacing.xl),
                if (state.lastReadUnit != null) ...<Widget>[
                  _ContinueCard(unit: state.lastReadUnit!),
                  const SizedBox(height: AppSpacing.xl),
                ],
                _StatsRow(state: state),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'أقسام التطبيق',
                  subtitle: 'مداخل منظّمة للمعرفة الفنية',
                  accent: Theme.of(context).colorScheme.secondary,
                ),
                _SectionsGrid(state: state),
                const SizedBox(height: AppSpacing.xl),
                SectionHeader(
                  title: 'اختصارات',
                  accent: Theme.of(context).colorScheme.tertiary,
                ),
                _ShortcutsRow(state: state),
                const SizedBox(height: AppSpacing.xl),
                _FooterNote(library: library),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reading progress of the chosen grade, with a shortcut to the plates.
class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final percent = (state.overallProgress * 100).round();

    final progress = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ProgressRing(
          value: state.overallProgress,
          label: '$percent٪',
          color: scheme.primary,
          trackColor: scheme.outlineVariant,
          size: 68,
        ),
        const SizedBox(width: AppSpacing.md),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('تقدّمك في الاستكشاف', style: theme.textTheme.labelLarge),
              const SizedBox(height: 2),
              Text(
                '${toArabicDigits('${state.readUnitsCount}')} / ${toArabicDigits('${state.totalUnits}')} وحدة',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.lg,
        runSpacing: AppSpacing.md,
        children: <Widget>[
          progress,
          OutlinedButton.icon(
            onPressed: () => AppRoutes.openPlates(context),
            icon: const Icon(Icons.image_outlined, size: 18),
            label: const Text('اللوحات'),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.unit});

  final LearningUnit unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppColors.fromAccent(unit.accent, theme.brightness == Brightness.dark);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => AppRoutes.openUnit(context, unit),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.play_arrow_rounded, color: accent, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('تابع من حيث توقفت', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(unit.title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      '${unit.grade} • ${readingTimeLabel(unit.searchableText)}',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final units = state.visibleUnits;
    final totalTopics = units.fold<int>(0, (int sum, LearningUnit unit) => sum + unit.topics.length);
    final totalQuestions = units.fold<int>(0, (int sum, LearningUnit unit) => sum + unit.questions.length);
    // One-word labels: the four tiles always share a single row.
    final items = <_Stat>[
      _Stat('وحدات', toArabicDigits('${units.length}'), Icons.menu_book_outlined),
      _Stat('موضوعات', toArabicDigits('$totalTopics'), Icons.subject_outlined),
      _Stat('أسئلة', toArabicDigits('$totalQuestions'), Icons.quiz_outlined),
      _Stat('لوحات', toArabicDigits('${state.visiblePlates.length}'), Icons.image_outlined),
    ];
    return EqualColumnsGrid(
      columns: items.length,
      children: items
          .map((_Stat item) => _StatTile(stat: item))
          .toList(growable: false),
    );
  }
}

class _Stat {
  const _Stat(this.label, this.value, this.icon);

  final String label;
  final String value;
  final IconData icon;
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      // The tile is a quarter of the row: its text keeps a fixed size and is
      // fitted to the tile, so the label stays on one line at any text scale.
      child: MediaQuery.withNoTextScaling(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(stat.icon, size: 20, color: scheme.secondary),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(stat.value, maxLines: 1, style: theme.textTheme.titleLarge),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(stat.label, maxLines: 1, style: theme.textTheme.labelMedium),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionsGrid extends StatelessWidget {
  const _SectionsGrid({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final sections = state.visibleSections;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
                ? 2
                : 1;
        final spacing = AppSpacing.md;
        final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: sections.map((ContentSection section) {
            return SizedBox(
              width: itemWidth,
              child: _SectionCard(section: section, state: state),
            );
          }).toList(growable: false),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section, required this.state});

  final ContentSection section;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final accent = switch (section.kind) {
      'intro' => AppColors.fromAccent('secondary', isDark),
      'lessons' => AppColors.fromAccent('green', isDark),
      'plates' => AppColors.fromAccent('gold', isDark),
      _ => AppColors.fromAccent('primary', isDark),
    };
    final count = switch (section.kind) {
      'lessons' => state.library.lessons.length,
      'plates' => state.visiblePlates.length,
      'theatre' => state.theatreUnit?.topics.length ?? 0,
      _ => state.library.unitsOf(section.id).length,
    };
    final progress = section.isGrade ? state.sectionProgress(section.id) : null;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => _openSection(context, section),
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
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_iconFor(section.kind), color: accent, size: 22),
                  ),
                  const Spacer(),
                  Text(
                    '${toArabicDigits('$count')} ${switch (section.kind) {
                      'lessons' => 'دروس',
                      'plates' => 'لوحة',
                      'theatre' => 'موضوعات',
                      _ => 'وحدات',
                    }}',
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(section.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 2),
              Text(section.subtitle, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
              if (progress != null && progress > 0) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: scheme.outlineVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openSection(BuildContext context, ContentSection section) {
    switch (section.kind) {
      case 'lessons':
        AppRoutes.openLessons(context);
        break;
      case 'plates':
        AppRoutes.openPlates(context);
        break;
      case 'theatre':
        final theatre = state.theatreUnit;
        if (theatre != null) {
          AppRoutes.openUnit(context, theatre);
        }
        break;
      default:
        final units = state.library.unitsOf(section.id);
        if (units.isNotEmpty) {
          AppRoutes.openUnit(context, units.first);
        }
    }
  }

  IconData _iconFor(String kind) {
    switch (kind) {
      case 'intro':
        return Icons.auto_stories_outlined;
      case 'theatre':
        return Icons.theater_comedy_outlined;
      case 'lessons':
        return Icons.edit_note_outlined;
      case 'plates':
        return Icons.image_outlined;
      default:
        return Icons.school_outlined;
    }
  }
}

class _ShortcutsRow extends StatelessWidget {
  const _ShortcutsRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final items = <_Shortcut>[
      _Shortcut('المصطلحات الفنية', Icons.translate_outlined, () => AppRoutes.openGlossary(context)),
      _Shortcut('المفضلة', Icons.bookmark_border, () => AppRoutes.openFavorites(context)),
      _Shortcut('دروس تطبيقية', Icons.edit_note_outlined, () => AppRoutes.openLessons(context)),
      _Shortcut('بحث شامل', Icons.search, () => AppRoutes.openSearch(context)),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: items
          .map((_Shortcut item) => OutlinedButton.icon(
                onPressed: item.onTap,
                icon: Icon(item.icon, size: 18),
                label: Text(item.label),
              ))
          .toList(growable: false),
    );
  }
}

class _Shortcut {
  const _Shortcut(this.label, this.icon, this.onTap);

  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'وحدات التربية الفنية للمرحلة المتوسطة ودروسها التطبيقية ولوحاتها ومفردات '
              'الأنشطة المسرحية. يعمل التطبيق دون اتصال بالإنترنت بالكامل بعد التثبيت.',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
