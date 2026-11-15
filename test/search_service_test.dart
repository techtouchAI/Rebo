import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/services/search_service.dart';

import 'test_support.dart';

void main() {
  late Library library;
  late SearchService search;

  setUpAll(() async {
    library = await ensureLibrary();
    search = SearchService(library);
  });

  test('the index covers units, lessons, terms and plates', () {
    expect(search.indexSize, greaterThanOrEqualTo(50));
  });

  test('finds units by a curriculum term', () {
    final hits = search.search('المنظور');
    expect(hits, isNotEmpty);
    expect(hits.any((hit) => hit.type == SearchHitType.unit), isTrue);
    expect(hits.any((hit) => hit.title.contains('التعبير الفني')), isTrue);
    expect(hits.any((hit) => hit.type == SearchHitType.term), isTrue);
  });

  test('search ignores hamza and diacritics differences', () {
    final withHamza = search.search('الألوان');
    final withoutHamza = search.search('الالوان');
    expect(withHamza.length, withoutHamza.length);
    expect(withHamza, isNotEmpty);
  });

  test('multi word queries keep ranking the best match first', () {
    final broad = search.search('الزخرفة');
    final narrow = search.search('الزخرفة النباتية');
    expect(broad, isNotEmpty);
    expect(narrow, isNotEmpty);
    expect(
      narrow.any((hit) => hit.title.contains('التصميم والزخرفة')),
      isTrue,
      reason: 'the ornament unit must rank for the ornament query',
    );
    expect(search.search('الزخرفة', limit: 2).length, 2);
  });

  test('finds glossary terms and the theatre section', () {
    final terms = search.search('التكرار');
    expect(terms.any((hit) => hit.type == SearchHitType.term), isTrue);
    final theatre = search.search('الأنشطة المسرحية');
    expect(
      theatre.any((hit) => hit.type == SearchHitType.unit && hit.title.contains('المسرحية')),
      isTrue,
    );
    expect(theatre.any((hit) => hit.type == SearchHitType.plate), isFalse);
  });

  test('finds the topic drawings of the booklet', () {
    // Every unit, lesson, term, plate and topic drawing is indexed once.
    expect(
      search.indexSize,
      library.units.length +
          library.lessons.length +
          library.glossary.length +
          library.plates.length +
          library.drawings.length,
    );
    final hits = search.search('التوزيع النجمي');
    expect(hits.any((hit) => hit.type == SearchHitType.drawing), isTrue);
    final drawing = hits.firstWhere((hit) => hit.type == SearchHitType.drawing);
    expect(drawing.title.contains('بالتوزيع النجمي'), isTrue);
    expect(drawing.subtitle.contains('قواعد التصميم الزخرفي'), isTrue);
    expect(hits.any((hit) => hit.type == SearchHitType.plate), isFalse);
  });

  test('a grade filter keeps the drawings of the other grades out', () {
    final filtered = SearchService(library, unitFilter: <String>{
      for (final unit in library.unitsOf('g3')) unit.id,
    });
    final hits = filtered.search('الضوء والظل');
    expect(hits.any((hit) => hit.type == SearchHitType.drawing), isTrue);
    expect(
      hits.where((hit) => hit.type == SearchHitType.drawing).every(
            (hit) => library.drawings
                .firstWhere((TopicDrawing drawing) => drawing.id == hit.id)
                .unitId
                .startsWith('g3'),
          ),
      isTrue,
    );
  });

  test('empty queries return nothing', () {
    expect(search.search('   '), isEmpty);
    expect(search.search(''), isEmpty);
  });

  test('returns no invented content', () {
    expect(search.search('زقزقزق'), isEmpty);
    expect(search.search('qqq'), isEmpty);
  });
}
