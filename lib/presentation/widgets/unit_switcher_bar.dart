import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../domain/models/library.dart';

/// Horizontal switcher between the units of one grade.
///
/// It sits right under the app bar of the unit reader so the learner can jump
/// between the four units of the grade without going back to the index.
/// The bar is a public widget (not a private helper) so the layout tests can
/// measure it directly.
class UnitSwitcherBar extends StatelessWidget {
  const UnitSwitcherBar({
    super.key,
    required this.units,
    required this.current,
    required this.accent,
    required this.onSelected,
    this.height = _defaultHeight,
  });

  static const double _defaultHeight = 56;

  final List<LearningUnit> units;
  final LearningUnit current;
  final Color accent;
  final ValueChanged<LearningUnit> onSelected;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
        itemCount: units.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (BuildContext context, int index) {
          final unit = units[index];
          final selected = unit.id == current.id;
          return Semantics(
            selected: selected,
            button: true,
            child: Material(
              color: selected ? accent.withValues(alpha: 0.16) : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(30),
              child: InkWell(
                borderRadius: BorderRadius.circular(30),
                onTap: () {
                  if (!selected) {
                    onSelected(unit);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: selected ? accent : scheme.outlineVariant),
                  ),
                  child: Text(
                    '${toArabicDigits('${unit.order}')}. ${unit.displayTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: selected ? accent : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
