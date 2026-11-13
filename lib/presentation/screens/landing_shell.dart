import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'index_screen.dart';
import 'settings_screen.dart';

/// Responsive shell: navigation rail on Windows / tablets, navigation bar on
/// phones. Both share the same four destinations.
class LandingShell extends StatefulWidget {
  const LandingShell({super.key});

  @override
  State<LandingShell> createState() => _LandingShellState();
}

class _LandingShellState extends State<LandingShell> {
  int _index = 0;

  static const List<_Destination> _destinations = <_Destination>[
    _Destination('الرئيسية', Icons.home_outlined, Icons.home),
    _Destination('الفهرس', Icons.list_alt_outlined, Icons.list_alt),
    _Destination('المفضلة', Icons.bookmark_border, Icons.bookmark),
    _Destination('الإعدادات', Icons.settings_outlined, Icons.settings),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final useRail = width >= AppLayout.railBreakpoint;
    final pages = <Widget>[
      const HomeScreen(),
      const IndexScreen(),
      const FavoritesScreen(embedded: true),
      const SettingsScreen(embedded: true),
    ];

    if (useRail) {
      return Scaffold(
        body: Row(
          children: <Widget>[
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (int value) => setState(() => _index = value),
              labelType: width >= 1180 ? NavigationRailLabelType.none : NavigationRailLabelType.all,
              extended: width >= 1180,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: _BrandMark(compact: true),
              ),
              destinations: _destinations
                  .map((_Destination item) => NavigationRailDestination(
                        icon: Icon(item.icon),
                        selectedIcon: Icon(item.selectedIcon),
                        label: Text(item.label),
                      ))
                  .toList(growable: false),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: IndexedStack(index: _index, children: pages)),
          ],
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: _destinations
            .map((_Destination item) => NavigationDestination(
                  icon: Icon(item.icon),
                  selectedIcon: Icon(item.selectedIcon),
                  label: item.label,
                ))
            .toList(growable: false),
      ),
    );
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Small identity mark (arch + colour dots) drawn with plain widgets.
class _BrandMark extends StatelessWidget {
  const _BrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: compact ? 40 : 46,
          height: compact ? 40 : 46,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.palette, color: scheme.onPrimary, size: compact ? 22 : 26),
        ),
        if (!compact) ...<Widget>[
          const SizedBox(width: AppSpacing.md),
          Text('مِرسم', style: Theme.of(context).textTheme.headlineMedium),
        ],
      ],
    );
  }
}

/// Small brand header used on top of the primary pages.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    this.showBrand = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < 640;
    final useRail = width >= AppLayout.railBreakpoint;

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineLarge?.copyWith(fontSize: narrow ? 24 : null),
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              maxLines: narrow ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: narrow ? 13 : null),
            ),
          ),
      ],
    );

    final topRow = Row(
      children: <Widget>[
        if (showBrand) _BrandMark(compact: narrow),
        const Spacer(),
        ...actions,
        const TextScaleControls(),
      ],
    );

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + AppSpacing.lg,
        left: AppSpacing.xl,
        right: AppSpacing.xl,
        bottom: AppSpacing.md,
      ),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                topRow,
                const SizedBox(height: AppSpacing.sm),
                titleBlock,
              ],
            )
          : Row(
              children: <Widget>[
                if (showBrand && !useRail) ...<Widget>[
                  _BrandMark(compact: width < 900),
                  const SizedBox(width: AppSpacing.lg),
                ],
                Expanded(child: titleBlock),
                ...actions,
                const SizedBox(width: AppSpacing.xs),
                const TextScaleControls(),
              ],
            ),
    );
  }
}

/// Reads the current state in a page that is hosted by the shell.
AppState pageState(BuildContext context) => AppScope.of(context);
