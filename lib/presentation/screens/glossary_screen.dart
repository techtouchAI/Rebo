import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/widgets/app_page.dart';
import '../../domain/models/library.dart';
import '../navigation/app_routes.dart';
import '../state/app_state.dart';

/// Glossary of the technical terms with the definitions of the source.
class GlossaryScreen extends StatelessWidget {
  const GlossaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final terms = state.library.glossary;
    return Scaffold(
      appBar: AppBar(title: const Text('المصطلحات الفنية')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
        children: <Widget>[
          AppPage(
            maxWidth: AppLayout.readingMaxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'تعريفات مختصرة مأخوذة حرفياً من موضوعات الوحدات، مع رابط إلى الوحدة التي وردت فيها.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ...terms.map((GlossaryTerm term) {
                  final unit = state.library.unitById(term.unitId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(term.term, style: theme.textTheme.titleLarge),
                          const SizedBox(height: AppSpacing.xs),
                          Text(term.definition, style: theme.textTheme.bodyLarge),
                          if (unit != null) ...<Widget>[
                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: () => AppRoutes.openUnit(context, unit),
                                icon: const Icon(Icons.arrow_back, size: 16),
                                label: Text(unit.displayTitle),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
