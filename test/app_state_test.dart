import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mirsam/data/local/memory_progress_repository.dart';
import 'package:mirsam/domain/models/library.dart';
import 'package:mirsam/domain/models/progress.dart';
import 'package:mirsam/domain/services/search_service.dart';
import 'package:mirsam/presentation/state/app_state.dart';

import 'test_support.dart';

void main() {
  late Library library;

  setUpAll(() async {
    library = await ensureLibrary();
  });

  test('reading progress survives a JSON round trip', () {
    final progress = ReadingProgress(
      favorites: <String>{'g1-u1'},
      readUnits: <String>{'g1-u1', 'g1-u2'},
      lastUnitId: 'g1-u2',
      scrollOffsets: <String, double>{'g1-u2': 320.5},
      quizScores: <String, int>{'g1-u1': 5},
      themeMode: AppThemeMode.dark,
      textScale: 1.2,
      gradeId: 'g3',
    );
    final restored = ReadingProgress.fromJson(
      jsonDecode(jsonEncode(progress.toJson())) as Map<String, dynamic>,
    );
    expect(restored.favorites, progress.favorites);
    expect(restored.readUnits, progress.readUnits);
    expect(restored.lastUnitId, 'g1-u2');
    expect(restored.scrollOffsets['g1-u2'], 320.5);
    expect(restored.quizScores['g1-u1'], 5);
    expect(restored.themeMode, AppThemeMode.dark);
    expect(restored.textScale, 1.2);
    expect(restored.gradeId, 'g3');
  });

  test('marking a unit as read updates progress, last read and storage', () async {
    final repository = MemoryProgressRepository();
    final state = buildState(library: library, repository: repository);
    expect(state.overallProgress, 0);

    await state.markRead('g1-u1');
    expect(state.isRead('g1-u1'), isTrue);
    expect(state.lastReadUnitId, 'g1-u1');
    expect(state.lastReadUnit?.id, 'g1-u1');
    expect(state.overallProgress, greaterThan(0));
    expect(repository.lastSaved?.isRead('g1-u1'), isTrue);
  });

  test('favorites toggle on and off', () async {
    final state = buildState(library: library, progress: ReadingProgress(gradeId: 'g2'));
    await state.toggleFavorite('g2-u3');
    expect(state.isFavorite('g2-u3'), isTrue);
    expect(state.favoriteUnits.map((unit) => unit.id), contains('g2-u3'));
    await state.toggleFavorite('g2-u3');
    expect(state.isFavorite('g2-u3'), isFalse);
  });

  test('the best quiz score is kept', () async {
    final state = buildState(library: library);
    await state.recordQuizScore('g1-u1', 4);
    await state.recordQuizScore('g1-u1', 2);
    expect(state.quizScoreOf('g1-u1'), 4);
    await state.recordQuizScore('g1-u1', 6);
    expect(state.quizScoreOf('g1-u1'), 6);
  });

  test('text scale is clamped and theme mode is persisted', () async {
    final repository = MemoryProgressRepository();
    final state = buildState(library: library, repository: repository);
    await state.setTextScale(3);
    expect(state.textScale, AppState.MaxTextScale);
    await state.setTextScale(0.1);
    expect(state.textScale, AppState.MinTextScale);
    await state.setThemeMode(AppThemeMode.dark);
    expect(repository.lastSaved?.themeMode, AppThemeMode.dark);
  });

  test('choosing a grade limits units, plates, glossary, search and order', () async {
    final repository = MemoryProgressRepository();
    final state = buildState(library: library, progress: ReadingProgress(), repository: repository);
    expect(state.hasGrade, isFalse);
    expect(state.gradeSections.length, 3);

    await state.setGrade('g2');

    expect(state.hasGrade, isTrue);
    expect(state.gradeId, 'g2');
    expect(state.gradeTitle, 'الصف الثاني المتوسط');
    expect(state.visibleUnits.every((LearningUnit unit) => unit.sectionId == 'g2'), isTrue);
    expect(state.visibleUnitIds, isNot(contains('g1-u1')));
    expect(state.totalUnits, 4);
    expect(state.visiblePlates.any((Plate plate) => plate.unitId.startsWith('g1')), isFalse);
    expect(state.visibleGlossary.any((GlossaryTerm term) => term.unitId.startsWith('g1')), isFalse);
    expect(
      state.search.search('المنظور').where((hit) => hit.type == SearchHitType.unit),
      everyElement(predicate<SearchHit>((hit) => state.visibleUnitIds.contains(hit.id))),
    );
    expect(state.visibleReadingOrder.every(state.visibleUnitIds.contains), isTrue);
    expect(state.visibleSections.any((ContentSection section) => section.id == 'g1'), isFalse);
    expect(repository.lastSaved?.gradeId, 'g2');

    await state.setGrade(null);
    expect(state.hasGrade, isFalse);
    expect(state.visibleUnits.length, library.units.length);
    expect(repository.lastSaved?.gradeId, isNull);
  });

  test('resetting the reading data keeps the chosen grade', () async {
    final state = buildState(library: library, progress: ReadingProgress(gradeId: 'g3'));
    await state.markRead('g3-u1');
    await state.resetProgress();
    expect(state.readUnitsCount, 0);
    expect(state.gradeId, 'g3');
  });

  test('section progress counts only the units of that grade', () async {
    final state = buildState(library: library);
    await state.markRead('g1-u1');
    expect(state.sectionProgress('g1'), closeTo(0.25, 0.0001));
    expect(state.sectionReadCount('g1'), 1);
    expect(state.sectionProgress('g2'), 0);
  });

  test('share text contains the unit title and its topics', () async {
    final state = buildState(library: library);
    final unit = library.unitById('g1-u1')!;
    final text = state.shareTextOfUnit(unit);
    expect(text.contains(unit.title), isTrue);
    expect(text.contains(unit.topics.first.title), isTrue);
    expect(text.contains('مِرسم'), isTrue);
  });

  test('reset clears the local state', () async {
    final state = buildState(library: library);
    await state.markRead('g1-u1');
    await state.toggleFavorite('g1-u2');
    await state.resetProgress();
    expect(state.readUnitsCount, 0);
    expect(state.favoriteUnits, isEmpty);
  });
}
