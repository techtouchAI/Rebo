import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Zoom in / zoom out for the reading text, available on every screen.
///
/// The scale is stored in the local reading progress, so the choice survives a
/// restart; [AppState.setTextScale] clamps it between 90% and 150%.
class TextScaleControls extends StatelessWidget {
  const TextScaleControls({super.key, this.showValue = false});

  /// Shows the current percentage between the two buttons.
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final canShrink = state.textScale > AppState.MinTextScale + 0.001;
    final canGrow = state.textScale < AppState.MaxTextScale - 0.001;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          tooltip: 'تصغير الخط',
          visualDensity: VisualDensity.compact,
          onPressed: canShrink ? () => state.setTextScale(state.textScale - 0.1) : null,
          icon: const Icon(Icons.text_decrease, size: 20),
        ),
        if (showValue)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '${(state.textScale * 100).round()}٪',
              style: theme.textTheme.labelMedium,
            ),
          ),
        IconButton(
          tooltip: 'تكبير الخط',
          visualDensity: VisualDensity.compact,
          onPressed: canGrow ? () => state.setTextScale(state.textScale + 0.1) : null,
          icon: const Icon(Icons.text_increase, size: 20),
        ),
      ],
    );
  }
}
