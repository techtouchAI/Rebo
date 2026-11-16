import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/prefs_progress_repository.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The repository is the only place that talks to the platform store, so the
/// migration from the previous default (100 %) to the new one (80 %) is
/// verified here against real stored JSON.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const repository = PrefsProgressRepository();

  test('migrates a document written before the new default and stores it', () async {
    // What a build that started at 100 % wrote: no version marker.
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefsProgressRepository.storageKey: jsonEncode(<String, dynamic>{
        'textScale': 1.0,
        'themeMode': 'dark',
        'gradeId': 'g2',
        'readUnits': <String>['g2-u1'],
      }),
    });

    final progress = await repository.load();
    expect(progress.textScale, defaultTextScale);
    expect(progress.textScale, 0.8);
    // Nothing else is lost by the migration.
    expect(progress.themeMode, AppThemeMode.dark);
    expect(progress.gradeId, 'g2');
    expect(progress.readUnits, <String>{'g2-u1'});

    // The migrated document is written back with the version marker.
    final prefs = await SharedPreferences.getInstance();
    final rewritten =
        jsonDecode(prefs.getString(PrefsProgressRepository.storageKey)!)
            as Map<String, dynamic>;
    expect(rewritten['version'], readingProgressVersion);
    expect(rewritten['textScale'], defaultTextScale);
  });

  test('keeps a size chosen after the migration', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefsProgressRepository.storageKey: jsonEncode(<String, dynamic>{
        'version': readingProgressVersion,
        'textScale': 1.1,
      }),
    });

    final progress = await repository.load();
    expect(progress.textScale, 1.1);
  });

  test('starts at 80 per cent when nothing is stored', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final progress = await repository.load();
    expect(progress.textScale, defaultTextScale);
  });

  test('falls back to the starting size on a corrupt document', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PrefsProgressRepository.storageKey: 'not json',
    });
    final progress = await repository.load();
    expect(progress.textScale, defaultTextScale);
  });
}
