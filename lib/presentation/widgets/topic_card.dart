import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';

/// Iconography that follows the vocabulary of the curriculum topics.
IconData iconForTopic(String title) {
  final text = title;
  if (text.contains('منظور')) {
    return Icons.filter_none;
  }
  if (text.contains('لون')) {
    return Icons.palette_outlined;
  }
  if (text.contains('زخرف') || text.contains('وحدات')) {
    return Icons.auto_awesome_outlined;
  }
  if (text.contains('تصميم') || text.contains('ملصق')) {
    return Icons.grid_view_outlined;
  }
  if (text.contains('طباعة') || text.contains('تفريغ') || text.contains('حفر')) {
    return Icons.print_outlined;
  }
  if (text.contains('ورق') || text.contains('مجسم')) {
    return Icons.category_outlined;
  }
  if (text.contains('طين') || text.contains('فخار') || text.contains('نحت')) {
    return Icons.emoji_objects_outlined;
  }
  if (text.contains('خشب')) {
    return Icons.carpenter_outlined;
  }
  if (text.contains('معدن') || text.contains('سلك')) {
    return Icons.hexagon_outlined;
  }
  if (text.contains('نسيج') || text.contains('حياكة') || text.contains('مكرمية')) {
    return Icons.texture_outlined;
  }
  if (text.contains('قصب') || text.contains('خامات') || text.contains('خضر')) {
    return Icons.grass_outlined;
  }
  if (text.contains('جلود') || text.contains('زهور')) {
    return Icons.eco_outlined;
  }
  if (text.contains('معرض') || text.contains('متاحف') || text.contains('فنون')) {
    return Icons.museum_outlined;
  }
  if (text.contains('جماعات') || text.contains('حركة') || text.contains('تاريخ')) {
    return Icons.timeline_outlined;
  }
  if (text.contains('ضوء') || text.contains('ظل')) {
    return Icons.wb_sunny_outlined;
  }
  if (text.contains('أدوات') || text.contains('آلات') || text.contains('مواد')) {
    return Icons.handyman_outlined;
  }
  if (text.contains('قيق') || text.contains('قصة') || text.contains('قصص')) {
    return Icons.auto_stories_outlined;
  }
  if (text.contains('مناسبات') || text.contains('أشخاص') || text.contains('طبيعة')) {
    return Icons.landscape_outlined;
  }
  return Icons.brush_outlined;
}

/// A topic of a unit, rendered as a card with its statements.
class TopicCard extends StatelessWidget {
  const TopicCard({
    super.key,
    required this.topic,
    required this.accent,
    this.index,
    this.emphasized = false,
  });

  final Topic topic;
  final Color accent;
  final int? index;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: emphasized ? accent.withValues(alpha: 0.07) : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: emphasized ? accent.withValues(alpha: 0.4) : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(iconForTopic(topic.title), size: 19, color: accent),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(topic.title, style: theme.textTheme.titleLarge),
                ),
              ),
              if (index != null)
                Text(
                  '$index',
                  style: theme.textTheme.labelMedium?.copyWith(color: accent),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...topic.bullets.map((String bullet) => _Bullet(text: bullet, accent: accent)),
          if (topic.listItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _CountList(
              title: topic.listTitle,
              items: topic.listItems,
              accent: accent,
            ),
          ],
          if (topic.methods.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            ...topic.methods.map((TeachingMethod method) => _MethodTile(method: method, accent: accent)),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text, required this.accent});

  final String text;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 9, left: 2, right: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.8), shape: BoxShape.circle),
            ),
          ),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}

class _CountList extends StatelessWidget {
  const _CountList({required this.title, required this.items, required this.accent});

  final String? title;
  final List<String> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (title != null && title!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Icon(Icons.format_list_numbered, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title!,
                      style: theme.textTheme.labelLarge?.copyWith(color: accent),
                    ),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (int i = 0; i < items.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    '${_arabicNumber(i + 1)}. ${items[i]}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontSize: 13.5,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({required this.method, required this.accent});

  final TeachingMethod method;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.chevron_left, size: 18, color: accent),
              Expanded(
                child: Text(method.title, style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          for (final bullet in method.bullets)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 18, top: 2),
              child: Text(bullet, style: theme.textTheme.bodyLarge),
            ),
        ],
      ),
    );
  }
}

String _arabicNumber(int value) {
  const digits = <String>['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  if (value < 10) {
    return digits[value];
  }
  final tens = value ~/ 10;
  final units = value % 10;
  return '${digits[tens]}${digits[units]}';
}
