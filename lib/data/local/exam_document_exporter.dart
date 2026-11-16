import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/services/exam_paper_formatter.dart';
import 'docx/exam_docx_builder.dart';

/// Outcome of an export, reported to the teacher in a snack bar.
class ExamExportResult {
  const ExamExportResult({required this.message, this.path, this.shared = false});

  final String message;

  /// Absolute path of the written file, when one was produced.
  final String? path;

  /// True when the file was handed to the system share sheet (phone).
  final bool shared;
}

/// Signature of the platform save/share step, replaceable in the UI tests.
typedef ExamDocumentExport = Future<ExamExportResult> Function(
  Uint8List bytes,
  String fileName,
);

/// Writes the Word file where the teacher can reach it, offline.
///
/// On Android the document is written to the cache directory and handed to the
/// system share sheet (Files, WhatsApp, Drive, Word…). On Windows it is written
/// to the user's Documents folder, which the file manager already shows.
abstract final class ExamDocumentExporter {
  static Future<ExamExportResult> export(Uint8List bytes, String fileName) async {
    final name = fileName.trim().isEmpty ? 'mirsam-exam.docx' : sanitizeExamFileName(fileName);
    final safeName = name.toLowerCase().endsWith('.docx') ? name : '$name.docx';

    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: ExamDocxBuilder.mimeType)],
        subject: safeName,
      );
      return ExamExportResult(
        message: 'تم تجهيز ملف الوورد: $safeName',
        path: file.path,
        shared: true,
      );
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}${Platform.pathSeparator}$safeName');
    await file.writeAsBytes(bytes, flush: true);
    return ExamExportResult(
      message: 'حُفظ ملف الوورد في: ${file.path}',
      path: file.path,
    );
  }
}
