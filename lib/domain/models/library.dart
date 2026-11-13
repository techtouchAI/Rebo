/// Domain models of the curriculum content.
///
/// The models map 1:1 to `assets/content/*.json`, which is generated from the
/// DOCX sources by `tools/build_content.py`. Nothing here knows about Flutter.
library;

/// How a unit is presented; derived from the nature of its content.
enum PresentationTemplate {
  concept,
  comparison,
  materials,
  process,
  timeline,
  lesson;

  static PresentationTemplate parse(String? value) {
    switch (value) {
      case 'comparison':
        return PresentationTemplate.comparison;
      case 'materials':
        return PresentationTemplate.materials;
      case 'process':
        return PresentationTemplate.process;
      case 'timeline':
        return PresentationTemplate.timeline;
      case 'lesson':
        return PresentationTemplate.lesson;
      case 'concept':
      default:
        return PresentationTemplate.concept;
    }
  }

  String get label {
    switch (this) {
      case PresentationTemplate.concept:
        return 'شرح وتكوين';
      case PresentationTemplate.comparison:
        return 'مقارنة وتصنيف';
      case PresentationTemplate.materials:
        return 'خامات وتطبيقات';
      case PresentationTemplate.process:
        return 'مراحل وخطوات';
      case PresentationTemplate.timeline:
        return 'خط زمني';
      case PresentationTemplate.lesson:
        return 'خطة درس';
    }
  }
}

/// A legend entry that explains one colour/term of an illustration.
class FigureLegend {
  const FigureLegend({required this.label, required this.color});

  final String label;
  final String color;

  factory FigureLegend.fromJson(Map<String, dynamic> json) {
    return FigureLegend(
      label: json['label'] as String? ?? '',
      color: json['color'] as String? ?? '#000000',
    );
  }
}

/// An authored vector illustration attached to a unit or a lesson.
class Figure {
  const Figure({required this.asset, required this.caption, required this.legend});

  final String asset;
  final String caption;
  final List<FigureLegend> legend;

  factory Figure.fromJson(Map<String, dynamic> json) {
    final legendJson = (json['legend'] as List<dynamic>? ?? const <dynamic>[]);
    return Figure(
      asset: json['asset'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      legend: legendJson
          .map((item) => FigureLegend.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

/// One teaching method of the introduction section.
class TeachingMethod {
  const TeachingMethod({required this.title, required this.bullets});

  final String title;
  final List<String> bullets;

  factory TeachingMethod.fromJson(Map<String, dynamic> json) {
    return TeachingMethod(
      title: json['title'] as String? ?? '',
      bullets: _stringList(json['bullets']),
    );
  }
}

/// A topic inside a unit: a title, short statements and an optional count list.
class Topic {
  const Topic({
    required this.id,
    required this.title,
    required this.bullets,
    this.listTitle,
    this.listItems = const <String>[],
    this.kind,
    this.methods = const <TeachingMethod>[],
  });

  final String id;
  final String title;
  final List<String> bullets;
  final String? listTitle;
  final List<String> listItems;
  final String? kind;
  final List<TeachingMethod> methods;

  bool get isProse => kind == 'prose';
  bool get isMethods => kind == 'methods';

  factory Topic.fromJson(Map<String, dynamic> json) {
    final methodJson = (json['methods'] as List<dynamic>? ?? const <dynamic>[]);
    return Topic(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      bullets: _stringList(json['bullets']),
      listTitle: json['listTitle'] as String?,
      listItems: _stringList(json['listItems']),
      kind: json['kind'] as String?,
      methods: methodJson
          .map((item) => TeachingMethod.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Plain text of the topic, used by the search index and by the reader.
  String get plainText {
    final buffer = StringBuffer(title);
    for (final bullet in bullets) {
      buffer.write(' ');
      buffer.write(bullet);
    }
    for (final item in listItems) {
      buffer.write(' ');
      buffer.write(item);
    }
    for (final method in methods) {
      buffer.write(' ');
      buffer.write(method.title);
      for (final bullet in method.bullets) {
        buffer.write(' ');
        buffer.write(bullet);
      }
    }
    return buffer.toString();
  }
}

/// Question kinds used by the unit self-assessment.
enum QuestionKind {
  trueFalse,
  choice,
  open;

  static QuestionKind parse(String? value) {
    switch (value) {
      case 'choice':
        return QuestionKind.choice;
      case 'open':
        return QuestionKind.open;
      case 'trueFalse':
      default:
        return QuestionKind.trueFalse;
    }
  }
}

/// A review question. Answers always come from the source document; a choice
/// question without a documented answer keeps [answerIndex] null and is shown
/// as an open review question instead of being graded.
class Question {
  const Question({
    required this.id,
    required this.kind,
    required this.prompt,
    this.options = const <String>[],
    this.answerIndex,
    this.answerSupport,
    this.boolAnswer,
    this.textAnswer,
  });

  final String id;
  final QuestionKind kind;
  final String prompt;
  final List<String> options;
  final int? answerIndex;
  final String? answerSupport;
  final bool? boolAnswer;
  final String? textAnswer;

  bool get isGradable {
    if (kind == QuestionKind.trueFalse) {
      return boolAnswer != null;
    }
    if (kind == QuestionKind.choice) {
      return answerIndex != null;
    }
    return false;
  }

  String get answerText {
    switch (kind) {
      case QuestionKind.trueFalse:
        return boolAnswer == true ? 'صح' : 'خطأ';
      case QuestionKind.choice:
        final index = answerIndex;
        if (index == null || index >= options.length) {
          return 'راجع نص الوحدة';
        }
        return options[index];
      case QuestionKind.open:
        return textAnswer ?? '';
    }
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String? ?? '',
      kind: QuestionKind.parse(json['kind'] as String?),
      prompt: json['prompt'] as String? ?? '',
      options: _stringList(json['options']),
      answerIndex: json['answerIndex'] as int?,
      answerSupport: json['answerSupport'] as String?,
      boolAnswer: json['answer'] is bool ? json['answer'] as bool : null,
      textAnswer: json['kind'] == 'open' ? json['answer'] as String? : null,
    );
  }
}

/// The scanned plate of the teacher guide that belongs to a unit.
class UnitPlate {
  const UnitPlate({required this.asset, required this.caption, required this.source});

  final String asset;
  final String caption;
  final String source;

  factory UnitPlate.fromJson(Map<String, dynamic> json) {
    return UnitPlate(
      asset: json['asset'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      source: json['source'] as String? ?? '',
    );
  }
}

/// A curriculum unit: the main content entity of the application.
class LearningUnit {
  const LearningUnit({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.displayTitle,
    required this.grade,
    required this.order,
    required this.template,
    required this.accent,
    required this.topics,
    required this.questions,
    required this.figures,
    this.plate,
    this.glossaryIds = const <String>[],
    this.unitText = '',
  });

  final String id;
  final String sectionId;
  final String title;
  final String displayTitle;
  final String grade;
  final int order;
  final PresentationTemplate template;
  final String accent;
  final List<Topic> topics;
  final List<Question> questions;
  final List<Figure> figures;
  final UnitPlate? plate;
  final List<String> glossaryIds;
  final String unitText;

  bool get isIntroduction => sectionId == 'intro';

  String get numberLabel {
    if (isIntroduction) {
      return 'مدخل';
    }
    return 'الوحدة ${_arabicOrdinal(order)}';
  }

  factory LearningUnit.fromJson(Map<String, dynamic> json) {
    final topics = (json['topics'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Topic.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final questions = (json['questions'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final figures = (json['figures'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Figure.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final plateJson = json['plate'] as Map<String, dynamic>?;
    return LearningUnit(
      id: json['id'] as String? ?? '',
      sectionId: json['sectionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      displayTitle: json['displayTitle'] as String? ?? json['title'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      template: PresentationTemplate.parse(json['template'] as String?),
      accent: json['accent'] as String? ?? 'primary',
      topics: topics,
      questions: questions,
      figures: figures,
      plate: plateJson == null ? null : UnitPlate.fromJson(plateJson),
      glossaryIds: _stringList(json['glossary']),
      unitText: json['unitText'] as String? ?? '',
    );
  }

  /// Everything of the unit in one string, for search and copy/share actions.
  String get searchableText {
    final buffer = StringBuffer('$title $displayTitle $grade');
    for (final topic in topics) {
      buffer.write(' ');
      buffer.write(topic.plainText);
    }
    for (final question in questions) {
      buffer.write(' ');
      buffer.write(question.prompt);
    }
    return buffer.toString();
  }

  String get summary {
    if (topics.isEmpty) {
      return '';
    }
    final first = topics.first;
    final text = first.bullets.isNotEmpty ? first.bullets.first : first.title;
    return text;
  }
}

/// A block of a lesson plan body.
enum LessonBlockKind {
  heading,
  bullet,
  paragraph;

  static LessonBlockKind parse(String? value) {
    switch (value) {
      case 'heading':
        return LessonBlockKind.heading;
      case 'bullet':
        return LessonBlockKind.bullet;
      case 'paragraph':
      default:
        return LessonBlockKind.paragraph;
    }
  }
}

class LessonBlock {
  const LessonBlock({required this.kind, required this.text});

  final LessonBlockKind kind;
  final String text;

  factory LessonBlock.fromJson(Map<String, dynamic> json) {
    return LessonBlock(
      kind: LessonBlockKind.parse(json['kind'] as String?),
      text: json['text'] as String? ?? '',
    );
  }
}

/// One of the two sessions (theoretical / practical) of a lesson.
class LessonSession {
  const LessonSession({
    required this.kind,
    required this.label,
    required this.subject,
    required this.generalAims,
    required this.specificAims,
    required this.media,
    required this.introduction,
    required this.body,
    required this.homework,
  });

  final String kind;
  final String label;
  final String subject;
  final String generalAims;
  final List<String> specificAims;
  final String media;
  final String introduction;
  final List<LessonBlock> body;
  final List<String> homework;

  bool get isTheory => kind == 'theory';

  factory LessonSession.fromJson(Map<String, dynamic> json) {
    final body = (json['body'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => LessonBlock.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return LessonSession(
      kind: json['kind'] as String? ?? 'theory',
      label: json['label'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      generalAims: json['generalAims'] as String? ?? '',
      specificAims: _stringList(json['specificAims']),
      media: json['media'] as String? ?? '',
      introduction: json['introduction'] as String? ?? '',
      body: body,
      homework: _stringList(json['homework']),
    );
  }
}

/// A lesson plan of the practical lessons section.
class LessonPlan {
  const LessonPlan({
    required this.id,
    required this.title,
    required this.summary,
    required this.accent,
    required this.order,
    required this.plans,
    required this.figures,
  });

  final String id;
  final String title;
  final String summary;
  final String accent;
  final int order;
  final List<LessonSession> plans;
  final List<Figure> figures;

  String get searchableText {
    final buffer = StringBuffer('$title $summary');
    for (final plan in plans) {
      buffer
        ..write(' ')
        ..write(plan.subject)
        ..write(' ')
        ..write(plan.generalAims)
        ..write(' ')
        ..write(plan.introduction);
      for (final aim in plan.specificAims) {
        buffer
          ..write(' ')
          ..write(aim);
      }
      for (final block in plan.body) {
        buffer
          ..write(' ')
          ..write(block.text);
      }
    }
    return buffer.toString();
  }

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final plans = (json['plans'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => LessonSession.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final figures = (json['figures'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Figure.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return LessonPlan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      accent: json['accent'] as String? ?? 'primary',
      order: json['order'] as int? ?? 0,
      plans: plans,
      figures: figures,
    );
  }
}

/// A technical term with the definition stated in the source document.
class GlossaryTerm {
  const GlossaryTerm({
    required this.id,
    required this.term,
    required this.definition,
    required this.unitId,
    this.topicId,
  });

  final String id;
  final String term;
  final String definition;
  final String unitId;
  final String? topicId;

  factory GlossaryTerm.fromJson(Map<String, dynamic> json) {
    return GlossaryTerm(
      id: json['id'] as String? ?? '',
      term: json['term'] as String? ?? '',
      definition: json['definition'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
      topicId: json['topicId'] as String?,
    );
  }
}

/// A scanned artwork plate taken from the teacher guide.
class Plate {
  const Plate({
    required this.id,
    required this.asset,
    required this.title,
    required this.caption,
    required this.source,
    required this.grade,
    required this.unitId,
  });

  final String id;
  final String asset;
  final String title;
  final String caption;
  final String source;
  final String grade;
  final String unitId;

  factory Plate.fromJson(Map<String, dynamic> json) {
    return Plate(
      id: json['id'] as String? ?? '',
      asset: json['asset'] as String? ?? '',
      title: json['title'] as String? ?? '',
      caption: json['caption'] as String? ?? '',
      source: json['source'] as String? ?? '',
      grade: json['grade'] as String? ?? '',
      unitId: json['unitId'] as String? ?? '',
    );
  }
}

/// A section of the table of contents.
class ContentSection {
  const ContentSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.kind,
  });

  final String id;
  final String title;
  final String subtitle;
  final String kind;

  bool get isGrade => kind == 'grade';

  factory ContentSection.fromJson(Map<String, dynamic> json) {
    return ContentSection(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      kind: json['kind'] as String? ?? 'grade',
    );
  }
}

/// The whole offline library, loaded once at start-up.
class Library {
  const Library({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.units,
    required this.lessons,
    required this.glossary,
    required this.plates,
  });

  final String title;
  final String subtitle;
  final List<ContentSection> sections;
  final List<LearningUnit> units;
  final List<LessonPlan> lessons;
  final List<GlossaryTerm> glossary;
  final List<Plate> plates;

  List<LearningUnit> unitsOf(String sectionId) {
    return units.where((unit) => unit.sectionId == sectionId).toList(growable: false);
  }

  LearningUnit? unitById(String id) {
    for (final unit in units) {
      if (unit.id == id) {
        return unit;
      }
    }
    return null;
  }

  LessonPlan? lessonById(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) {
        return lesson;
      }
    }
    return null;
  }

  GlossaryTerm? termById(String id) {
    for (final term in glossary) {
      if (term.id == id) {
        return term;
      }
    }
    return null;
  }

  /// Reading order used by the previous/next navigation.
  List<String> get readingOrder {
    final ids = <String>[];
    for (final section in sections) {
      if (section.kind == 'grade' || section.kind == 'intro') {
        for (final unit in unitsOf(section.id)) {
          ids.add(unit.id);
        }
      }
    }
    return ids;
  }

  int get totalReadableUnits => units.length;

  factory Library.fromJson(
    Map<String, dynamic> curriculum,
    Map<String, dynamic> lessonsJson,
    Map<String, dynamic> glossaryJson,
    Map<String, dynamic> platesJson,
  ) {
    final sections = (curriculum['sections'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => ContentSection.fromJson(item as Map<String, dynamic>))
        .toList(growable: false)
      ..sort((a, b) => _sectionWeight(a.kind).compareTo(_sectionWeight(b.kind)));
    final units = (curriculum['units'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => LearningUnit.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final lessons = (lessonsJson['lessons'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => LessonPlan.fromJson(item as Map<String, dynamic>))
        .toList(growable: false)
      ..sort((a, b) => a.order.compareTo(b.order));
    final glossary = (glossaryJson['terms'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => GlossaryTerm.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final plates = (platesJson['plates'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Plate.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    return Library(
      title: curriculum['title'] as String? ?? 'مِرسم',
      subtitle: curriculum['subtitle'] as String? ?? '',
      sections: sections,
      units: units,
      lessons: lessons,
      glossary: glossary,
      plates: plates,
    );
  }
}

int _sectionWeight(String kind) {
  switch (kind) {
    case 'intro':
      return 0;
    case 'grade':
      return 1;
    case 'lessons':
      return 2;
    case 'plates':
      return 3;
    default:
      return 4;
  }
}

const List<String> _arabicOrdinals = <String>[
  'الأولى',
  'الثانية',
  'الثالثة',
  'الرابعة',
  'الخامسة',
  'السادسة',
];

String _arabicOrdinal(int value) {
  if (value >= 1 && value <= _arabicOrdinals.length) {
    return _arabicOrdinals[value - 1];
  }
  return '$value';
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}
