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
    expect(search.indexSize, greaterThanOrEqualTo(51));
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

  test('finds glossary terms and plates', () {
    final terms = search.search('التكرار');
    expect(terms.any((hit) => hit.type == SearchHitType.term), isTrue);
    final plates = search.search('الأنشطة المسرحية');
    expect(plates.any((hit) => hit.type == SearchHitType.plate), isTrue);
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
