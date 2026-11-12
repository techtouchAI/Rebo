# أدوات البناء / Build tools

هذا المجلد يحتوي الأدوات **الرسمية** التي تُبنى بها حزمة APK. الملفات الثنائية
الكبيرة غير محفوظة في Git (انظر `.gitignore`)، وتُجلَب بـ:

```bash
bash tools/fetch-tools.sh      # يشرح المصادر ويجلبها إن توفّر الإنترنت
```

| الملف | المصدر الرسمي | الغرض |
|---|---|---|
| `aapt2` | Android SDK Build-Tools (Google) | تجميع وربط الموارد |
| `android.jar` | Android SDK Platform (`platforms/android-34/android.jar`) | مكتبة منصة أندرويد |
| `d8.jar` | Android SDK Build-Tools | تحويل الـ bytecode إلى DEX |
| `apksigner.jar` | Android SDK Build-Tools | توقيع APK (v1 + v2) |
| `ecj.jar` | Eclipse JDT Core (مُضمَّن في Build-Tools) | تصريف Java |
| `zipalign.py` | بديل مكتوب داخليًا يطابق سلوك `zipalign` | محاذاة الحزمة |

مصدر الأدوات: **Android Developers — Command line tools**
<https://developer.android.com/studio#command-line-tools-only>

الترخيص: Android SDK Build-Tools و`android.jar` تخضع لـ *Android SDK License*؛
`ecj.jar` يخضع لـ Eclipse Public License (EPL-2.0). لا تُعاد توزيعها في
حزم الإخراج (`dist/`).
