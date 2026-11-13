import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/meta_pill.dart';
import '../../core/widgets/section_header.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// Gallery of the scanned plates of the teacher guide.
class PlatesScreen extends StatelessWidget {
  const PlatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final plates = state.visiblePlates;
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحات من دليل المعلم'),
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
                  'أعمال فنية مصوّرة من صفحات دليل معلم التربية الفنية للمرحلة المتوسطة، '
                  'مرتبطة بوحداتها. اضغط أي لوحة لعرضها بحجم أكبر.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'اللوحات',
                  subtitle: '${plates.length} لوحة',
                ),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final columns = constraints.maxWidth >= 1000
                        ? 3
                        : constraints.maxWidth >= 640
                            ? 2
                            : 1;
                    final spacing = AppSpacing.md;
                    final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: plates
                          .map((Plate plate) => SizedBox(
                                width: width,
                                child: _PlateTile(plate: plate),
                              ))
                          .toList(growable: false),
                    );
                  },
                ),
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
              AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.asset(
                  plate.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) => Container(
                    color: scheme.surfaceContainerHighest,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
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
                    MetaPill(label: plate.grade, color: scheme.tertiary),
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
