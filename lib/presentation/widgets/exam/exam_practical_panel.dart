import 'package:flutter/material.dart';

import '../../../core/theme/dimens.dart';
import '../../../core/utils/arabic_text.dart';
import '../../../domain/models/exam_paper.dart';
import '../../../domain/models/library.dart';
import '../../state/exam_composer_state.dart';
import 'exam_composer_controllers.dart';
import 'exam_panel_parts.dart';

/// Fourth step: the practical questions, each one either a prepared drawing
/// topic of the curriculum or a question written by the teacher.
class ExamPracticalPanel extends StatelessWidget {
  const ExamPracticalPanel({
    super.key,
    required this.state,
    required this.controllers,
  });

  final ExamComposerState state;
  final ExamComposerControllers controllers;

  /// Sentinel of the "write my own question" choice; the dropdown cannot use a
  /// null value to select an item.
  static const String customChoice = '__exam_custom__';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ExamPanelCard(
          title: 'المادة العملية',
          subtitle:
              'اختر موضوع رسم جاهزاً من موضوعات الصف، أو اكتب سؤالاً مخصصاً. '
              'ترتيب الأسئلة هو ترتيب كتابتها.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextField(
                key: const ValueKey<String>('exam-practical-header'),
                controller: controllers.practicalHeader,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'عنوان المادة العملية',
                  helperText: 'تُطبع بعده الدرجة الكلية تلقائياً.',
                  border: OutlineInputBorder(),
                ),
                onChanged: state.setPracticalHeader,
              ),
              const SizedBox(height: AppSpacing.md),
              ExamNumberField(
                fieldKey: const ValueKey<String>('exam-practical-total'),
                label: 'درجة القسم العملي',
                controller: controllers.practicalDegree,
                onChanged: () => state.setPracticalDegree(
                  parseIntegerDigits(controllers.practicalDegree.text),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'عدد الموضوعات الجاهزة لهذا الصف: '
                '${toArabicDigits('${state.drawings.length}')}.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        for (var i = 0; i < state.practical.length; i++) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          _slot(context, i),
        ],
      ],
    );
  }

  Widget _slot(BuildContext context, int index) {
    final ExamPracticalQuestion question = state.practical[index];
    final selectedId = question.drawingId ?? customChoice;
    return ExamPanelCard(
      title: 'السؤال العملي ${toArabicDigits('${index + 1}')}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          DropdownButtonFormField<String>(
            key: ValueKey<String>('exam-drawing-$index'),
            initialValue: selectedId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'موضوع الرسم',
              border: OutlineInputBorder(),
            ),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: customChoice,
                child: Text('سؤال مخصص'),
              ),
              for (final TopicDrawing drawing in state.drawings)
                DropdownMenuItem<String>(
                  value: drawing.id,
                  child: Text(
                    '${drawing.title} — ${drawing.unitTitle}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (String? id) {
              state.selectDrawing(index, _drawingById(id));
              final controller = controllers.practicalPrompts[index];
              final prompt = state.practical[index].prompt;
              if (controller.text != prompt) {
                controller.text = prompt;
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: ValueKey<String>('exam-practical-$index'),
            controller: controllers.practicalPrompts[index],
            maxLines: 3,
            minLines: 1,
            decoration: const InputDecoration(
              labelText: 'نص السؤال',
              hintText: 'ارسم …',
              border: OutlineInputBorder(),
            ),
            onChanged: (String value) => state.setPracticalPrompt(index, value),
          ),
          const SizedBox(height: AppSpacing.md),
          ExamNumberField(
            fieldKey: ValueKey<String>('exam-practical-degree-$index'),
            label: 'درجة السؤال',
            controller: controllers.practicalDegrees[index],
            onChanged: () => state.setPracticalSlotDegree(
              index,
              parseIntegerDigits(controllers.practicalDegrees[index].text),
            ),
          ),
        ],
      ),
    );
  }

  TopicDrawing? _drawingById(String? id) {
    if (id == null || id == customChoice) {
      return null;
    }
    for (final TopicDrawing drawing in state.drawings) {
      if (drawing.id == id) {
        return drawing;
      }
    }
    return null;
  }
}
