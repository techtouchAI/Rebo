import 'package:flutter/material.dart';

import '../../domain/models/library.dart';
import '../state/app_state.dart';
import '../widgets/asset_viewer.dart';
import 'unit_screen.dart';

/// Full-screen zoomable view of a scanned plate, with its source reference.
class PlateViewerScreen extends StatelessWidget {
  const PlateViewerScreen({super.key, required this.plateId});

  final String plateId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
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
    return AssetViewer(
      title: selected.title,
      asset: selected.asset,
      caption: selected.caption,
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
