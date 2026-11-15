import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';

/// The picture of a topic, shown at the start of that topic in the reader.
///
/// A topic may carry more than one picture (the booklet pages that share a
/// topic), so the widget lays them out in document order and never renders an
/// empty gap when a topic has none.
class TopicDrawings extends StatelessWidget {
  const TopicDrawings({super.key, required this.drawings, required this.accent});

  final List<TopicDrawing> drawings;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (drawings.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: drawings
            .map(
              (TopicDrawing drawing) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TopicDrawingCard(drawing: drawing, accent: accent),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

/// One tappable picture: the drawing itself, its title and a topic label.
class TopicDrawingCard extends StatelessWidget {
  const TopicDrawingCard({super.key, required this.drawing, required this.accent});

  final TopicDrawing drawing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRoutes.openDrawing(context, drawing),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 220,
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Image.asset(
                    drawing.asset,
                    fit: BoxFit.contain,
                    cacheWidth: 720,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stack,
                    ) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: <Widget>[
                    Icon(Icons.brush_outlined, size: 18, color: accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        drawing.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.zoom_in, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
