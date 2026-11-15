import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/models/question_print_settings.dart';
import '../../domain/services/question_print_plan.dart';

/// Produces an A4, right-to-left question-and-answer paper using bundled fonts.
/// Pages continue naturally if the selected questions cannot fit on one sheet;
/// the requested font sizes are never shrunk and questions are never clipped.
class QuestionPdfBuilder {
  const QuestionPdfBuilder({this.compress = true});

  /// Can be disabled to inspect the generated page content in tests.
  final bool compress;

  /// Backwards-compatible defaults; each plan may select different sizes.
  static const double bodyFontSize = QuestionPrintSettings.defaultBodyFontSize * 1.0;
  static const double headingFontSize = QuestionPrintSettings.defaultHeadingFontSize * 1.0;

  Future<pw.Document> build(
    QuestionPrintPlan plan, {
    required String gradeTitle,
    AssetBundle? assetBundle,
  }) async {
    if (plan.isEmpty) {
      throw ArgumentError('At least one unit with questions must be selected.');
    }
    final settings = plan.settings;
    if (!settings.isValid) {
      throw ArgumentError(
        'Print font sizes must be between '
        '${QuestionPrintSettings.minFontSize} and ${QuestionPrintSettings.maxFontSize} points.',
      );
    }

    final bundle = assetBundle ?? rootBundle;
    // These families contain the Arabic presentation forms required by the
    // PDF shaper. Flutter asset bundles may return a SynchronousFuture, so
    // await each asset directly instead of combining them with Future.wait.
    final regularFont = await bundle.load(settings.font.regularAsset);
    final boldFont = await bundle.load(settings.font.boldAsset);
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFont),
      bold: pw.Font.ttf(boldFont),
    );
    // Slightly widen the font's narrow default space without shrinking text.
    final bodyStyle = pw.TextStyle(fontSize: settings.bodyFontSize.toDouble(), wordSpacing: 1.5);
    final headingStyle = pw.TextStyle(
      fontSize: settings.headingFontSize.toDouble(),
      fontWeight: pw.FontWeight.bold,
      wordSpacing: 1.5,
    );
    final document = pw.Document(theme: theme, compress: compress);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        // RTL numeric runs can extend beyond their measured layout width.
        // Reserve extra horizontal space as font sizes grow, while keeping a
        // minimum 7 mm margin and the requested text sizes unchanged.
        margin: pw.EdgeInsets.symmetric(
          horizontal: math.max(
            7 * PdfPageFormat.mm,
            math.max(settings.bodyFontSize, settings.headingFontSize) * 1.5,
          ),
          vertical: 7 * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        build: (pw.Context context) {
          final content = <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('أسئلة الامتحان - $gradeTitle', style: headingStyle),
              ),
            ),
          ];
          for (final section in plan.sections) {
            // Keep a type heading together with the first question line, even
            // when the user chooses larger text. Unit names are not printed.
            content.add(
              pw.NewPage(freeSpace: settings.headingFontSize * 1.6 + settings.bodyFontSize * 1.8),
            );
            content.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, bottom: 1),
                child: pw.Text(section.kind.printHeading, style: headingStyle),
              ),
            );
            var number = 0;
            for (final group in section.groups) {
              for (final question in group.questions) {
                number++;
                content.add(pw.NewPage(freeSpace: settings.bodyFontSize * 1.6));
                // A direct spanning Text can continue on the next A4 page if
                // a future question is exceptionally long.
                content.add(
                  pw.Text(
                    formatPrintableQuestion(question, number),
                    style: bodyStyle,
                    textAlign: pw.TextAlign.right,
                    overflow: pw.TextOverflow.span,
                  ),
                );
              }
            }
          }
          return content;
        },
      ),
    );
    return document;
  }
}

/// Sends the exact A4 document to the platform print dialog, offline.
abstract final class QuestionPrinter {
  static Future<void> print(QuestionPrintPlan plan, String gradeTitle) async {
    final document = await const QuestionPdfBuilder().build(plan, gradeTitle: gradeTitle);
    final bytes = await document.save();
    await Printing.layoutPdf(
      name: 'mirsam-questions.pdf',
      format: PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (PdfPageFormat _) async => bytes,
    );
  }
}
