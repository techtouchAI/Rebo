import 'package:flutter/material.dart';

/// Brand palette of مِرسم.
///
/// The colours are drawn from the materials of the art classroom: fired clay,
/// indigo pigment, ochre and paper.
abstract final class AppColors {
  static const Color clay = Color(0xFFB4462F);
  static const Color claySoft = Color(0xFFE9C5B7);
  static const Color indigo = Color(0xFF1E5F74);
  static const Color indigoSoft = Color(0xFFAECBD4);
  static const Color ochre = Color(0xFFD9A34A);
  static const Color ochreSoft = Color(0xFFF2E1BE);
  static const Color leaf = Color(0xFF4E7C59);
  static const Color leafSoft = Color(0xFFC4D6C8);
  static const Color ink = Color(0xFF23242B);
  static const Color inkSoft = Color(0xFF5A5B66);
  static const Color paper = Color(0xFFF7F1E6);
  static const Color paperHigh = Color(0xFFFFFCF5);
  static const Color night = Color(0xFF14151A);
  static const Color nightSurface = Color(0xFF1E2027);
  static const Color nightElevated = Color(0xFF262932);

  /// Accent used for a unit or lesson, resolved from the content JSON.
  static Color fromAccent(String accent, bool isDark) {
    switch (accent) {
      case 'secondary':
        return isDark ? const Color(0xFF7FB6C7) : indigo;
      case 'gold':
        return isDark ? const Color(0xFFE8BE72) : const Color(0xFFB47F26);
      case 'green':
        return isDark ? const Color(0xFF8FB99A) : leaf;
      case 'ink':
        return isDark ? const Color(0xFFB8B9C4) : inkSoft;
      case 'primary':
      default:
        return isDark ? const Color(0xFFE38A6E) : clay;
    }
  }
}
