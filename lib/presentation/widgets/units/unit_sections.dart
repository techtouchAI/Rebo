import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../domain/models/library.dart';
import '../topic_card.dart';

/// Renders the body of a unit with a layout that follows the nature of its
/// content. Every topic is always rendered; the template only changes the way
/// the information is arranged on screen.
class UnitSections extends StatelessWidget {
  const UnitSections({
    super.key,
    required this.unit,
    required this.accent,
  });

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    switch (unit.template) {
      case PresentationTemplate.comparison:
        return _ComparisonSections(unit: unit, accent: accent);
      case PresentationTemplate.materials:
        return _MaterialsSections(unit: unit, accent: accent);
      case PresentationTemplate.process:
        return _ProcessSections(unit: unit, accent: accent);
      case PresentationTemplate.timeline:
        return _TimelineSections(unit: unit, accent: accent);
      case PresentationTemplate.concept:
      case PresentationTemplate.lesson:
        return _ConceptSections(unit: unit, accent: accent);
    }
  }
}

// ------------------------------------------------------------------ concept --

class _ConceptSections extends StatelessWidget {
  const _ConceptSections({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final topics = unit.topics;
    if (topics.isEmpty) {
      return const SizedBox.shrink();
    }
    final first = topics.first;
    final rest = topics.skip(1).toList(growable: false);
    final hasDefinition = first.bullets.isNotEmpty && !first.isProse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (hasDefinition)
          _DefinitionPanel(
            title: first.title,
            definition: first.bullets.first,
            notes: first.bullets.skip(1).toList(growable: false),
            listTitle: first.listTitle,
            listItems: first.listItems,
            accent: accent,
          )
        else
          TopicCard(topic: first, accent: accent),
        const SizedBox(height: AppSpacing.lg),
        ...rest.map(
          (Topic topic) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: TopicCard(topic: topic, accent: accent),
          ),
        ),
      ],
    );
  }
}

class _DefinitionPanel extends StatelessWidget {
  const _DefinitionPanel({
    required this.title,
    required this.definition,
    required this.notes,
    required this.accent,
    this.listTitle,
    this.listItems = const <String>[],
  });

  final String title;
  final String definition;
  final List<String> notes;
  final Color accent;
  final String? listTitle;
  final List<String> listItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: <Color>[
            accent.withValues(alpha: 0.14),
            accent.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(iconForTopic(title), size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title, style: theme.textTheme.headlineMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text('مفهوم أساسي', style: theme.textTheme.labelMedium),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            definition,
            style: theme.textTheme.titleLarge?.copyWith(
              height: 1.75,
              fontSize: 19,
            ),
          ),
          if (notes.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            ...notes.map(
              (String note) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 2, right: 8),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                      ),
                    ),
                    Expanded(child: Text(note, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            ),
          ],
          if (listItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final item in listItems)
                  Chip(label: Text(item), visualDensity: VisualDensity.compact),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- comparison --

class _ComparisonSections extends StatelessWidget {
  const _ComparisonSections({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ...unit.topics.map((Topic topic) {
          final rows = _labelValueRows(topic.bullets);
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: rows.length >= 2
                ? _ComparisonTable(
                    title: topic.title,
                    rows: rows,
                    accent: accent,
                    footnote: topic.listTitle,
                    footItems: topic.listItems,
                  )
                : TopicCard(topic: topic, accent: accent),
          );
        }),
      ],
    );
  }
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({
    required this.title,
    required this.rows,
    required this.accent,
    this.footnote,
    this.footItems = const <String>[],
  });

  final String title;
  final List<_KeyValue> rows;
  final Color accent;
  final String? footnote;
  final List<String> footItems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            color: accent.withValues(alpha: 0.10),
            child: Row(
              children: <Widget>[
                Icon(iconForTopic(title), size: 18, color: accent),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                Text('مقارنة', style: theme.textTheme.labelMedium?.copyWith(color: accent)),
              ],
            ),
          ),
          ...rows.map(
            (_KeyValue row) => Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: scheme.outlineVariant)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 150,
                    child: Text(
                      row.key,
                      style: theme.textTheme.titleMedium?.copyWith(color: accent),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(row.value, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
          if (footItems.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: scheme.surfaceContainerHighest,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (footnote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(footnote!, style: theme.textTheme.labelLarge),
                    ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: footItems
                        .map((String item) => Chip(label: Text(item), visualDensity: VisualDensity.compact))
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyValue {
  const _KeyValue(this.key, this.value);

  final String key;
  final String value;
}

List<_KeyValue> _labelValueRows(List<String> bullets) {
  final rows = <_KeyValue>[];
  for (final bullet in bullets) {
    final split = _splitLabel(bullet);
    if (split == null) {
      continue;
    }
    rows.add(split);
  }
  return rows;
}

_KeyValue? _splitLabel(String bullet) {
  final index = bullet.indexOf(':');
  final altIndex = bullet.indexOf('：');
  final position = index >= 0 ? index : altIndex;
  if (position <= 0) {
    return null;
  }
  final key = bullet.substring(0, position).trim();
  final value = bullet.substring(position + 1).trim();
  if (key.isEmpty || value.isEmpty || key.length > 40) {
    return null;
  }
  return _KeyValue(key, value);
}

// ---------------------------------------------------------------- materials --

class _MaterialsSections extends StatelessWidget {
  const _MaterialsSections({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth >= 820 ? 2 : 1;
        return _ResponsiveGrid(
          columns: columns,
          spacing: AppSpacing.md,
          children: unit.topics
              .map((Topic topic) => _MaterialTile(topic: topic, accent: accent))
              .toList(growable: false),
        );
      },
    );
  }
}

class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.topic, required this.accent});

  final Topic topic;
  final Color accent;

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(iconForTopic(topic.title), color: accent, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(topic.title, style: theme.textTheme.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...topic.bullets.map(
            (String bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('— $bullet', style: theme.textTheme.bodyLarge),
            ),
          ),
          if (topic.listItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: topic.listItems
                    .map((String item) => Chip(label: Text(item), visualDensity: VisualDensity.compact))
                    .toList(growable: false),
              ),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ process --

class _ProcessSections extends StatelessWidget {
  const _ProcessSections({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < unit.topics.length; i++)
          _ProcessStep(
            index: i + 1,
            topic: unit.topics[i],
            accent: accent,
            isLast: i == unit.topics.length - 1,
          ),
      ],
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({
    required this.index,
    required this.topic,
    required this.accent,
    required this.isLast,
  });

  final int index;
  final Topic topic;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: 46,
            child: Column(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: accent.withValues(alpha: 0.3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Container(
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
                        Icon(iconForTopic(topic.title), size: 18, color: accent),
                        const SizedBox(width: 8),
                        Expanded(child: Text(topic.title, style: theme.textTheme.titleLarge)),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ...topic.bullets.map(
                      (String bullet) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(bullet, style: theme.textTheme.bodyLarge),
                      ),
                    ),
                    if (topic.listItems.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: topic.listItems
                              .map((String item) => Chip(
                                    label: Text(item),
                                    visualDensity: VisualDensity.compact,
                                  ))
                              .toList(growable: false),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- timeline --

class _TimelineSections extends StatelessWidget {
  const _TimelineSections({required this.unit, required this.accent});

  final LearningUnit unit;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final entries = _yearEntries(unit.topics);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (entries.isNotEmpty) ...<Widget>[
          _YearStrip(entries: entries, accent: accent),
          const SizedBox(height: AppSpacing.lg),
        ],
        ...unit.topics.map(
          (Topic topic) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: TopicCard(topic: topic, accent: accent),
          ),
        ),
      ],
    );
  }
}

class _YearEntry {
  const _YearEntry({required this.year, required this.text});

  final int year;
  final String text;
}

List<_YearEntry> _yearEntries(List<Topic> topics) {
  final entries = <_YearEntry>[];
  final pattern = RegExp(r'(\d{4})');
  for (final topic in topics) {
    for (final bullet in topic.bullets) {
      for (final match in pattern.allMatches(bullet)) {
        final year = int.tryParse(match.group(1) ?? '');
        if (year == null || year < 1800 || year > 2100) {
          continue;
        }
        entries.add(_YearEntry(year: year, text: bullet));
      }
    }
  }
  entries.sort((a, b) => a.year.compareTo(b.year));
  return entries;
}

class _YearStrip extends StatelessWidget {
  const _YearStrip({required this.entries, required this.accent});

  final List<_YearEntry> entries;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final years = <int>[];
    for (final entry in entries) {
      if (!years.contains(entry.year)) {
        years.add(entry.year);
      }
    }
    if (years.isEmpty) {
      return const SizedBox.shrink();
    }
    final first = years.first;
    final last = years.last;
    return Container(
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
              Icon(Icons.timeline, size: 18, color: accent),
              const SizedBox(width: 8),
              Text('محطات زمنية', style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final span = (last - first).clamp(1, 100000);
              return SizedBox(
                height: 74,
                child: Stack(
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 26,
                      child: Container(height: 3, color: accent.withValues(alpha: 0.25)),
                    ),
                    for (final year in years)
                      Positioned(
                        left: ((year - first) / span) * (constraints.maxWidth - 74) + 8,
                        top: 8,
                        child: SizedBox(
                          width: 78,
                          child: Column(
                            children: <Widget>[
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: scheme.surface, width: 3),
                                ),
                                child: Text(
                                  '$year',
                                  textDirection: TextDirection.ltr,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------------- grid ---

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    required this.columns,
    required this.spacing,
  });

  final List<Widget> children;
  final int columns;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (columns <= 1) {
      return Column(
        children: children
            .map((Widget child) => Padding(
                  padding: EdgeInsets.only(bottom: spacing),
                  child: child,
                ))
            .toList(growable: false),
      );
    }
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < columns; j++) {
        final index = i + j;
        if (index < children.length) {
          rowChildren.add(Expanded(child: children[index]));
          if (j != columns - 1) {
            rowChildren.add(SizedBox(width: spacing));
          }
        }
      }
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rowChildren,
            ),
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
