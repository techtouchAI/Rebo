import '../../core/utils/arabic_text.dart';
import '../models/library.dart';

enum SearchHitType { unit, lesson, term, plate }

/// A single search result, already prepared for display.
class SearchHit {
  const SearchHit({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.snippet,
  });

  final SearchHitType type;
  final String id;
  final String title;
  final String subtitle;
  final String snippet;

  String get typeLabel {
    switch (type) {
      case SearchHitType.unit:
        return 'وحدة';
      case SearchHitType.lesson:
        return 'درس تطبيقي';
      case SearchHitType.term:
        return 'مصطلح';
      case SearchHitType.plate:
        return 'لوحة';
    }
  }
}

/// Offline full-text search over the loaded library.
///
/// The index is built once at start-up from the same JSON that feeds the
/// reader, therefore a query can never return content that is not in the app.
class SearchService {
  SearchService(this.library, {this.unitFilter}) {
    _buildIndex();
  }

  final Library library;

  /// When set, only entries of these units (plus the shared lesson plans) are
  /// indexed — the grade picker uses it to keep the search inside one grade.
  final Set<String>? unitFilter;

  final List<_IndexEntry> _index = <_IndexEntry>[];

  void _buildIndex() {
    for (final unit in library.units) {
      if (unitFilter != null && !unitFilter!.contains(unit.id)) {
        continue;
      }
      _index.add(_IndexEntry(
        type: SearchHitType.unit,
        id: unit.id,
        title: unit.displayTitle,
        subtitle: unit.isIntroduction ? 'مدخل' : unit.grade,
        haystack: normalizeArabic(unit.searchableText),
        text: unit.searchableText,
      ));
    }
    for (final lesson in library.lessons) {
      _index.add(_IndexEntry(
        type: SearchHitType.lesson,
        id: lesson.id,
        title: lesson.title,
        subtitle: 'دروس تطبيقية',
        haystack: normalizeArabic(lesson.searchableText),
        text: lesson.searchableText,
      ));
    }
    for (final term in library.glossary) {
      if (unitFilter != null && !unitFilter!.contains(term.unitId)) {
        continue;
      }
      final unit = library.unitById(term.unitId);
      _index.add(_IndexEntry(
        type: SearchHitType.term,
        id: term.id,
        title: term.term,
        subtitle: unit?.displayTitle ?? 'مصطلح فني',
        haystack: normalizeArabic('${term.term} ${term.definition}'),
        text: term.definition,
      ));
    }
    for (final plate in library.plates) {
      if (unitFilter != null && !unitFilter!.contains(plate.unitId)) {
        continue;
      }
      _index.add(_IndexEntry(
        type: SearchHitType.plate,
        id: plate.id,
        title: plate.title,
        subtitle: plate.grade,
        haystack: normalizeArabic('${plate.title} ${plate.caption} ${plate.grade}'),
        text: plate.caption,
      ));
    }
  }

  int get indexSize => _index.length;

  List<SearchHit> search(String query, {int limit = 40}) {
    final tokens = tokenizeQuery(query);
    if (tokens.isEmpty) {
      return const <SearchHit>[];
    }
    final scored = <_ScoredHit>[];
    for (final entry in _index) {
      var matches = 0;
      for (final token in tokens) {
        if (entry.haystack.contains(token)) {
          matches++;
        }
      }
      if (matches == 0) {
        continue;
      }
      final titleMatch = tokens.any((token) => normalizeArabic(entry.title).contains(token));
      final score = matches * 10 + (titleMatch ? 25 : 0) + (matches == tokens.length ? 15 : 0);
      scored.add(_ScoredHit(entry: entry, score: score));
    }
    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored
        .take(limit)
        .map((item) => SearchHit(
              type: item.entry.type,
              id: item.entry.id,
              title: item.entry.title,
              subtitle: item.entry.subtitle,
              snippet: snippetFor(item.entry.text, tokens),
            ))
        .toList(growable: false);
  }
}

class _IndexEntry {
  const _IndexEntry({
    required this.type,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.haystack,
    required this.text,
  });

  final SearchHitType type;
  final String id;
  final String title;
  final String subtitle;
  final String haystack;
  final String text;
}

class _ScoredHit {
  const _ScoredHit({required this.entry, required this.score});

  final _IndexEntry entry;
  final int score;
}
