import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/progress.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import 'landing_shell.dart';

/// Display preferences, progress management and content attribution.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _SettingsCard(
          title: 'المظهر',
          icon: Icons.palette_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SegmentedButton<AppThemeMode>(
                segments: const <ButtonSegment<AppThemeMode>>[
                  ButtonSegment<AppThemeMode>(
                    value: AppThemeMode.system,
                    label: Text('النظام'),
                    icon: Icon(Icons.brightness_auto_outlined),
                  ),
                  ButtonSegment<AppThemeMode>(
                    value: AppThemeMode.light,
                    label: Text('نهاري'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment<AppThemeMode>(
                    value: AppThemeMode.dark,
                    label: Text('ليلي'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: <AppThemeMode>{state.progress.themeMode},
                onSelectionChanged: (Set<AppThemeMode> value) {
                  state.setThemeMode(value.first);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: <Widget>[
                  const Icon(Icons.format_size, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Text('حجم الخط', style: theme.textTheme.titleMedium),
                  const Spacer(),
                  Text(
                    '${toArabicDigits((state.textScale * 100).round().toString())}٪',
                    style: theme.textTheme.labelLarge,
                  ),
                ],
              ),
              Slider(
                value: state.textScale,
                min: AppState.MinTextScale,
                max: AppState.MaxTextScale,
                divisions: 6,
                label: '${(state.textScale * 100).round()}٪',
                onChanged: (double value) => state.setTextScale(value),
              ),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  'نموذج للنص بالحجم المختار: الخط أساس في تكوين الأشكال، والوحدة والاتزان '
                  'وتوزيع الضوء من قواعد تنظيم العمل الفني.',
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: 'التقدم المحلي',
          icon: Icons.insights_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _InfoRow(
                label: 'الوحدات المقروءة',
                value: '${toArabicDigits('${state.readUnitsCount}')} من ${toArabicDigits('${state.totalUnits}')}',
              ),
              _InfoRow(
                label: 'العناصر المحفوظة',
                value: toArabicDigits('${state.favoriteUnits.length + state.favoriteLessons.length}'),
              ),
              _InfoRow(
                label: 'نسبة الاستكشاف',
                value: '${toArabicDigits('${(state.overallProgress * 100).round()}')}٪',
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () => _confirmReset(context, state),
                icon: const Icon(Icons.restart_alt),
                label: const Text('إعادة تعيين سجل القراءة والمفضلة'),
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: 'عن المحتوى',
          icon: Icons.menu_book_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'جميع الموضوعات والأسئلة مأخوذة من ملف «ملخص التربية الفنية» للمرحلة المتوسطة، '
                'ومن خطط الدروس ولوحات دليل المعلم. لم يُضف محتوى علمي من خارج المصدر.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () => AppRoutes.openGlossary(context),
                    icon: const Icon(Icons.translate, size: 18),
                    label: const Text('المصطلحات'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => AppRoutes.openPlates(context),
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text('اللوحات'),
                  ),
                ],
              ),
            ],
          ),
        ),
        _SettingsCard(
          title: 'التطبيق',
          icon: Icons.info_outline,
          child: Column(
            children: <Widget>[
              const _InfoRow(label: 'الاسم', value: 'مِرسم'),
              const _InfoRow(label: 'الإصدار', value: '1.0.0 (1)'),
              _InfoRow(label: 'الوحدات', value: toArabicDigits('${state.library.units.length}')),
              _InfoRow(label: 'اللوحات', value: toArabicDigits('${state.library.plates.length}')),
              _InfoRow(label: 'الدروس التطبيقية', value: toArabicDigits('${state.library.lessons.length}')),
              _InfoRow(label: 'المصالح', value: 'Android • Windows'),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            'يعمل التطبيق دون إنترنت — جميع الوسائط مضمنة في الحزمة.',
            style: theme.textTheme.labelMedium,
          ),
        ),
      ],
    );

    if (!embedded) {
      return Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
          children: <Widget>[AppPage(maxWidth: AppLayout.readingMaxWidth, child: body)],
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          const AppPageHeader(title: 'الإعدادات', subtitle: 'المظهر، التقدم، وعن المحتوى'),
          AppPage(maxWidth: AppLayout.readingMaxWidth, child: body),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('إعادة تعيين البيانات'),
        content: const Text('سيتم حذف سجل القراءة والمفضلة ونتائج الاختبارات من هذا الجهاز.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إعادة تعيين'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await state.resetProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إعادة تعيين البيانات المحلية')),
        );
      }
    }
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 20, color: scheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}
