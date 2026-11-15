import 'package:flutter/material.dart';

import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/asset_viewer.dart';
import 'unit_screen.dart';

/// Full-screen view of one topic drawing, with the unit and the topic it shows.
class DrawingViewerScreen extends StatelessWidget {
  const DrawingViewerScreen({super.key, required this.drawingId});

  final String drawingId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final drawing = state.library.drawingById(drawingId);
    if (drawing == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('الرسم غير موجود')));
    }
    final LearningUnit? unit = state.library.unitById(drawing.unitId);
    return AssetViewer(
      title: drawing.title,
      asset: drawing.asset,
      caption: 'الموضوع: ${drawing.topicTitle} — ${drawing.unitTitle} (${drawing.grade})',
      links: <Widget>[
        if (unit != null)
          ViewerLink(
            icon: Icons.menu_book_outlined,
            label: 'الوحدة: ${unit.displayTitle}',
            onPressed: () {
              final navigator = Navigator.of(context);
              navigator.pushReplacement(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => UnitScreen(unitId: unit.id),
                ),
              );
            },
          ),
      ],
    );
  }
}
