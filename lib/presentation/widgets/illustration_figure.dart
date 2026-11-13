import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';

/// Shows an authored vector illustration with its caption and colour legend.
///
/// Tapping opens the same drawing in a larger, zoomable view.
class IllustrationFigure extends StatelessWidget {
  const IllustrationFigure({
    super.key,
    required this.figure,
    required this.accent,
    this.height = 240,
  });

  final Figure figure;
  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Material(
          color: scheme.brightness == Brightness.light
              ? const Color(0xFFFBF6EC)
              : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => showIllustrationDialog(
              context,
              asset: figure.asset,
              caption: figure.caption,
              legend: figure.legend,
            ),
            child: Container(
              height: height,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: SvgPicture.asset(
                figure.asset,
                fit: BoxFit.contain,
                semanticsLabel: figure.caption,
                placeholderBuilder: (BuildContext context) => Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accent),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(Icons.brush_outlined, size: 16, color: accent),
            ),
            const SizedBox(width: 6),
            // The caption and its zoom action stay on one line: at 390 px the
            // text shrinks slightly instead of breaking into a tall column.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  figure.caption,
                  maxLines: 1,
                  softWrap: false,
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13.5, height: 1.5),
                ),
              ),
            ),
            IconButton(
              tooltip: 'تكبير الرسم',
              visualDensity: VisualDensity.compact,
              onPressed: () => showIllustrationDialog(
                context,
                asset: figure.asset,
                caption: figure.caption,
                legend: figure.legend,
              ),
              icon: Icon(Icons.zoom_out_map, size: 18, color: accent),
            ),
          ],
        ),
        if (figure.legend.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xs),
          // The legend always stays on a single line: the row shrinks instead
          // of wrapping onto a second line on narrow phones.
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (int index = 0; index < figure.legend.length; index++) ...<Widget>[
                        if (index > 0) const SizedBox(width: AppSpacing.sm),
                        _LegendChip(legend: figure.legend[index]),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.legend});

  final FigureLegend legend;

  @override
  Widget build(BuildContext context) {
    final color = _parseHex(legend.color) ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            legend.label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// Full-screen preview of a vector illustration with pinch / button zoom.
Future<void> showIllustrationDialog(
  BuildContext context, {
  required String asset,
  required String caption,
  required List<FigureLegend> legend,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (BuildContext context) {
      final scheme = Theme.of(context).colorScheme;
      return Dialog(
        backgroundColor: scheme.surface,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980, maxHeight: 780),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        caption,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: SvgPicture.asset(asset, fit: BoxFit.contain),
                    ),
                  ),
                ),
                if (legend.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      children: legend
                          .map((item) => _LegendChip(legend: item))
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Color? _parseHex(String value) {
  var hex = value.replaceAll('#', '').trim();
  if (hex.length == 6) {
    hex = 'FF$hex';
  }
  final parsed = int.tryParse(hex, radix: 16);
  return parsed == null ? null : Color(parsed);
}
