import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Keeps [children] on one line, whatever the screen width or the text scale.
///
/// The children ignore the user's text scale, so the line keeps a stable
/// height, and the whole line is scaled down uniformly in the rare case where
/// it is still wider than the available space. It never wraps nor overflows.
class SingleLineRow extends StatelessWidget {
  const SingleLineRow({
    super.key,
    required this.children,
    this.spacing = AppSpacing.sm,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0) SizedBox(width: spacing),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
