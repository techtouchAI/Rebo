import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/app.dart';
import 'package:mirsam/core/theme/app_theme.dart';
import 'package:mirsam/data/local/asset_content_repository.dart';
import 'package:mirsam/data/local/memory_progress_repository.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/presentation/state/app_state.dart';

/// Reads the very same JSON files that are bundled in the application.
class FileContentRepository extends AssetContentRepository {
  const FileContentRepository() : super(loader: _readFile);

  static Future<String> _readFile(String path) => File(path).readAsString();
}

Library? _cached;

/// Loaded once per test file, inside `setUpAll` (real asynchronous zone).
Future<Library> ensureLibrary() async {
  _cached ??= await const FileContentRepository().load();
  return _cached!;
}

AppState buildState({
  required Library library,
  ReadingProgress? progress,
  MemoryProgressRepository? repository,
}) {
  return AppState(
    library: library,
    progress: progress ?? ReadingProgress(),
    progressRepository: repository ?? MemoryProgressRepository(),
  );
}

/// The real application widget tree, with an in-memory progress store.
Future<AppState> pumpApplication(
  WidgetTester tester, {
  ReadingProgress? progress,
  Size size = const Size(1280, 900),
}) async {
  final library = await ensureLibrary();
  final state = buildState(library: library, progress: progress);
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: const MirsamApp(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return state;
}

/// A single screen inside a minimal Arabic application shell.
Future<AppState> pumpScreen(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1200, 1600),
  ReadingProgress? progress,
}) async {
  final library = await ensureLibrary();
  final state = buildState(library: library, progress: progress);
  await tester.binding.setSurfaceSize(size);
  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: const <Locale>[Locale('ar')],
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(),
        home: child,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  return state;
}
