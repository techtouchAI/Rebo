import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';

/// One unit of a gallery together with the pictures that belong to it.
class GalleryGroup<T> {
  const GalleryGroup({required this.unit, required this.items});

  final LearningUnit unit;
  final List<T> items;
}

/// Groups gallery items by the unit they belong to, keeping the library order
/// so that every gallery reads the material in the same sequence.
List<GalleryGroup<T>> groupByUnit<T>(
  List<LearningUnit> units,
  List<T> items,
  String Function(T item) unitIdOf,
) {
  final buckets = <String, List<T>>{};
  for (final item in items) {
    buckets.putIfAbsent(unitIdOf(item), () => <T>[]).add(item);
  }
  final groups = <GalleryGroup<T>>[];
  for (final unit in units) {
    final bucket = buckets.remove(unit.id);
    if (bucket != null) {
      groups.add(GalleryGroup<T>(unit: unit, items: bucket));
    }
  }
  return groups;
}

/// Equal-width tiles: one column on a phone, two on a tablet, three on a
/// desktop window. The tile itself only has to fill its width.
class GalleryTiles extends StatelessWidget {
  const GalleryTiles({super.key, required this.children});

  final List<Widget> children;

  static const double _spacing = AppSpacing.md;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 640
                ? 2
                : 1;
        final width = (constraints.maxWidth - _spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: _spacing,
          runSpacing: _spacing,
          children: children
              .map((Widget child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

/// Compact heading above one unit group of a gallery.
class GalleryGroupHeader extends StatelessWidget {
  const GalleryGroupHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 34,
            margin: const EdgeInsetsDirectional.only(end: AppSpacing.sm, top: 4),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
