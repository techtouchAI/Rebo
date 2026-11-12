import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/models/library.dart';
import '../../domain/repositories/content_repository.dart';

/// Loads `assets/content/*.json` from the application bundle.
class AssetContentRepository implements ContentRepository {
  const AssetContentRepository({this.loader = _loadFromBundle});

  /// Injectable so that tests can read the very same files from disk.
  final Future<String> Function(String path) loader;

  static const String curriculumPath = 'assets/content/curriculum.json';
  static const String lessonsPath = 'assets/content/lessons.json';
  static const String glossaryPath = 'assets/content/glossary.json';
  static const String platesPath = 'assets/content/plates.json';

  static Future<String> _loadFromBundle(String path) => rootBundle.loadString(path);

  @override
  Future<Library> load() async {
    final results = await Future.wait<String>(<Future<String>>[
      loader(curriculumPath),
      loader(lessonsPath),
      loader(glossaryPath),
      loader(platesPath),
    ]);
    return Library.fromJson(
      jsonDecode(results[0]) as Map<String, dynamic>,
      jsonDecode(results[1]) as Map<String, dynamic>,
      jsonDecode(results[2]) as Map<String, dynamic>,
      jsonDecode(results[3]) as Map<String, dynamic>,
    );
  }
}
