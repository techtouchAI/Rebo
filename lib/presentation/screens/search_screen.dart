import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/empty_state.dart';
import '../../domain/services/search_service.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';
import '../widgets/text_scale_controls.dart';

/// Instant search across units, lessons, terms and plates.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<SearchHit> _results = const <SearchHit>[];
  SearchHitType? _typeFilter;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value, AppState state) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 140), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _query = value;
        _results = state.search.search(value);
      });
    });
  }

  void _applyType(SearchHitType? type, AppState state) {
    setState(() {
      _typeFilter = type;
      _results = state.search.search(_query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final visible = _typeFilter == null
        ? _results
        : _results.where((SearchHit hit) => hit.type == _typeFilter).toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('البحث في المحتوى'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: (String value) => _onChanged(value, state),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن موضوع، مصطلح، أو لوحة…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح',
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _query = '';
                                _results = const <SearchHit>[];
                              });
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: <Widget>[
                    ChoiceChip(
                      label: const Text('الكل'),
                      selected: _typeFilter == null,
                      onSelected: (_) => _applyType(null, state),
                    ),
                    ChoiceChip(
                      label: const Text('وحدات'),
                      selected: _typeFilter == SearchHitType.unit,
                      onSelected: (_) => _applyType(SearchHitType.unit, state),
                    ),
                    ChoiceChip(
                      label: const Text('دروس'),
                      selected: _typeFilter == SearchHitType.lesson,
                      onSelected: (_) => _applyType(SearchHitType.lesson, state),
                    ),
                    ChoiceChip(
                      label: const Text('مصطلحات'),
                      selected: _typeFilter == SearchHitType.term,
                      onSelected: (_) => _applyType(SearchHitType.term, state),
                    ),
                    ChoiceChip(
                      label: const Text('لوحات'),
                      selected: _typeFilter == SearchHitType.plate,
                      onSelected: (_) => _applyType(SearchHitType.plate, state),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_query.trim().isEmpty)
                  EmptyState(
                    icon: Icons.search,
                    title: 'ابحث في كامل المحتوى',
                    message: 'يشمل البحث عناوين الوحدات والموضوعات والمصطلحات واللوحات، '
                        'ويعمل دون اتصال بالإنترنت.',
                  )
                else if (visible.isEmpty)
                  EmptyState(
                    icon: Icons.search_off,
                    title: 'لا توجد نتائج',
                    message: 'جرّب كلمة أخرى أو أزل عامل التصفية.',
                  )
                else ...<Widget>[
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      '${visible.length} نتيجة',
                      style: theme.textTheme.labelMedium,
                    ),
                  ),
                  ...visible.map(
                    (SearchHit hit) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _HitTile(
                        hit: hit,
                        onTap: () => _openHit(context, state, hit),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openHit(BuildContext context, AppState state, SearchHit hit) {
    switch (hit.type) {
      case SearchHitType.unit:
        final unit = state.library.unitById(hit.id);
        if (unit != null) {
          AppRoutes.openUnit(context, unit);
        }
        break;
      case SearchHitType.lesson:
        final lesson = state.library.lessonById(hit.id);
        if (lesson != null) {
          AppRoutes.openLesson(context, lesson);
        }
        break;
      case SearchHitType.term:
        AppRoutes.openGlossary(context);
        break;
      case SearchHitType.plate:
        AppRoutes.openPlateById(context, hit.id);
        break;
    }
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.onTap});

  final SearchHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = switch (hit.type) {
      SearchHitType.unit => Icons.menu_book_outlined,
      SearchHitType.lesson => Icons.edit_note_outlined,
      SearchHitType.term => Icons.translate,
      SearchHitType.plate => Icons.image_outlined,
    };
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.md),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(hit.title, style: theme.textTheme.titleMedium),
                        ),
                        Text(hit.typeLabel, style: theme.textTheme.labelMedium),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(hit.subtitle, style: theme.textTheme.labelMedium),
                    if (hit.snippet.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        hit.snippet,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
