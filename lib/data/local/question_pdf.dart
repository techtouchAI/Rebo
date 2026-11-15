import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/services/question_print_plan.dart';

/// Produces an A4, right-to-left question paper using bundled Arabic fonts.
/// Pages continue naturally if the selected questions cannot fit on one sheet;
/// the requested font sizes are never shrunk and questions are never clipped.
class QuestionPdfBuilder {
  const QuestionPdfBuilder({this.compress = true});

  /// Can be disabled to inspect the generated page content in tests.
  final bool compress;

  static const double bodyFontSize = 12;
  static const double headingFontSize = 14;

  Future<pw.Document> build(
    QuestionPrintPlan plan, {
    required String gradeTitle,
    AssetBundle? assetBundle,
  }) async {
    if (plan.isEmpty) {
      throw ArgumentError('At least one unit with questions must be selected.');
    }

    final bundle = assetBundle ?? rootBundle;
    // PDF's Arabic shaper uses presentation forms, including isolated yeh.
    // These bundled fonts include those glyphs; some UI fonts do not. Await
    // each asset directly because Flutter asset bundles can return a
    // SynchronousFuture, which is not safe to combine with Future.wait.
    final regularFont = await bundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final boldFont = await bundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
    final theme = pw.ThemeData.withFont(
      base: pw.Font.ttf(regularFont),
      bold: pw.Font.ttf(boldFont),
    );
    // The font's default space is very narrow, especially next to Arabic
    // joining forms. A little extra word spacing keeps printed words distinct.
    final bodyStyle = pw.TextStyle(fontSize: bodyFontSize, wordSpacing: 2);
    final headingStyle = pw.TextStyle(
      fontSize: headingFontSize,
      fontWeight: pw.FontWeight.bold,
      wordSpacing: 1.5,
    );
    final document = pw.Document(theme: theme, compress: compress);
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          9 * PdfPageFormat.mm,
          8 * PdfPageFormat.mm,
          9 * PdfPageFormat.mm,
          8 * PdfPageFormat.mm,
        ),
        textDirection: pw.TextDirection.rtl,
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        build: (pw.Context context) {
          final content = <pw.Widget>[
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Align(
                alignment: pw.Alignment.center,
                child: pw.Text('أسئلة $gradeTitle', style: headingStyle),
              ),
            ),
          ];
          for (final section in plan.sections) {
            // Reserve room for the category, unit, and first question line.
            content.add(pw.NewPage(freeSpace: 68));
            content.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 2, bottom: 1),
                child: pw.Text(section.kind.printHeading, style: headingStyle),
              ),
            );
            var number = 0;
            for (final group in section.groups) {
              content.add(pw.NewPage(freeSpace: 42));
              content.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 1),
                  child: pw.Text(group.unit.title, style: headingStyle),
                ),
              );
              for (final question in group.questions) {
                number++;
                content.add(pw.NewPage(freeSpace: 20));
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
