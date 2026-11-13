import 'package:flutter/material.dart';

import '../theme/dimens.dart';

/// Constrains page content to a comfortable measure on wide Windows screens.
class AppPage extends StatelessWidget {
  const AppPage({
    super.key,
    required this.child,
    this.maxWidth = AppLayout.pageMaxWidth,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
