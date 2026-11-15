/// The teacher profile remembered between sessions: it pre-fills the header of
/// the next exam paper so that only the questions change.
library;

import 'exam_paper.dart';

class ExamProfile {
  const ExamProfile({
    this.schoolName = '',
    this.gradeLabel = '',
    this.sectionName = '',
    this.teacherName = '',
    this.typography = const ExamPaperTypography(),
  });

  final String schoolName;
  final String gradeLabel;
  final String sectionName;
  final String teacherName;
  final ExamPaperTypography typography;

  bool get isEmpty =>
      schoolName.trim().isEmpty &&
      gradeLabel.trim().isEmpty &&
      sectionName.trim().isEmpty &&
      teacherName.trim().isEmpty;

  factory ExamProfile.fromJson(Map<String, dynamic> json) {
    return ExamProfile(
      schoolName: json['schoolName'] as String? ?? '',
      gradeLabel: json['gradeLabel'] as String? ?? '',
      sectionName: json['sectionName'] as String? ?? '',
      teacherName: json['teacherName'] as String? ?? '',
      typography: ExamPaperTypography(
        font: _fontFromName(json['font'] as String?),
        headerFontSize: _sizeFromJson(
          json['headerFontSize'],
          ExamPaperTypography.defaultHeaderFontSize,
        ),
        bodyFontSize: _sizeFromJson(
          json['bodyFontSize'],
          ExamPaperTypography.defaultBodyFontSize,
        ),
        headingFontSize: _sizeFromJson(
          json['headingFontSize'],
          ExamPaperTypography.defaultHeadingFontSize,
        ),
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'schoolName': schoolName,
      'gradeLabel': gradeLabel,
      'sectionName': sectionName,
      'teacherName': teacherName,
      'font': typography.font.name,
      'headerFontSize': typography.headerFontSize,
      'bodyFontSize': typography.bodyFontSize,
      'headingFontSize': typography.headingFontSize,
    };
  }

  ExamProfile copyWith({
    String? schoolName,
    String? gradeLabel,
    String? sectionName,
    String? teacherName,
    ExamPaperTypography? typography,
  }) {
    return ExamProfile(
      schoolName: schoolName ?? this.schoolName,
      gradeLabel: gradeLabel ?? this.gradeLabel,
      sectionName: sectionName ?? this.sectionName,
      teacherName: teacherName ?? this.teacherName,
      typography: typography ?? this.typography,
    );
  }

  static ExamPaperFont _fontFromName(String? name) {
    for (final ExamPaperFont font in ExamPaperFont.values) {
      if (font.name == name) {
        return font;
      }
    }
    return ExamPaperFont.traditionalArabic;
  }

  /// A saved size from an older version may be outside the supported range; the
  /// fallback keeps the exported file valid.
  static int _sizeFromJson(Object? value, int fallback) {
    final size = value is int ? value : int.tryParse('${value ?? ''}');
    return ExamPaperTypography.isValidFontSize(size) ? size! : fallback;
  }
}

/// Persistence contract of the exam profile.
abstract interface class ExamProfileRepository {
  Future<ExamProfile> load();

  Future<void> save(ExamProfile profile);
}
