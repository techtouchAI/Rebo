import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../../domain/models/progress.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import 'grade_picker_screen.dart';
import 'landing_shell.dart';

/// Landing page: identity, progress, continue-reading, sections and shortcuts.
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
                const _HeroPanel(),
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

class _HeroPanel extends StatelessWidget {
  const _HeroPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final percent = (state.overallProgress * 100).round();

    final textBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          'لوحة تتكوّن من معرفة ولون',
          style: theme.textTheme.displayMedium?.copyWith(color: Colors.white, fontSize: 30),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'محتوى التربية الفنية للمرحلة المتوسطة: وحدات، موضوعات، أسئلة مراجعة، '
          'خطط دروس، ولوحات من دليل المعلم — كل ذلك دون إنترنت.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 15,
            height: 1.8,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.ink,
              ),
              onPressed: () => AppRoutes.openSearch(context),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('ابحث في المحتوى'),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
              ),
              onPressed: () => AppRoutes.openPlates(context),
              icon: const Icon(Icons.image_outlined, size: 18),
              label: const Text('لوحات الدليل'),
            ),
          ],
        ),
      ],
    );

    final progressBlock = Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ProgressRing(
            value: state.overallProgress,
            label: '$percent٪',
            color: Colors.white,
            trackColor: Colors.white.withValues(alpha: 0.25),
            size: 68,
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'تقدّمك في الاستكشاف',
                  style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  '${toArabicDigits('${state.readUnitsCount}')} / ${toArabicDigits('${state.totalUnits}')} وحدة',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[Color(0xFF1E5F74), Color(0xFF8C3A26)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            left: wide ? -30 : -70,
            bottom: wide ? -40 : -60,
            child: Opacity(
              opacity: 0.24,
              child: SvgPicture.asset(
                'assets/illustrations/studio.svg',
                width: wide ? 300 : 220,
                semanticsLabel: 'أدوات العمل الفني',
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(flex: 3, child: textBlock),
                    const SizedBox(width: AppSpacing.lg),
                    progressBlock,
                  ],
                )
              else ...<Widget>[
                textBlock,
                const SizedBox(height: AppSpacing.lg),
                Align(alignment: AlignmentDirectional.centerStart, child: progressBlock),
              ],
            ],
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
    final units = state.visibleUnits.where((LearningUnit unit) => !unit.isIntroduction).toList(growable: false);
    final totalTopics = units.fold<int>(0, (int sum, LearningUnit unit) => sum + unit.topics.length);
    final totalQuestions = units.fold<int>(0, (int sum, LearningUnit unit) => sum + unit.questions.length);
    final items = <_Stat>[
      _Stat('وحدة دراسية', toArabicDigits('${units.length}'), Icons.menu_book_outlined),
      _Stat('موضوعاً', toArabicDigits('$totalTopics'), Icons.subject_outlined),
      _Stat('سؤال مراجعة', toArabicDigits('$totalQuestions'), Icons.quiz_outlined),
      _Stat('لوحة مصوّرة', toArabicDigits('${state.visiblePlates.length}'), Icons.image_outlined),
    ];
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(stat.icon, size: 20, color: scheme.secondary),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(stat.value, style: theme.textTheme.titleLarge),
              Text(stat.label, style: theme.textTheme.labelMedium),
            ],
          ),
        ],
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
                    '${toArabicDigits('$count')} ${section.kind == 'lessons' ? 'دروس' : section.kind == 'plates' ? 'لوحة' : 'وحدات'}',
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
              'المحتوى مستخرج من ملف «ملخص التربية الفنية» وخطط الدروس ولوحات دليل معلم '
              'التربية الفنية للمرحلة المتوسطة. يعمل التطبيق offline بالكامل، ولا يحتاج إلى اتصال '
              'بالإنترنت بعد التثبيت.',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
