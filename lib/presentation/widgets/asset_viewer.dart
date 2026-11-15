import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import 'text_scale_controls.dart';

/// Full-screen zoomable view of a picture bundled with the application.
///
/// The plate viewer and the topic-drawing viewer share this scaffold so both
/// keep the same zoom range, caption bar, text-size controls and dark stage.
class AssetViewer extends StatelessWidget {
  const AssetViewer({
    super.key,
    required this.title,
    required this.asset,
    required this.caption,
    this.links = const <Widget>[],
  });

  final String title;
  final String asset;
  final String caption;

  /// Buttons that lead back into the content the picture belongs to.
  final List<Widget> links;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 16)),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  errorBuilder: (BuildContext context, Object error, StackTrace? stack) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.lg),
              color: Colors.black.withValues(alpha: 0.85),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    caption,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  if (links.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: links,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Outlined button of the viewer caption bar; readable on the black stage.
class ViewerLink extends StatelessWidget {
  const ViewerLink({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
      ),
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
