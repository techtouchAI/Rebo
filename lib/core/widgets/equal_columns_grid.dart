import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Lays [children] out in rows of exactly [columns] equally wide cells.
///
/// Unlike a `Wrap`, the number of cells per row never depends on the content
/// width or on the text scale: a row always holds [columns] cells, every cell
/// of a row shares the tallest cell's height, and an incomplete last row keeps
/// its cells aligned with the rows above it.
class EqualColumnsGrid extends StatelessWidget {
  const EqualColumnsGrid({
    super.key,
    required this.columns,
    required this.children,
    this.spacing = AppSpacing.sm,
    this.runSpacing = AppSpacing.sm,
  }) : assert(columns > 0, 'columns must be positive');

  final int columns;
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int start = 0; start < children.length; start += columns) {
      if (rows.isNotEmpty) {
        rows.add(SizedBox(height: runSpacing));
      }
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int column = 0; column < columns; column++) ...<Widget>[
                if (column > 0) SizedBox(width: spacing),
                Expanded(
                  child: start + column < children.length
                      ? children[start + column]
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}
