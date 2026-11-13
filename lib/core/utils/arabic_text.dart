/// Text helpers for Arabic content: normalisation for search, reading-time
/// estimation and digit formatting.
library;

const String _diacritics = '\u064b\u064c\u064d\u064e\u064f\u0650\u0651\u0652\u0670';
const String _tatweel = '\u0640';

/// Normalises Arabic text so that search is insensitive to hamza forms,
/// diacritics and tatweel — while the displayed text stays untouched.
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final char = String.fromCharCode(rune);
    if (_diacritics.contains(char) || char == _tatweel) {
      continue;
    }
    switch (char) {
      case 'أ':
      case 'إ':
      case 'آ':
      case 'ٱ':
        buffer.write('ا');
        break;
      case 'ى':
      case 'ئ':
        buffer.write('ي');
        break;
      case 'ؤ':
        buffer.write('و');
        break;
      case 'ة':
        buffer.write('ه');
        break;
      default:
        buffer.write(char.toLowerCase());
    }
  }
  return buffer.toString();
}

/// Splits a query into normalised tokens; short tokens are ignored.
List<String> tokenizeQuery(String query) {
  final normalized = normalizeArabic(query).trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }
  return normalized
      .split(RegExp(r'\s+'))
      .where((token) => token.length >= 2)
      .toList(growable: false);
}

/// Returns the sentence of [text] that contains [token] (or a trimmed slice).
String snippetFor(String text, List<String> tokens, {int maxLength = 170}) {
  if (text.isEmpty) {
    return '';
  }
  final normalizedText = normalizeArabic(text);
  var index = -1;
  for (final token in tokens) {
    index = normalizedText.indexOf(token);
    if (index >= 0) {
      break;
    }
  }
  if (index < 0) {
    return _trim(text, 0, maxLength);
  }
  final start = _sentenceStart(text, index);
  return _trim(text, start, maxLength);
}

int _sentenceStart(String text, int index) {
  final candidates = <String>[r'. ', '؟ ', '! ', '\n'];
  var start = 0;
  for (final marker in candidates) {
    final found = text.lastIndexOf(marker, index);
    if (found > start) {
      start = found + marker.length;
    }
  }
  return start;
}

String _trim(String text, int start, int maxLength) {
  if (text.length <= maxLength) {
    return text.trim();
  }
  final end = (start + maxLength).clamp(0, text.length);
  final slice = text.substring(start.clamp(0, text.length), end).trim();
  return end < text.length ? '$slice…' : slice;
}

/// Renders Western digits as Arabic-Indic digits (used for reading time only;
/// years and page numbers keep their original digits).
String toArabicDigits(String value) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in value.split('')) {
    final index = western.indexOf(char);
    buffer.write(index >= 0 ? eastern[index] : char);
  }
  return buffer.toString();
}

/// Rough reading-time estimate for Arabic prose (~180 words per minute).
String readingTimeLabel(String text) {
  final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
  final minutes = (words / 180).ceil();
  final safeMinutes = minutes < 1 ? 1 : minutes;
  return '${toArabicDigits('$safeMinutes')} د قراءة';
}
