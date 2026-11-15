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

/// The one gallery of the app's pictures, ordered by topic.
///
/// It presents the scanned plates of the units and the topic drawings of the
/// chosen grade, each group under the unit it belongs to, so a picture is
/// always read together with the topic it illustrates.
class PlatesScreen extends StatelessWidget {
  const PlatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final plates = state.visiblePlates;
    final drawings = state.visibleDrawings;
    final plateGroups = groupByUnit<Plate>(
      state.library.units,
      plates,
      (Plate plate) => plate.unitId,
    );
    final drawingGroups = groupByUnit<TopicDrawing>(
      state.library.units,
      drawings,
      (TopicDrawing drawing) => drawing.unitId,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('اللوحات'),
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
                  'صور المصدر مرتبة حسب الموضوع: لوحات الوحدات ورسوم الموضوعات. '
                  'اضغط أي صورة لعرضها بحجم أكبر.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                if (plateGroups.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'لوحات الوحدات',
                    subtitle: '${toArabicDigits('${plates.length}')} لوحة',
                    accent: scheme.primary,
                  ),
                  ...plateGroups.map(
                    (GalleryGroup<Plate> group) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GalleryGroupHeader(
                            title: group.unit.displayTitle,
                            subtitle:
                                '${group.unit.grade} • ${toArabicDigits('${group.items.length}')} لوحة',
                            accent: scheme.primary,
                          ),
                          GalleryTiles(
                            children: group.items
                                .map((Plate plate) => _PlateTile(plate: plate))
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (drawingGroups.isNotEmpty) ...<Widget>[
                  SectionHeader(
                    title: 'رسوم الموضوعات',
                    subtitle:
                        '${toArabicDigits('${drawings.length}')} رسماً — صورة واحدة لكل موضوع',
                    accent: scheme.tertiary,
                  ),
                  ...drawingGroups.map(
                    (GalleryGroup<TopicDrawing> group) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          GalleryGroupHeader(
                            title: group.unit.displayTitle,
                            subtitle:
                                '${group.unit.grade} • ${toArabicDigits('${group.items.length}')} رسماً',
                            accent: scheme.tertiary,
                          ),
                          GalleryTiles(
                            children: group.items
                                .map(
                                  (TopicDrawing drawing) => _TopicDrawingTile(drawing: drawing),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlateTile extends StatelessWidget {
  const _PlateTile({required this.plate});

  final Plate plate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppRoutes.openPlate(context, plate),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ClipRect(
                child: SizedBox(
                  height: 210,
                  child: ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Image.asset(
                      plate.asset,
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
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(plate.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      plate.caption,
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

class _TopicDrawingTile extends StatelessWidget {
  const _TopicDrawingTile({required this.drawing});

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
              ClipRect(
                child: SizedBox(
                  height: 210,
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
