import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/core/utils/arabic_text.dart';

void main() {
  group('normalizeArabic', () {
    test('unifies hamza forms and alef maqsura', () {
      expect(normalizeArabic('ألوان'), normalizeArabic('الوان'));
      expect(normalizeArabic('إبداع'), normalizeArabic('ابداع'));
      expect(normalizeArabic('مصطفى'), normalizeArabic('مصطفي'));
    });

    test('removes diacritics and tatweel', () {
      expect(normalizeArabic('تُستمد'), 'تستمد');
      expect(normalizeArabic('كتـــــاب'), 'كتاب');
    });

    test('is used for tokenising queries', () {
      expect(tokenizeQuery('  المنظور   والظل '), <String>['المنظور', 'والظل']);
      expect(tokenizeQuery('ا'), isEmpty, reason: 'single letters are ignored');
    });
  });

  group('snippetFor', () {
    test('returns the sentence that contains the token', () {
      const text = 'قواعد تساعد على إظهار العمق. تظهر أهمية خط الأرض وخط الأفق.';
      final snippet = snippetFor(text, <String>['الافق']);
      expect(snippet.contains('خط الأفق'), isTrue);
    });

    test('falls back to the beginning of the text', () {
      final snippet = snippetFor('نص لا يحتوي الكلمة', <String>['مفقود']);
      expect(snippet.startsWith('نص'), isTrue);
    });
  });

  group('digits and reading time', () {
    test('converts western digits to Arabic-Indic digits', () {
      expect(toArabicDigits('2026'), '٢٠٢٦');
      expect(toArabicDigits('12 صفحة'), '١٢ صفحة');
    });

    test('reading time is at least one minute', () {
      expect(readingTimeLabel('كلمة'), contains('١'));
      expect(readingTimeLabel(List<String>.filled(400, 'كلمة').join(' ')), contains('٣'));
    });
  });
}
