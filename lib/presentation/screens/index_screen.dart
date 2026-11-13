import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/meta_pill.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import 'landing_shell.dart';

enum _IndexFilter { all, unread, favorites }

/// The interactive table of contents: every unit, grouped by section, with
/// reading state, numbering, filtering and direct navigation.
class IndexScreen extends StatefulWidget {
  const IndexScreen({super.key});

  @override
  State<IndexScreen> createState() => _IndexScreenState();
}

class _IndexScreenState extends State<IndexScreen> {
  _IndexFilter _filter = _IndexFilter.all;
  String _query = '';

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
            title: 'الفهرس',
            subtitle: 'اثنتا عشرة وحدة دراسية، ودروس تطبيقية، ولوحات مصوّرة',
            actions: <Widget>[
              IconButton(
                tooltip: 'بحث',
                onPressed: () => AppRoutes.openSearch(context),
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  textInputAction: TextInputAction.search,
                  onChanged: (String value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم الوحدة أو الموضوع…',
                    prefixIcon: Icon(Icons.filter_list),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    _FilterChip(
                      label: 'الكل',
                      selected: _filter == _IndexFilter.all,
                      onSelected: () => setState(() => _filter = _IndexFilter.all),
                    ),
                    _FilterChip(
                      label: 'غير مقروء',
                      selected: _filter == _IndexFilter.unread,
                      onSelected: () => setState(() => _filter = _IndexFilter.unread),
                    ),
                    _FilterChip(
                      label: 'المفضلة',
                      selected: _filter == _IndexFilter.favorites,
                      onSelected: () => setState(() => _filter = _IndexFilter.favorites),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                ...state.visibleSections.map(
                  (ContentSection section) => _SectionBlock(
                    section: section,
                    state: state,
                    filter: _filter,
                    query: _query,
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({
    required this.section,
    required this.state,
    required this.filter,
    required this.query,
  });

  final ContentSection section;
  final AppState state;
  final _IndexFilter filter;
  final String query;

  @override
  Widget build(BuildContext context) {
    if (section.kind == 'lessons') {
      return _ExtraSection(
        title: section.title,
        subtitle: section.subtitle,
        icon: Icons.edit_note_outlined,
        entries: state.library.lessons
            .map((LessonPlan lesson) => _ExtraEntry(
                  title: lesson.title,
                  subtitle: lesson.summary,
                  onTap: () => AppRoutes.openLesson(context, lesson),
                  isFavorite: state.isFavorite(lesson.id),
                  onFavorite: () => state.toggleFavorite(lesson.id),
                ))
            .toList(growable: false),
        matchesQuery: query,
        filter: filter,
      );
    }
    if (section.kind == 'plates') {
      return _ExtraSection(
        title: section.title,
        subtitle: section.subtitle,
        icon: Icons.image_outlined,
        entries: state.visiblePlates
            .map((Plate plate) => _ExtraEntry(
                  title: plate.title,
                  subtitle: '${plate.grade} — ${plate.caption}',
                  onTap: () => AppRoutes.openPlate(context, plate),
                ))
            .toList(growable: false),
        matchesQuery: query,
        filter: filter,
      );
    }

    final units = state.library.unitsOf(section.id).where((LearningUnit unit) {
      if (filter == _IndexFilter.unread && state.isRead(unit.id)) {
        return false;
      }
      if (filter == _IndexFilter.favorites && !state.isFavorite(unit.id)) {
        return false;
      }
      if (query.trim().isNotEmpty) {
        final needle = normalizeArabic(query.trim());
        return normalizeArabic('${unit.title} ${unit.searchableText}').contains(needle);
      }
      return true;
    }).toList(growable: false);

    if (units.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SectionHeader(title: section.title, subtitle: section.subtitle),
            const SizedBox(height: AppSpacing.sm),
            EmptyState(
              icon: Icons.filter_alt_off_outlined,
              title: 'لا توجد وحدات مطابقة',
              message: 'جرّب تغيير عامل التصفية أو كلمة البحث.',
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: section.title,
            subtitle: section.kind == 'grade'
                ? '${toArabicDigits('${state.sectionReadCount(section.id)}')} من ${toArabicDigits('${units.length}')} مقروءة'
                : section.subtitle,
          ),
          ...units.map(
            (LearningUnit unit) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _UnitTile(unit: unit, state: state),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.unit, required this.state});

  final LearningUnit unit;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = _accent(theme, unit.accent);
    final isRead = state.isRead(unit.id);
    final isFavorite = state.isFavorite(unit.id);
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: () => AppRoutes.openUnit(context, unit),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(
              color: isRead ? accent.withValues(alpha: 0.45) : scheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isRead
                    ? Icon(Icons.check_rounded, color: accent, size: 22)
                    : Text(
                        unit.isIntroduction ? 'م' : toArabicDigits('${unit.order}'),
                        style: theme.textTheme.titleLarge?.copyWith(color: accent),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      unit.isIntroduction ? unit.title : '${unit.numberLabel}: ${unit.displayTitle}',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      unit.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        MetaPill(label: '${toArabicDigits('${unit.topics.length}')} موضوعاً', color: accent),
                        if (unit.questions.isNotEmpty)
                          MetaPill(
                            label: '${toArabicDigits('${unit.questions.length}')} سؤالاً',
                            color: scheme.secondary,
                          ),
                        MetaPill(label: unit.template.label, color: scheme.tertiary),
                        if (isRead) MetaPill(label: 'مقروءة', icon: Icons.done_all, color: accent),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: isFavorite ? 'إزالة من المفضلة' : 'إضافة إلى المفضلة',
                onPressed: () => state.toggleFavorite(unit.id),
                icon: Icon(
                  isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  color: isFavorite ? accent : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraEntry {
  const _ExtraEntry({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFavorite = false,
    this.onFavorite,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback? onFavorite;
}

class _ExtraSection extends StatelessWidget {
  const _ExtraSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.entries,
    required this.matchesQuery,
    required this.filter,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<_ExtraEntry> entries;
  final String matchesQuery;
  final _IndexFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final needle = normalizeArabic(matchesQuery.trim());
    final visible = entries.where((_ExtraEntry entry) {
      if (filter == _IndexFilter.unread) {
        return false;
      }
      if (filter == _IndexFilter.favorites && !entry.isFavorite) {
        return false;
      }
      if (needle.isEmpty) {
        return true;
      }
      return normalizeArabic('${entry.title} ${entry.subtitle}').contains(needle);
    }).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SectionHeader(
            title: title,
            subtitle: subtitle,
            accent: scheme.tertiary,
          ),
          if (visible.isEmpty)
            Text(
              filter == _IndexFilter.unread
                  ? 'هذا القسم لا يحتوي على وحدات تُتابع حالتها.'
                  : 'لا توجد نتائج في هذا القسم.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ...visible.map(
              (_ExtraEntry entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Material(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: entry.onTap,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: scheme.tertiary.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(icon, size: 20, color: scheme.tertiary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(entry.title, style: theme.textTheme.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  entry.subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                          if (entry.onFavorite != null)
                            IconButton(
                              onPressed: entry.onFavorite,
                              icon: Icon(
                                entry.isFavorite ? Icons.bookmark : Icons.bookmark_border,
                                color: entry.isFavorite ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                          Icon(Icons.chevron_left, color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _accent(ThemeData theme, String accent) {
  switch (accent) {
    case 'secondary':
      return theme.colorScheme.secondary;
    case 'gold':
      return theme.colorScheme.tertiary;
    case 'green':
      return const Color(0xFF4E7C59);
    case 'ink':
      return theme.colorScheme.onSurfaceVariant;
    case 'primary':
    default:
      return theme.colorScheme.primary;
  }
}
