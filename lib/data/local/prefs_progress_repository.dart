import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/progress.dart';
import '../../domain/repositories/progress_repository.dart';

/// Stores the reading state as a single JSON string in shared preferences.
class PrefsProgressRepository implements ProgressRepository {
  const PrefsProgressRepository();

  static const String storageKey = 'mirsam.progress.v1';

  @override
  Future<ReadingProgress> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return ReadingProgress();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final progress = ReadingProgress.fromJson(decoded);
      // A document migrated from an older version is written back once, so the
      // migration never runs twice and the new size is stable.
      final savedVersion = (decoded['version'] as num?)?.toInt() ?? 0;
      if (savedVersion < readingProgressVersion) {
        await prefs.setString(storageKey, jsonEncode(progress.toJson()));
      }
      return progress;
    } on FormatException {
      return ReadingProgress();
    }
  }

  @override
  Future<void> save(ReadingProgress progress) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(progress.toJson()));
  }
}
