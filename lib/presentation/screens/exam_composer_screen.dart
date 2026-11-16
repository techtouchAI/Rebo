import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/theme/dimens.dart';
import '../../core/utils/arabic_text.dart';
import '../../core/widgets/app_page.dart';
import '../../data/local/docx/exam_docx_builder.dart';
import '../../data/local/exam_document_exporter.dart';
import '../../data/local/prefs_exam_profile_repository.dart';
import '../../data/local/prefs_exam_question_bank_repository.dart';
import '../../domain/models/exam_question_bank.dart';
import '../../domain/repositories/exam_question_bank_repository.dart';
import '../../domain/models/exam_paper.dart';
import '../../domain/repositories/exam_profile_repository.dart';
import '../../domain/services/exam_paper_formatter.dart';
import '../state/app_state.dart';
import '../state/exam_composer_state.dart';
import '../widgets/exam/exam_composer_controllers.dart';
import '../widgets/exam/exam_info_panel.dart';
import '../widgets/exam/exam_practical_panel.dart';
import '../widgets/exam/exam_review_panel.dart';
import '../widgets/exam/exam_theory_panel.dart';
import '../widgets/exam/exam_typography_panel.dart';
import '../widgets/text_scale_controls.dart';

/// Titles of the five steps of the composer, in order.
const List<String> examStepTitles = <String>[
  'الخط',
  'معلومات الامتحان',
  'الأسئلة النظرية',
  'الأسئلة العملية',
  'المعاينة والتصدير',
];

/// Writes an exam paper question by question and exports it as a Word file
/// that follows the official paper of the project.
///
/// Both the file writer and the profile store are injectable so that the widget
/// tests never touch the platform channels.
class ExamComposerScreen extends StatefulWidget {
  const ExamComposerScreen({
    super.key,
    this.exportDocument,
    this.profileRepository,
    this.questionBankRepository,
  });

  final ExamDocumentExport? exportDocument;
  final ExamProfileRepository? profileRepository;
  final ExamQuestionBankRepository? questionBankRepository;

  @override
  State<ExamComposerScreen> createState() => _ExamComposerScreenState();
}

class _ExamComposerScreenState extends State<ExamComposerScreen> {
  late final ExamProfileRepository _profiles;
  ExamComposerState? _composer;
  ExamComposerControllers? _controllers;
  int _step = 0;
  int _theoryIndex = 0;
  bool _exporting = false;

  late final ExamQuestionBankRepository _bank;
  List<ExamQuestionBankEntry> _savedGroups = const <ExamQuestionBankEntry>[];

  @override
  void initState() {
    super.initState();
    _profiles = widget.profileRepository ?? const PrefsExamProfileRepository();
    _bank = widget.questionBankRepository ?? const PrefsExamQuestionBankRepository();
    _bootstrap();
  }

  @override
  void dispose() {
    _controllers?.dispose();
    _composer?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    var profile = const ExamProfile();
    try {
      profile = await _profiles.load();
    } catch (error, stackTrace) {
      debugPrint('Exam profile loading failed: $error\n$stackTrace');
    }
    if (!mounted) {
      return;
    }
    _savedGroups = await _loadBank();
    if (!mounted) {
      return;
    }
    final app = AppScope.read(context);
    final composer = ExamComposerState(
      units: app.visibleUnits,
      drawings: app.visibleDrawings,
      gradeLabel: examGradeLabel(app.gradeTitle),
      profile: profile,
    );
    final controllers = ExamComposerControllers(composer);
    setState(() {
      _composer = composer;
      _controllers = controllers;
    });
  }

  Future<List<ExamQuestionBankEntry>> _loadBank() async {
    try {
      return await _bank.load();
    } catch (error, stackTrace) {
      debugPrint('Exam question bank loading failed: $error\n$stackTrace');
      return const <ExamQuestionBankEntry>[];
    }
  }

  /// Keeps the current selection in the on-device bank.
  Future<void> _saveGroup() async {
    final composer = _composer;
    if (composer == null || _exporting) {
      return;
    }
    final entry = composer.toBankEntry(
      id: 'group-${DateTime.now().microsecondsSinceEpoch}',
      title: _groupTitle(composer),
    );
    if (entry.isEmpty) {
      _showMessage('اختر سؤالاً واحداً على الأقل قبل الحفظ.');
      return;
    }
    final next = <ExamQuestionBankEntry>[entry, ..._savedGroups];
    try {
      await _bank.save(next);
    } catch (error, stackTrace) {
      debugPrint('Saving the exam question group failed: $error\n$stackTrace');
      _showMessage('تعذّر حفظ المجموعة. حاول مرة أخرى.');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _savedGroups = next);
    _showMessage('حُفظت المجموعة في التطبيق للرجوع إليها لاحقاً.');
  }

  String _groupTitle(ExamComposerState composer) {
    final grade = composer.gradeLabel.trim();
    final term = composer.term.label;
    final count = toArabicDigits('${composer.theoryItemCount + composer.practicalCount}');
    return '$term • $count سؤالاً${grade.isEmpty ? '' : ' • $grade'}';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Lists the saved groups so one of them can be restored.
  Future<void> _openBank() async {
    if (_exporting) {
      return;
    }
    final entries = _savedGroups.isEmpty ? await _loadBank() : _savedGroups;
    if (!mounted) {
      return;
    }
    if (entries.isEmpty) {
      _showMessage('لا توجد مجموعات محفوظة بعد.');
      return;
    }
    setState(() => _savedGroups = entries);
    final chosen = await showDialog<ExamQuestionBankEntry>(
      context: context,
      builder: (BuildContext context) => _BankDialog(entries: entries),
    );
    final composer = _composer;
    final controllers = _controllers;
    if (chosen == null || !mounted || composer == null || controllers == null) {
      return;
    }
    composer.applyBankEntry(chosen);
    controllers.syncFrom(composer);
    _showMessage('استُرجعت المجموعة المحفوظة.');
  }

  Future<void> _export() async {
    final composer = _composer;
    final paper = composer?.paper;
    if (composer == null || paper == null || _exporting) {
      return;
    }
    final exporter = widget.exportDocument ?? ExamDocumentExporter.export;
    setState(() => _exporting = true);
    try {
      final Uint8List bytes = ExamDocxBuilder.build(paper);
      final ExamExportResult result = await exporter(bytes, examPaperFileName(paper));
      await _profiles.save(composer.toProfile());
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
    } catch (error, stackTrace) {
      debugPrint('Exam export failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تصدير ملف وورد. تحقق من مساحة التخزين وحاول مرة أخرى.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  void _goTo(int step) {
    if (step < 0 || step >= examStepTitles.length || step == _step) {
      return;
    }
    setState(() => _step = step);
  }

  @override
  Widget build(BuildContext context) {
    final composer = _composer;
    final controllers = _controllers;
    return Scaffold(
      appBar: AppBar(
        title: const Text('كتابة الأسئلة'),
        actions: const <Widget>[TextScaleControls()],
      ),
      body: composer == null || controllers == null
          ? const Center(child: CircularProgressIndicator())
          : ListenableBuilder(
              listenable: composer,
              builder: (BuildContext context, Widget? child) =>
                  _steps(context, composer, controllers),
            ),
      bottomNavigationBar: composer == null
          ? null
          : ListenableBuilder(
              listenable: composer,
              builder: (BuildContext context, Widget? child) => _bar(context, composer),
            ),
    );
  }

  Widget _steps(
    BuildContext context,
    ExamComposerState composer,
    ExamComposerControllers controllers,
  ) {
    final ExamPaper? paper = composer.paper;
    final panels = <Widget>[
      ExamTypographyPanel(state: composer, controllers: controllers),
      ExamInfoPanel(state: composer, controllers: controllers),
      ExamTheoryPanel(
        state: composer,
        controllers: controllers,
        index: _theoryIndex,
        onIndexChanged: (int value) => setState(() => _theoryIndex = value),
      ),
      ExamPracticalPanel(state: composer, controllers: controllers),
      ExamReviewPanel(state: composer, paper: paper),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
      children: <Widget>[
        AppPage(
          maxWidth: AppLayout.readingMaxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: AppSpacing.md),
              _bankBar(),
              const SizedBox(height: AppSpacing.md),
              _StepBar(step: _step, onSelected: _goTo),
              const SizedBox(height: AppSpacing.lg),
              panels[_step],
            ],
          ),
        ),
      ],
    );
  }

  /// Saving and restoring the group, available from every step.
  Widget _bankBar() {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        OutlinedButton.icon(
          key: const ValueKey<String>('exam-save-group'),
          onPressed: _exporting ? null : _saveGroup,
          icon: const Icon(Icons.bookmark_add_outlined, size: 18),
          label: const Text('حفظ المجموعة'),
        ),
        OutlinedButton.icon(
          key: const ValueKey<String>('exam-open-bank'),
          onPressed: _exporting ? null : _openBank,
          icon: const Icon(Icons.inventory_2_outlined, size: 18),
          label: Text(
            'المجموعات المحفوظة (${toArabicDigits('${_savedGroups.length}')})',
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, ExamComposerState composer) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ExamPaper? paper = composer.paper;
    final List<String> issues = composer.issues;
    final bool last = _step == examStepTitles.length - 1;
    final String status = paper == null
        ? (issues.isEmpty ? 'أكمل بيانات الامتحان' : issues.first)
        : '${toArabicDigits('${paper.theoryItemCount}')} عنصراً نظرياً • '
              '${toArabicDigits('${paper.practicalCount}')} سؤالاً عملياً';
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.readingMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    status,
                    key: const ValueKey<String>('exam-status'),
                    style: theme.textTheme.labelLarge,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: <Widget>[
                      if (_step > 0) ...<Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const ValueKey<String>('exam-back'),
                            onPressed: _exporting ? null : () => _goTo(_step - 1),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text(
                              'السابق',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                      ],
                      Expanded(
                        child: last
                            ? FilledButton.icon(
                                key: const ValueKey<String>('exam-export'),
                                onPressed: paper == null || _exporting ? null : _export,
                                icon: _exporting
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.description_outlined, size: 20),
                                label: Text(
                                  _exporting ? 'جاري التصدير' : 'تصدير ملف وورد',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : FilledButton.tonalIcon(
                                key: const ValueKey<String>('exam-next'),
                                onPressed: _exporting ? null : () => _goTo(_step + 1),
                                icon: const Icon(Icons.arrow_back, size: 18),
                                label: const Text(
                                  'التالي',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Five selectable chips that also show where the teacher is.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.step, required this.onSelected});

  final int step;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (var i = 0; i < examStepTitles.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: AppSpacing.xs),
            ChoiceChip(
              key: ValueKey<String>('exam-step-$i'),
              selected: i == step,
              label: Text('${toArabicDigits('${i + 1}')}. ${examStepTitles[i]}'),
              onSelected: (_) => onSelected(i),
            ),
          ],
        ],
      ),
    );
  }
}

/// Lists the saved groups and returns the one the teacher picks.
class _BankDialog extends StatelessWidget {
  const _BankDialog({required this.entries});

  final List<ExamQuestionBankEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('المجموعات المحفوظة'),
      content: SizedBox(
        width: 420,
        height: 360,
        child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (BuildContext context, int index) => const Divider(height: 1),
          itemBuilder: (BuildContext context, int index) {
            final entry = entries[index];
            return ListTile(
              key: ValueKey<String>('exam-bank-entry-${entry.id}'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_open_outlined),
              title: Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${toArabicDigits('${entry.itemCount}')} عنصراً • '
                '${entry.savedAt.year}/${entry.savedAt.month}/${entry.savedAt.day}',
                style: theme.textTheme.bodySmall,
              ),
              onTap: () => Navigator.of(context).pop(entry),
            );
          },
        ),
      ),
      actions: <Widget>[
        TextButton(
          key: const ValueKey<String>('exam-bank-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
