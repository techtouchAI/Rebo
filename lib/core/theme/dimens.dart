/// Shared spacing and radius scale (4 / 8 / 12 / 16 / 24 / 32 / 48).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

abstract final class AppRadii {
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class AppLayout {
  /// Reading measure: keeps lines comfortable on large Windows screens.
  static const double readingMaxWidth = 860;
  static const double pageMaxWidth = 1240;
  static const double railBreakpoint = 940;
}
