import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/exam_profile_repository.dart';

/// Stores the teacher profile as one JSON string in shared preferences.
class PrefsExamProfileRepository implements ExamProfileRepository {
  const PrefsExamProfileRepository();

  static const String storageKey = 'mirsam.exam-profile.v1';

  @override
  Future<ExamProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return const ExamProfile();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return const ExamProfile();
      }
      return ExamProfile.fromJson(decoded);
    } on FormatException {
      return const ExamProfile();
    }
  }

  @override
  Future<void> save(ExamProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(profile.toJson()));
  }
}
