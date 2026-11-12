import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../domain/models/library.dart';
import '../state/app_state.dart';
import 'unit_screen.dart';

/// Full-screen zoomable view of a scanned plate, with its source reference.
class PlateViewerScreen extends StatelessWidget {
  const PlateViewerScreen({super.key, required this.plateId});

  final String plateId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    Plate? plate;
    for (final Plate item in state.library.plates) {
      if (item.id == plateId) {
        plate = item;
        break;
      }
    }
    if (plate == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('اللوحة غير موجودة')));
    }
    final selected = plate;
    final unit = state.library.unitById(selected.unitId);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(selected.title, style: const TextStyle(fontSize: 16)),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: Center(
                child: Image.asset(
                  selected.asset,
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
                    selected.caption,
                    style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected.source,
                    style: theme.textTheme.labelMedium?.copyWith(color: Colors.white70),
                  ),
                  if (unit != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (BuildContext context) => UnitScreen(unitId: unit.id),
                          ),
                        );
                      },
                      icon: const Icon(Icons.menu_book_outlined, size: 18),
                      label: Text('الوحدة: ${unit.displayTitle}'),
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
