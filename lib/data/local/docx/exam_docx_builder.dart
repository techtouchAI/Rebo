/// Builds the Word document of an exam paper.
///
/// The output reproduces the official paper of the project page for page: the
/// three-column header table, the grade table (س1، س2، س3، العملي، المجموع),
/// the theoretical section in the order true/false → choice → enumeration, the
/// practical section and the closing line with the teacher's name. Page setup
/// (A4, 12.7 mm top margin, 12.7 mm sides, right-to-left section) is copied
/// from the source document.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../../domain/services/exam_paper_formatter.dart';
import 'stored_zip_writer.dart';

abstract final class ExamDocxBuilder {
  /// MIME type used when the file is shared from the phone.
  static const String mimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  /// The complete `.docx` package as bytes.
  static Uint8List build(ExamPaper paper) {
    if (!paper.isComplete) {
      throw ArgumentError('The exam paper is incomplete: ${paper.issues.join(' / ')}');
    }
    final parts = <String, List<int>>{
      '[Content_Types].xml': utf8.encode(_contentTypes),
      '_rels/.rels': utf8.encode(_packageRels),
      'docProps/core.xml': utf8.encode(_coreProperties),
      'docProps/app.xml': utf8.encode(_applicationProperties),
      'word/document.xml': utf8.encode(documentXml(paper)),
      'word/_rels/document.xml.rels': utf8.encode(_documentRels),
      'word/styles.xml': utf8.encode(_stylesXml(paper.typography)),
      'word/settings.xml': utf8.encode(_settingsXml),
    };
    return buildStoredZip(parts);
  }

  /// `word/document.xml` only, exposed for the regression tests.
  static String documentXml(ExamPaper paper) => _DocumentWriter(paper).build();

  static const String _contentTypes =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" '
      'ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '<Override PartName="/word/styles.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
      '<Override PartName="/word/settings.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
      '<Override PartName="/docProps/core.xml" '
      'ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>'
      '<Override PartName="/docProps/app.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>'
      '</Types>';

  static const String _packageRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" '
      'Target="docProps/core.xml"/>'
      '<Relationship Id="rId3" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" '
      'Target="docProps/app.xml"/>'
      '</Relationships>';

  static const String _documentRels =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId2" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" '
      'Target="styles.xml"/>'
      '<Relationship Id="rId4" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" '
      'Target="settings.xml"/>'
      '</Relationships>';

  static const String _coreProperties =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<cp:coreProperties '
      'xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" '
      'xmlns:dc="http://purl.org/dc/elements/1.1/" '
      'xmlns:dcterms="http://purl.org/dc/terms/" '
      'xmlns:dcmitype="http://purl.org/dc/dcmitype/" '
      'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">'
      '<dc:title>اسئلة الامتحان</dc:title>'
      '<dc:creator>مِرسم</dc:creator>'
      '<cp:lastModifiedBy>مِرسم</cp:lastModifiedBy>'
      '<dcterms:created xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:created>'
      '<dcterms:modified xsi:type="dcterms:W3CDTF">2026-01-01T00:00:00Z</dcterms:modified>'
      '</cp:coreProperties>';

  static const String _applicationProperties =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Properties '
      'xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" '
      'xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes">'
      '<Application>مِرسم</Application>'
      '</Properties>';

  static const String _settingsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
      '<w:zoom w:percent="100"/>'
      '<w:defaultTabStop w:val="708"/>'
      '<w:characterSpacingControl w:val="doNotCompress"/>'
      '<w:compat/>'
      '</w:settings>';

  static String _stylesXml(ExamPaperTypography typography) {
    final family = _escapeXml(typography.font.family);
    final line = typography.lineTwips;
    return '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="$family" w:hAnsi="$family" w:cs="$family"/>'
        '<w:sz w:val="28"/><w:szCs w:val="28"/>'
        '<w:lang w:val="ar-IQ" w:bidi="ar-IQ"/>'
        '</w:rPr></w:rPrDefault>'
        '<w:pPrDefault><w:pPr>'
        '<w:spacing w:after="0" w:line="$line" w:lineRule="auto"/>'
        '</w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/></w:style>'
        '</w:styles>';
  }

  /// Escapes text for an XML text node or attribute value.
  static String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}

/// A single styled text run of a paragraph.
class _Run {
  const _Run(this.text, {required this.size, this.bold = false});

  final String text;

  /// Size in half-points, as stored by Word.
  final int size;
  final bool bold;
}

/// Emits the WordprocessingML of the document body.
class _DocumentWriter {
  _DocumentWriter(this.paper)
      : typography = paper.typography,
        _family = ExamDocxBuilder._escapeXml(paper.typography.font.family);

  final ExamPaper paper;
  final ExamPaperTypography typography;
  final String _family;
  final StringBuffer _buffer = StringBuffer();

  String build() {
    _buffer
      ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..write(
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">',
      )
      ..write('<w:body>');
    _writeHeaderTable();
    _writeRule();
    _writeGradeTable();
    _writeRule();
    _writeTheorySection();
    _writePracticalSection();
    _writeRule();
    _writeFooter();
    _writeSectionProperties();
    _buffer.write('</w:body></w:document>');
    return _buffer.toString();
  }

  // ------------------------------------------------------------------ text ---

  String _runXml(_Run run) {
    final text = ExamDocxBuilder._escapeXml(_normalizeText(run.text));
    final buffer = StringBuffer()
      ..write('<w:r><w:rPr>')
      ..write('<w:rFonts w:ascii="$_family" w:hAnsi="$_family" w:cs="$_family"/>');
    if (run.bold) {
      buffer.write('<w:b/><w:bCs/>');
    }
    buffer
      ..write('<w:sz w:val="${run.size}"/><w:szCs w:val="${run.size}"/>')
      ..write('<w:rtl/><w:lang w:bidi="ar-IQ"/>')
      ..write('</w:rPr><w:t xml:space="preserve">$text</w:t></w:r>');
    return buffer.toString();
  }

  String _paragraphXml(
    List<_Run> runs, {
    bool center = false,
    bool keepNext = false,
    int after = 0,
    int? line,
  }) {
    // A null line means "the spacing chosen for the paper"; the empty
    // paragraphs that separate the questions always stay compact.
    final spacing = line ?? typography.lineTwips;
    final buffer = StringBuffer('<w:p><w:pPr>');
    if (keepNext) {
      buffer.write('<w:keepNext/>');
    }
    buffer
      ..write('<w:bidi/>')
      ..write('<w:spacing w:after="$after" w:line="$spacing" w:lineRule="auto"/>');
    if (center) {
      buffer.write('<w:jc w:val="center"/>');
    }
    buffer.write('</w:pPr>');
    for (final _Run run in runs) {
      buffer.write(_runXml(run));
    }
    buffer.write('</w:p>');
    return buffer.toString();
  }

  /// Newlines cannot appear inside a `w:t`; user text keeps its words.
  static String _normalizeText(String value) {
    return value
        .replaceAll(RegExp(r'[\u0000-\u0008\u000B\u000C\u000E-\u001F]'), '')
        .replaceAll(RegExp(r'\r\n?|\n'), ' ');
  }

  // ---------------------------------------------------------------- tables ---

  static const String _noBorders =
      '<w:tblBorders>'
      '<w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:bottom w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '<w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>'
      '</w:tblBorders>';

  static const String _singleBorders =
      '<w:tblBorders>'
      '<w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '<w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>'
      '</w:tblBorders>';

  String _cellXml(int width, List<String> paragraphs, {int? span}) {
    final buffer = StringBuffer()
      ..write('<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>');
    if (span != null && span > 1) {
      buffer.write('<w:gridSpan w:val="$span"/>');
    }
    buffer.write('</w:tcPr>');
    for (final String paragraph in paragraphs) {
      buffer.write(paragraph);
    }
    if (paragraphs.isEmpty) {
      buffer.write(_paragraphXml(const <_Run>[]));
    }
    buffer.write('</w:tc>');
    return buffer.toString();
  }

  void _writeHeaderTable() {
    final info = paper.info;
    final size = typography.headerHalfPoints;
    final schoolCell = _cellXml(2693, <String>[
      _paragraphXml(<_Run>[_Run('ادارة', size: size, bold: true)], center: true),
      _paragraphXml(<_Run>[_Run(info.school, size: size, bold: true)], center: true),
      _paragraphXml(const <_Run>[], center: true),
    ]);
    final examCell = _cellXml(5245, <String>[
      _paragraphXml(<_Run>[_Run(info.examTitleLine, size: size, bold: true)], center: true),
      _paragraphXml(<_Run>[_Run(info.yearLine, size: size, bold: true)], center: true),
      _paragraphXml(<_Run>[_Run('التربية الفنية', size: size, bold: true)], center: true),
    ]);
    final studentCell = _cellXml(2977, <String>[
      _paragraphXml(<_Run>[_Run('الاسم :', size: size, bold: true)]),
      _paragraphXml(<_Run>[_Run(info.classLine, size: size, bold: true)]),
      _paragraphXml(<_Run>[_Run('الرقم الامتحاني :', size: size, bold: true)]),
    ]);
    _buffer.write(
      '<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="10915" w:type="dxa"/>'
      '<w:tblInd w:w="-199" w:type="dxa"/>$_noBorders<w:tblLayout w:type="fixed"/>'
      '</w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="2693"/><w:gridCol w:w="5245"/>'
      '<w:gridCol w:w="2977"/></w:tblGrid>'
      '<w:tr><w:trPr><w:trHeight w:val="1131"/></w:trPr>'
      '$schoolCell$examCell$studentCell'
      '</w:tr></w:tbl>',
    );
  }

  void _writeGradeTable() {
    final size = typography.bodyHalfPoints;
    String head(String text) => _cellXml(
      1334,
      <String>[_paragraphXml(<_Run>[_Run(text, size: size, bold: true)], center: true)],
    );
    String label(String text) => _cellXml(
      1334,
      <String>[_paragraphXml(<_Run>[_Run(text, size: size, bold: true)], center: true)],
    );
    String blank(int width) =>
        _cellXml(width, <String>[_paragraphXml(const <_Run>[])]);

    final buffer = StringBuffer()
      ..write(
        '<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="0" w:type="auto"/>'
        '<w:jc w:val="center"/>$_singleBorders<w:tblLayout w:type="fixed"/>'
        '</w:tblPr>'
        '<w:tblGrid><w:gridCol w:w="1334"/><w:gridCol w:w="1334"/>'
        '<w:gridCol w:w="1334"/><w:gridCol w:w="1447"/>'
        '<w:gridCol w:w="1221"/></w:tblGrid>',
      )
      ..write(
        '<w:tr><w:trPr><w:trHeight w:val="196"/></w:trPr>'
        '${head('رقم السؤال')}${head('الدرجة رقما')}${head('الدرجة كتابة')}'
        '${_cellXml(1447, <String>[_paragraphXml(<_Run>[_Run('اسم المصحح', size: size, bold: true)], center: true)])}'
        '${_cellXml(1221, <String>[_paragraphXml(<_Run>[_Run('اسم المدقق', size: size, bold: true)], center: true)])}'
        '</w:tr>',
      );

    String scoreRow(String title) =>
        '<w:tr><w:trPr><w:trHeight w:val="196"/></w:trPr>'
        '${label(title)}${blank(1334)}${blank(1334)}${blank(1447)}${blank(1221)}'
        '</w:tr>';

    buffer
      ..write(scoreRow('س1'))
      ..write(scoreRow('س2'))
      ..write(scoreRow('س3'))
      ..write(
        '<w:tr><w:trPr><w:trHeight w:val="196"/></w:trPr>'
        '${_cellXml(6670, <String>[_paragraphXml(<_Run>[_Run('العملـــــي', size: size, bold: true)], center: true)], span: 5)}'
        '</w:tr>',
      )
      ..write(scoreRow('س1'))
      ..write(scoreRow('س2'))
      ..write(scoreRow('س3'))
      ..write(scoreRow('المجموع'))
      ..write('</w:tbl>');
    _buffer.write(buffer.toString());
  }

  void _writeRule() {
    _buffer.write(
      _paragraphXml(
        <_Run>[_Run('_' * 58, size: typography.ruleHalfPoints, bold: true)],
        center: true,
        line: 240,
      ),
    );
  }

  // --------------------------------------------------------------- content ---

  void _writeTheorySection() {
    if (!paper.hasTheory) {
      return;
    }
    final headingSize = typography.headingHalfPoints;
    final bodySize = typography.bodyHalfPoints;
    _buffer.write(
      _paragraphXml(<_Run>[
        _Run(paper.theoryHeadingLine, size: headingSize, bold: true),
      ], keepNext: true),
    );

    var questionIndex = 0;
    for (final ExamTheoryQuestion question in paper.theory) {
      if (question.isEmpty) {
        continue;
      }
      _buffer.write(
        _paragraphXml(<_Run>[
          _Run(examTheoryHeading(question, questionIndex), size: bodySize, bold: true),
        ], keepNext: true),
      );
      questionIndex++;
      var itemIndex = 0;
      for (final ExamTheoryItem item in question.items) {
        itemIndex++;
        _buffer.write(
          _paragraphXml(<_Run>[
            _Run('$itemIndex- ${examTheoryItemText(item)}', size: bodySize),
          ]),
        );
        if (item.kind == QuestionKind.open) {
          for (final String line in examAnswerLines(question)) {
            _buffer.write(_paragraphXml(<_Run>[_Run(line, size: bodySize)]));
          }
        }
      }
      _buffer.write(_paragraphXml(const <_Run>[], line: 240));
    }
  }

  void _writePracticalSection() {
    if (!paper.hasPractical) {
      return;
    }
    final headingSize = typography.headingHalfPoints;
    final bodySize = typography.bodyHalfPoints;
    _buffer.write(
      _paragraphXml(<_Run>[
        _Run(paper.practicalHeadingLine, size: headingSize, bold: true),
      ], keepNext: true),
    );
    for (var i = 0; i < paper.practical.length; i++) {
      final ExamPracticalQuestion question = paper.practical[i];
      _buffer.write(
        _paragraphXml(<_Run>[
          _Run('${examQuestionNumber(i)}: ${question.prompt.trim()}', size: bodySize),
        ], after: 40),
      );
    }
  }

  void _writeFooter() {
    final size = typography.bodyHalfPoints;
    final wishes = _cellXml(6000, <String>[
      _paragraphXml(<_Run>[_Run('تمنياتي لكم بالتوفيق والنجاح', size: size, bold: true)], center: true),
    ]);
    final teacher = _cellXml(4466, <String>[
      _paragraphXml(<_Run>[_Run('مدرس المادة', size: size, bold: true)], center: true),
      _paragraphXml(<_Run>[_Run(paper.info.teacherName.trim(), size: size, bold: true)], center: true),
    ]);
    _buffer.write(
      '<w:tbl><w:tblPr><w:bidiVisual/><w:tblW w:w="0" w:type="auto"/>'
      '$_noBorders<w:tblLayout w:type="fixed"/></w:tblPr>'
      '<w:tblGrid><w:gridCol w:w="6000"/><w:gridCol w:w="4466"/></w:tblGrid>'
      '<w:tr>$wishes$teacher</w:tr></w:tbl>',
    );
  }

  void _writeSectionProperties() {
    _buffer.write(
      '<w:sectPr><w:pgSz w:w="11906" w:h="16838"/>'
      '<w:pgMar w:top="426" w:right="720" w:bottom="720" w:left="720" '
      'w:header="708" w:footer="708" w:gutter="0"/>'
      '<w:cols w:space="708"/><w:bidi/><w:rtlGutter/>'
      '<w:docGrid w:linePitch="360"/></w:sectPr>',
    );
  }
}
