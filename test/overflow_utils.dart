import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Appends a one-line diagnosis to a file the CI step turns into annotations.
void reportLayoutDiagnostic(String message) {
  final line = "LAYOUT-DIAG ${message.replaceAll(RegExp(r'\s+'), ' ')}\n";
  try {
    File('layout-report.txt').writeAsStringSync(line, mode: FileMode.append, flush: true);
  } catch (_) {
    // Reporting must never break a test run.
  }
}

/// Finds the flexible rows/columns whose children are laid out past the edge.
///
/// The default Flutter error only reports the number of overflowing pixels;
/// tests need to know *which* row did it, so this walks every [RenderFlex].
List<String> findFlexOverflows(WidgetTester tester) {
  final hits = <String>[];
  for (final render in tester.allRenderObjects) {
    if (render is! RenderFlex) {
      continue;
    }
    if (!render.hasSize) {
      continue;
    }
    final horizontal = render.direction == Axis.horizontal;
    final limit = horizontal ? render.size.width : render.size.height;
    if (limit <= 0) {
      continue;
    }
    var extent = 0.0;
    RenderBox? child = render.firstChild;
    while (child != null) {
      final data = child.parentData;
      if (data is FlexParentData) {
        final edge = horizontal ? data.offset.dx + child.size.width : data.offset.dy + child.size.height;
        extent = math.max(extent, edge);
      }
      child = render.childAfter(child);
    }
    if (extent > limit + 0.5) {
      hits.add(
        'overflows ${(extent - limit).toStringAsFixed(1)}px '
        '(${extent.toStringAsFixed(1)} > ${limit.toStringAsFixed(1)}, ${render.direction.name}) '
        'from ${render.debugCreator ?? "an unknown flex"}',
      );
    }
  }
  return hits;
}
