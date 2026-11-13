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
│   ├── models/library.dart    نماذج المحتوى + PresentationTemplate + QuestionKind
│   ├── models/progress.dart   ReadingProgress + AppThemeMode
│   ├── models/quiz_session.dart  منطق تصحيح الاختبار (منفصل عن الواجهة)
│   ├── repositories/          عقود المحتوى والتقدّم
│   └── services/search_service.dart  فهرس وبحث دون اتصال
├── data/local/
│   ├── asset_content_repository.dart   يقرأ أربعة ملفات JSON من الحزمة
│   ├── prefs_progress_repository.dart  حفظ التقدّم في SharedPreferences
│   └── memory_progress_repository.dart بديل للاختبارات
└── presentation/
    ├── state/app_state.dart   ChangeNotifier واحد + AppScope (InheritedNotifier)
    ├── state/bootstrap.dart   تحميل المحتوى، شاشة بداية، شاشة خطأ
    ├── navigation/app_routes.dart
    ├── screens/               13 شاشة + الهيكل العام (منها اختيار الصف)
    └── widgets/               IllustrationFigure, TopicCard, unit_sections
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
  "gradeId": "g1"
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

- `assets/content/{curriculum,lessons,glossary,plates}.json` — ناتج `tools/build_content.py`،
  ومصدره الوحيد ملفات DOCX المرفقة. لا يُحرَّر يدوياً.
- `Library` يوفّر: `unitsOf(section)`, `unitById`, `lessonById`, `termById`, `readingOrder`.
- `SearchService` يبني الفهرس مرة واحدة عند الإقلاع (51 مدخلاً) من الوحدات والدروس والمصطلحات واللوحات،
  ويُطبّع النص بـ `normalizeArabic` (توحيد الهمزات/الياء/التاء المربوطة، إزالة التشكيل والتطويل).
  التسجيل: 10 لكل رمز مطابق + 25 إذا طابق العنوان + 15 إذا طابقت كل الرموز.
- `snippetFor` يستخرج الجملة التي تحتوي الكلمة من النص الأصلي (دون تطبيع) لعرض مقتطف صحيح.

## الواجهة

- **الهيكل**: `LandingShell` يعرض `NavigationRail` عند العرض ≥ 940 (`AppLayout.railBreakpoint`)
  و`NavigationBar` دونه، بأربع وجهات: الرئيسية، الفهرس، المفضلة، الإعدادات.
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
- **المقاسات**: `AppLayout.pageMaxWidth = 1240`، `readingMaxWidth = 860`، `railBreakpoint = 940`.
- **الترويسة**: `AppPageHeader` يضع على الهاتف صفّاً علوياً مستقلاً (الشعار + الأدوات + `TextScaleControls`)
  ثم كتلة العنوان/العنوان الفرعي تحته، وعلى الشاشات العريضة صفّاً واحداً موسّعاً — فلا تتزاحم العناصر.
- **حجم الخط**: `TextScaleControls` (تكبير/تصغير) مركّب في `AppPageHeader` و`AppBar` لكل شاشة، ويتصرّف على
  `AppState.setTextScale` نفسه المستخدم في شريط الإعدادات.
- **السمة**: ألوان مستوحاة من خامات الصف الفني (طين `#B4462F`، نيلي `#1E5F74`، مغرة `#D9A34A`،
  أخضر `#4E7C59`، ورق `#F7F1E6`)، خط **Almarai** للنصوص و**Amiri** للعناوين، وكلاهما بترخيص OFL.

## الشاشات

| الشاشة | الوظيفة |
| --- | --- |
| `home_screen` | هوية، مساحة بحث، متابعة القراءة، إحصاءات، أقسام المحتوى، معاينة الوحدات |
| `index_screen` | فهرس كامل بتصفية وحالة قراءة وشارات لكل وحدة |
| `unit_screen` | قارئ وحدة: رسوم، موضوعات بقالبها، مصطلحات، لوحة، دعوة للاختبار، تنقّل سابق/تالٍ |
| `quiz_screen` | أسئلة الوحدة مع تصحيح تلقائي وكشف الإجابات ونتيجة قابلة لإعادة المحاولة |
| `lessons_screen` | فهرس الدروس التطبيقية الأربعة |
| `lesson_screen` | تبويب لكل حصة (نظري/عملي): أهداف، وسائل، مقدمة، عرض، واجب |
| `plates_screen` | معرض اللوحات المصوّرة |
| `plate_viewer_screen` | عرض ملء الشاشة مع تكبير وسحب وإسناد الصفحة |
| `glossary_screen` | المصطلحات وتعريفاتها وروابط وحداتها |
| `search_screen` | بحث فوري مع تصفية بالنوع |
| `favorites_screen` | المحفوظات (وضع مدمج داخل الهيكل) |
| `settings_screen` | الصف الدراسي، المظهر، حجم الخط، سجل التقدّم، عن المحتوى (وضع مدمج) |
| `grade_picker_screen` | اختيار الصف في أول تشغيل (وثالثة بطاقات للصفوف الثلاثة) |

## قيود مقصودة

- لا اتصال شبكي في أي طبقة: لا `http` ولا تحميل بعيد. كل الوسائط في الحزمة.
- لا قاعدة بيانات: حجم المحتوى ثابت ومعروف (‎< 1MB JSON)، والقراءة من الأصول أسرع وأبسط.
- لا `provider`/`riverpod`: `InheritedNotifier` يكفي ويقلّل التبعيات.
