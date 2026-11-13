# البناء والتوزيع

## المتطلبات

| المكوّن | الإصدار | ملاحظة |
| --- | --- | --- |
| Flutter SDK | 3.35.0 (stable) | Dart 3.9 |
| JDK | 17 (Temurin) | مطلوب لـ AGP 8.9.1 |
| Android SDK | API 36 (compile/target) | minSdk 24 |
| Gradle / AGP / Kotlin | 8.12 / 8.9.1 / 2.1.0 | من قوالب Flutter 3.35.0 |
| Visual Studio 2022 | Desktop development with C++ | لبناء ويندوز فقط |
| Python | 3.10+ | لأدوات المحتوى والتحقق (ليست مطلوبة للتطبيق) |

هوية التطبيق: `applicationId = com.techtouchai.mirsam`، اسم الحزمة `مِرسم`، اسم الملف التنفيذي `mirsam.exe`.

## أوامر أساسية

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release            # build/app/outputs/flutter-apk/app-release.apk
flutter build apk --split-per-abi      # نسخ أصغر لكل معمارية إن لزم
flutter build windows --release        # build/windows/x64/runner/Release/mirsam.exe
```

## توقيع APK

التوقيع يُقرأ من `android/key.properties` وهو **غير مُتضمَّن في المستودع** (مستثنى في `.gitignore`):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=…
keyAlias=upload
keyPassword=…
```

بدون هذا الملف يُبنى الإصدار بمفتاح التنقيح (debug) ليبقى قابلاً للتجربة — وهو ما تفعله CI.
لا تُحفظ أي كلمة مرور أو مفتاح داخل المستودع.

لإنشاء مفتاح رفع (مرة واحدة، خارج المستودع):

```bash
keytool -genkeypair -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 \
        -validity 10000 -alias upload
```

## توزيع ويندوز

**ملف EXE وحده ليس حزمة توزيع.** مجلد `build/windows/x64/runner/Release` يحتوي:

```
mirsam.exe
flutter_windows.dll
data/                 (flutter_assets + icudtl.dat)
*.dll                 (ملحقات القابلات إن وُجدت)
```

يجب توزيع المجلد كاملاً (أو مضغوطاً ZIP)، ويمكن أن يعمل من مجلد عادي دون تثبيت.
على أجهزة ويندوز 10/11 الحديثة تكون حزمة **Microsoft Visual C++ Redistributable 2015–2022 (x64)** مثبّتة عادةً؛
إن ظهر خطأ في `VCRUNTIME140.dll` أو `MSVCP140.dll` فيجب تثبيتها من موقع Microsoft الرسمي.

لتثبيت أنيق (قائمة ابدأ، اختصار، إزالة) يمكن لاحقاً توليد حزمة **MSIX** عبر
`msix` (حزمة نشر مجتمعية) بعد مراجعة أمنها — لم تُضَف الآن لأنها تبعية بناء إضافية غير لازمة للتشغيل.

## مخرجات CI

`.github/workflows/ci.yml` ينفّذ أربع وظائف على كل دفعة:

| الوظيفة | ما تفعله | الأثر |
| --- | --- | --- |
| `Content fidelity` | `verify_content.py` + التحقق من صحة JSON | حماية المحتوى من أي تغيير غير موثّق |
| `Analyze and test` | `flutter analyze` و`flutter test` | تقرير التحليل + `resolved-pubspec.lock` |
| `Android APK` | بناء APK بتوقيع التنقيح | `mirsam-<sha>.apk` + `SHA256SUMS.txt` |
| `Windows EXE` | بناء ويندوز وضغط المجلد كاملاً | `mirsam-<sha>-windows-x64.zip` + بصمة SHA-256 |

Flutter يُنزَّل من أرشيف الإصدارات الرسمي:
`https://storage.googleapis.com/flutter_infra_release/releases/stable/<platform>/…-3.35.0-stable.*`

## إصدار نسخة جديدة

1. ارفع `version:` في `pubspec.yaml` (مثال: `1.1.0+2`) — رقم البناء يزيد دائماً.
2. `python3 tools/build_content.py && python3 tools/verify_content.py`.
3. `flutter analyze && flutter test`.
4. ادفع إلى الفرع، ثم ابنِ APK وZIP ويندوز من مخرجات CI.
5. أرفق `SHA256SUMS.txt` مع كل ملف منشور، ولا ترفع مفاتيح التوقيع.

## استكشاف الأخطاء

| العرض | السبب المرجّح | الحل |
| --- | --- | --- |
| `Unable to load asset` عند الإقلاع | مجلد أصول غير مُعلن في `pubspec.yaml` | تحقّق من قسم `assets:` (المجلدات الأربعة معلنة) |
| خطأ `NDK not found` | لا يوجد NDK 27.0.12077973 في بيئة البناء | ثبّته من Android SDK Manager أو اتركه — لا كود أصلي في المشروع |
| `key.properties` غير موجود | بناء إصدار بلا مفتاح | يُستخدم مفتاح التنقيح تلقائياً (سلوك مقصود) |
| النص العربي لا يظهر في عنوان النافذة | ترجمة حرفية غير مرمّزة | العنوان مكتوب بتسلسلات `\uXXXX` في `windows/runner/main.cpp` |
