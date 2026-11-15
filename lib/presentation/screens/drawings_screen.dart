import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/gallery_layout.dart';
import '../widgets/text_scale_controls.dart';

/// Gallery of the fourteen topic drawings: one picture per curriculum topic.
///
/// The pictures of the chosen grade are grouped by unit, in the same order as
/// the reader, and each tile names the topic the picture belongs to.
class DrawingsScreen extends StatelessWidget {
  const DrawingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final drawings = state.visibleDrawings;
    final groups = groupByUnit<TopicDrawing>(
      state.library.units,
      drawings,
      (TopicDrawing drawing) => drawing.unitId,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('موضوعات مصوّرة'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'صورة واحدة لكل موضوع من موضوعات الرسم والتصميم والزخرفة، مرتبة حسب '
                  'وحدات الصف المختار وموضوعاتها. اضغط أي صورة لعرضها بحجم أكبر.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'موضوعات مصوّرة',
                  subtitle: '${toArabicDigits('${drawings.length}')} موضوعاً مصوّراً',
                  accent: theme.colorScheme.tertiary,
                ),
                ...groups.map(
                  (GalleryGroup<TopicDrawing> group) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        GalleryGroupHeader(
                          title: group.unit.displayTitle,
                          subtitle:
                              '${group.unit.grade} • ${toArabicDigits('${group.items.length}')} رسماً',
                          accent: theme.colorScheme.tertiary,
                        ),
                        GalleryTiles(
                          children: group.items
                              .map(
                                (TopicDrawing drawing) => _DrawingTile(drawing: drawing),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ),
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

class _DrawingTile extends StatelessWidget {
  const _DrawingTile({required this.drawing});

  final TopicDrawing drawing;

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
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                height: 210,
                child: ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Image.asset(
                    drawing.asset,
                    fit: BoxFit.contain,
                    cacheWidth: 720,
                    errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
                        const Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(drawing.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'الموضوع: ${drawing.topicTitle}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
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
