/// Arabic typefaces whose regular and bold variants are bundled with the app.
/// These families include the Arabic presentation forms needed by the PDF
/// renderer, including the isolated yeh.
enum QuestionPrintFont {
  plex('IBM بلكس', 'IBMPlexSansArabic'),
  kufi('كوفي نوتو', 'NotoKufiArabic'),
  amiri('أميري', 'Amiri');

  const QuestionPrintFont(this.label, this.family);

  final String label;
  final String family;

  String get regularAsset => 'assets/fonts/$family-Regular.ttf';
  String get boldAsset => 'assets/fonts/$family-Bold.ttf';
}

/// Print-only typography. Sizes are in PDF points and do not change the app's
/// reading settings. Validation is shared by the screen and the PDF builder.
class QuestionPrintSettings {
  const QuestionPrintSettings({
    this.font = QuestionPrintFont.plex,
    this.bodyFontSize = defaultBodyFontSize,
    this.headingFontSize = defaultHeadingFontSize,
  });

  static const int defaultBodyFontSize = 12;
  static const int defaultHeadingFontSize = 14;
  static const int minFontSize = 8;
  static const int maxFontSize = 32;

  final QuestionPrintFont font;
  final int bodyFontSize;
  final int headingFontSize;

  static bool isValidFontSize(int? size) =>
      size != null && size >= minFontSize && size <= maxFontSize;

  bool get isValid => isValidFontSize(bodyFontSize) && isValidFontSize(headingFontSize);
}
