# بنية التطبيق

## نظرة عامة

```
lib/
├── main.dart                  نقطة الدخول
├── app.dart                   MaterialApp عربي RTL + حجم الخط + السمة
├── core/
│   ├── theme/                 الألوان، السمة، المقاسات ونقاط الانكسار
│   ├── utils/arabic_text.dart تطبيع البحث، المقتطفات، الأرقام، زمن القراءة
│   └── widgets/               عناصر مشتركة (AppPage, SectionHeader, MetaPill…)
├── domain/
│   ├── models/library.dart    نماذج المحتوى + PresentationTemplate + QuestionKind + TopicDrawing
│   ├── models/progress.dart   ReadingProgress + AppThemeMode
│   ├── models/quiz_session.dart  منطق تصحيح الاختبار (منفصل عن الواجهة)
│   ├── repositories/          عقود المحتوى والتقدّم
│   └── services/              البحث وخطة تجميع أسئلة الطباعة حسب النوع والوحدة
├── data/local/
│   ├── asset_content_repository.dart   يقرأ خمسة ملفات JSON من الحزمة
│   ├── question_pdf.dart      إنشاء PDF عربي A4 وإرساله لخدمة طباعة النظام
│   ├── docx/                  كاتب ZIP مخزّن + بناء ملف وورد (WordprocessingML) لورقة الامتحان
│   ├── exam_document_exporter.dart  حفظ ملف الوورد على ويندوز ومشاركته من الهاتف
│   ├── prefs_exam_profile_repository.dart  حفظ بيانات المدرس والخط بين الجلسات
│   ├── prefs_progress_repository.dart  حفظ التقدّم في SharedPreferences
│   └── memory_progress_repository.dart بديل للاختبارات
└── presentation/
    ├── state/app_state.dart   ChangeNotifier واحد + AppScope (InheritedNotifier)
    ├── state/bootstrap.dart   تحميل المحتوى، شاشة بداية، شاشة خطأ
    ├── navigation/app_routes.dart
    ├── screens/               15 شاشة + الهيكل العام (منها اختيار الصف والموضوعات المصوّرة)
    └── widgets/               IllustrationFigure, TopicCard, TopicDrawings,
                               AssetViewer, GalleryTiles, unit_sections
```

## تدفّق الإقلاع

1. `main()` يثبّت الاتجاه العام ويشغّل `MirsamBootstrap`.
2. `MirsamBootstrap` يحمّل بالتوازي: `AssetContentRepository.load()` و`PrefsProgressRepository.load()`.
3. عند النجاح: `AppState(library, progress, repository)` ثم `AppScope` ثم `MirsamApp`.
   إن لم يكن `progress.gradeId` محفوظاً (أول تشغيل) يفتح `MirsamApp` شاشة `GradePickerScreen`،
   وبعد اختيار الصف تُستبدل بـ `LandingShell`.
4. أثناء التحميل تظهر شاشة بداية بهوية التطبيق، وعند الفشل شاشة خطأ عربية بالسبب.
5. في الاختبارات يُحقن `MemoryProgressRepository` و`FileContentRepository`، لذا تُجرّب الشجرة نفسها
   التي تعمل في الإنتاج.

`AppState` يُنشأ مرة واحدة داخل `_load()` لا داخل `build()`، حتى لا يُفقد التقدّم عند أي إعادة بناء.

## الحالة

- `AppState extends ChangeNotifier` — لا حزم حالة خارجية.
- `AppScope extends InheritedNotifier<AppState>`:
  - `AppScope.of(context)` يشترك في التغييرات (للواجهات).
  - `AppScope.read(context)` للقراءة دون اشتراك (داخل معالجات الأحداث).
- التقدّم يُحفظ ككتلة JSON واحدة تحت المفتاح `mirsam.progress.v1`، ويُكتب بعد كل تغيير دلالي
  (قراءة وحدة، مفضلة، نتيجة اختبار، سمة، حجم خط). موضع التمرير يُحفظ عند مغادرة الوحدة.

```json
{
  "favorites": ["g1-u1"],
  "readUnits": ["g1-u1", "g2-u1"],
  "lastUnitId": "g2-u1",
  "scrollOffsets": {"g2-u1": 812.0},
  "quizScores": {"g1-u1": 6},
  "themeMode": "system",
  "textScale": 1.0,
  "gradeId": "g1",
  "font": "almarai"
}
```

## الصف الدراسي كمرشّح وحيد

- `ReadingProgress.gradeId` (`g1|g2|g3|null`) هو المصدر الوحيد لتصفية المحتوى، ويُحفظ مع بقية التقدّم.
- `AppState` يوفّر: `gradeId`, `hasGrade`, `gradeSection`, `gradeTitle`, `gradeSections`, `setGrade`,
  و`visibleUnits`, `visibleUnitIds`, `visibleSections`, `visibleReadingOrder`, `visiblePlates`,
  `visibleGlossary`, إضافة إلى `totalUnits`, `readUnitsCount`, `favoriteUnits`, `lastReadUnit` المشتقة منها.
- `setGrade` يعيد بناء `SearchService` بمرشّح `unitFilter` (وحدات الصف + الدروس المشتركة)، و`setGrade(null)`
  يعيد الفهرس الكامل (يُستخدم في الاختبارات فقط).
- «إعادة تعيين البيانات» تُبقي `gradeId` لأن اختيار الصف إعداد عرض لا بيانات قراءة.

## المحتوى والبحث

- `assets/content/{curriculum,lessons,glossary,plates,drawings}.json` — ناتج `tools/build_content.py`،
  ومصدره الوحيد ملفات DOCX المرفقة. لا يُحرَّر يدوياً.
- `Library` يوفّر: `unitsOf(section)`, `unitById`, `lessonById`, `termById`, `drawingById`,
  `drawingsOfUnit`, `drawingsOfTopic`, `readingOrder`.
- `TopicDrawing` هو رسم موضوع واحد: `id, order, title, asset, unitId, unitTitle, topicId, topicTitle,
  grade, caption`. الربط بالموضوع هو ما يسمح بعرض الرسم في بداية موضوعه وفي المعرض حسب الموضوع.
- `SearchService` يبني الفهرس مرة واحدة عند الإقلاع (66 مدخلاً) من الوحدات والدروس والمصطلحات واللوحات
  ورسوم الموضوعات، ويُطبّع النص بـ `normalizeArabic` (توحيد الهمزات/الياء/التاء المربوطة، إزالة
  التشكيل والتطويل). التسجيل: 10 لكل رمز مطابق + 25 إذا طابق العنوان + 15 إذا طابقت كل الرموز.
- `snippetFor` يستخرج الجملة التي تحتوي الكلمة من النص الأصلي (دون تطبيع) لعرض مقتطف صحيح.

## الواجهة

- **الهيكل**: `LandingShell` يعرض `NavigationRail` عند العرض ≥ 940 (`AppLayout.railBreakpoint`)
  و`NavigationBar` دونه، بأربع وجهات: الرئيسية، الفهرس، المفضلة، الإعدادات.
- **طباعة أسئلة الامتحان**: قسم مستقل لا يعرض نصوص الأسئلة، ويتيح تحديد وحدات الصف وإعداد خط الطباعة
  وحجمَي المحتوى والعناوين. تحتفظ `QuestionPrintPlan` باختيار الوحدات وإعدادات الطباعة في لقطة واحدة، وتجمع
  الأسئلة حسب النوع من دون طباعة أسماء الوحدات. تُستمد إجابات صح/خطأ والاختيارات والتعداد من البيانات الموثّقة؛
  يُعرض تصحيح العبارة الخاطئة عند توفره، ويُذكر غياب الإجابة صراحةً عند عدم توثيقها. يضمّن `QuestionPdfBuilder`
  الخط المختار من IBM Plex Sans Arabic أو Noto Kufi Arabic أو Amiri ووزنَه العريض، ويرسم المستند باتجاه RTL على A4.
  أحجام الطباعة من ٨ إلى ٣٢ نقطة (افتراضياً ١٢ للمحتوى و١٤ للعناوين) مستقلة عن إعدادات القراءة في التطبيق؛
  يُستكمل المحتوى على صفحات إضافية عند الحاجة دون قص أو تصغير. يفتح `QuestionPrinter` نافذة الطباعة الأصلية
  لأندرويد أو ويندوز، ولا يحتاج توليد المستند إلى شبكة.
- **كتابة الأسئلة (قسم مستقل)**: `ExamComposerScreen` خمس خطوات بترتيب النموذج الرسمي: الخط، ثم بيانات
  الامتحان، ثم الأسئلة النظرية الثلاثة (الصح والخطأ ← الاختيارات ← التعداد) واحداً بعد الآخر، ثم الأسئلة
  العملية الثلاثة، ثم المعاينة والتصدير. تُبنى الأسئلة المعروضة من `examQuestionOptions` بترتيب المنهج نفسه
  (`units` ثم الأسئلة)، وتُبنى الموضوعات العملية من رسوم الصف بترتيبها. `ExamComposerState` مسودة واحدة
  تُنتج `ExamPaper` غير قابلة للتغيير فقط عند اكتمالها، و`ExamDocxBuilder` يكتب حزمة `.docx` كاملة
  (ZIP مخزّن + `word/document.xml` + `styles.xml` + `settings.xml`) تحاكي الورقة الرسمية: ترويسة بثلاثة
  أعمدة (المدرسة، عنوان الامتحان والسنة، الاسم والصف والشعبة)، جدول الدرجات بتسعة صفوف وخلية «العملي»
  المدمجة، القسم النظري، القسم العملي، ثم التمنيات واسم المدرس، بمقاس A4 وهامش 12.7 مم واتجاه RTL.
  التصدير يمرّ عبر `ExamDocumentExporter` (المستندات على ويندوز، مشاركة النظام على أندرويد)، والدالة
  قابلة للحقن في الاختبارات.
- **العرض المتغيّر**: `UnitSections` يختار تخطيطاً حسب `PresentationTemplate`:

  | القالب | التخطيط |
  | --- | --- |
  | `concept` | لوحة تعريف + بطاقات موضوعات بشارات |
  | `comparison` | جدول طرفين (يسقط إلى بطاقات إذا قلّت صفوف التسميات) |
  | `materials` | شبكة بلاطات بعمود أو عمودين |
  | `process` | خط خطوات عمودي مرقّم |
  | `timeline` | شريط سنوات مستخرج (1800–2100) + بطاقات |

- **الرسوم**: `IllustrationFigure` يعرض SVG من الحزمة بحد أقصى للارتفاع، وخطاطيف `textDirection: rtl`،
  ومربّع حوار للتكبير، ووسيلة إيضاح ملوّنة من `legend` في JSON.
- **رسوم الموضوعات**: `UnitSections` يستقبل `drawings` ويعرض `TopicDrawings` **قبل** بطاقة الموضوع في
  القوالب الخمسة (مفهومي، مقارن، خامات، خطوات، زمني)، فيقف الرسم في بداية الموضوع الذي يخدمه.
- **معرض الصور**: `GalleryTiles` + `groupByUnit` يجمعان لوحات الوحدات ورسوم الموضوعات تحت كل وحدة،
  و`PlatesScreen` يعرضهما في قسمين داخل معرض واحد بدل قائمة مسطّحة.
- **العرض المكبَّر**: `AssetViewer` هو الهيكل المشترك لعارض اللوحة وعارض رسم الموضوع (تكبير 0.8–5×،
  شريط شرح، أزرار رجوع إلى الوحدة، وأزرار حجم الخط)، فلا تتكرر الواجهة في الشاشتين.
- **المقاسات**: `AppLayout.pageMaxWidth = 1240`، `readingMaxWidth = 860`، `railBreakpoint = 940`.
- **التنقّل بين الوحدات**: `_UnitSwitcher` في `unit_screen` شريط أفقي أسفل شريط التطبيق يعرض
  الوحدات الأربع للصف المختار (رقم الوحدة وعنوانها)، والانتقال يستبدل الشاشة (`pushReplacement`)
  بدل تكديسها.
- **الترويسة**: `AppPageHeader` يضع على الهاتف صفّاً علوياً مستقلاً (الشعار + الأدوات + `TextScaleControls`)
  ثم كتلة العنوان/العنوان الفرعي تحته، وعلى الشاشات العريضة صفّاً واحداً موسّعاً — فلا تتزاحم العناصر.
- **حجم الخط**: `TextScaleControls` (تكبير/تصغير) مركّب في `AppPageHeader` و`AppBar` لكل شاشة، ويتصرّف على
  `AppState.setTextScale` نفسه المستخدم في شريط الإعدادات.
- **السمة**: ألوان مستوحاة من خامات الصف الفني (طين `#B4462F`، نيلي `#1E5F74`، مغرة `#D9A34A`،
  أخضر `#4E7C59`، ورق `#F7F1E6`)، و**Amiri** للعناوين بترخيص OFL.
- **الخطوط**: خمس عائلات مضمّنة (`Almarai`, `Cairo`, `Tajawal`, `IBMPlexSansArabic`, `NotoKufiArabic`)،
  يختار المتعلّم واحدة من «الإعدادات ← الخط»؛ `AppTheme.light/dark(bodyFont:)` يبني `TextTheme` بالعائلة
  المختارة و`ReadingProgress.font` يحفظها، فلا حاجة إلى أي تحميل شبكي.

## الشاشات

| الشاشة | الوظيفة |
| --- | --- |
| `home_screen` | هوية، مساحة بحث، متابعة القراءة، إحصاءات، أقسام المحتوى، معاينة الوحدات |
| `index_screen` | فهرس كامل بتصفية وحالة قراءة وشارات لكل وحدة |
| `unit_screen` | قارئ وحدة: شريط تنقّل بين وحدات الصف، رسوم، موضوعات بقالبها، مصطلحات، لوحة، دعوة للاختبار، تنقّل سابق/تالٍ |
| `quiz_screen` | أسئلة الوحدة مع تصحيح تلقائي وكشف الإجابات ونتيجة قابلة لإعادة المحاولة |
| `question_print_screen` | اختيار الوحدات وخط الطباعة وأحجامه، ثم طباعة الأسئلة وإجاباتها على A4 |
| `lessons_screen` | فهرس الدروس التطبيقية الأربعة |
| `lesson_screen` | درس تطبيقي واحد: العرض ثم الواجب البيتي |
| `drawings_screen` | معرض الموضوعات المصوّرة الأربعة عشر (قسم مستقل)، مجمّع حسب الوحدة والموضوع |
| `drawing_viewer_screen` | عرض رسم موضوع ملء الشاشة مع تكبير واسم الوحدة والموضوع |
| `plates_screen` | معرض موحّد: لوحات الوحدات ورسوم الموضوعات، كلتاهما حسب الوحدة والموضوع |
| `plate_viewer_screen` | عرض ملء الشاشة مع تكبير وسحب وإسناد الصفحة |
| `glossary_screen` | المصطلحات وتعريفاتها وروابط وحداتها |
| `search_screen` | بحث فوري مع تصفية بالنوع |
| `favorites_screen` | المحفوظات (وضع مدمج داخل الهيكل) |
| `settings_screen` | الصف الدراسي، المظهر، حجم الخط، سجل التقدّم، عن المحتوى (وضع مدمج) |
| `grade_picker_screen` | اختيار الصف في أول تشغيل (وثالثة بطاقات للصفوف الثلاثة) |

## قيود مقصودة

- لا يُحمَّل المحتوى أو الخطوط عبر الشبكة وقت التشغيل؛ كل الوسائط في الحزمة. إرسال المهمة إلى الطابعة
  يستخدم خدمة النظام وقد يعتمد اتصال الطابعة نفسها على إعدادات الجهاز.
- لا قاعدة بيانات: حجم المحتوى ثابت ومعروف (‎< 1MB JSON)، والقراءة من الأصول أسرع وأبسط.
- لا `provider`/`riverpod`: `InheritedNotifier` يكفي ويقلّل التبعيات.
