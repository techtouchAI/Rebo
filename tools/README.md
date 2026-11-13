# tools/ — أدوات البناء والتحقق

كل ما تحتاجه عملية البناء القابلة للتكرار. الملفات الثنائية الكبيرة **غير
محفوظة في Git** (انظر `.gitignore`) وتُجلب من مصادرها الرسمية.

## أدوات Android (رسمية)

| الملف | المصدر | الغرض |
|---|---|---|
| `aapt2` | Android SDK **Build-Tools 34.0.0** | تجميع وربط الموارد |
| `android.jar` | Android SDK **Platform 34** | مكتبة منصة أندرويد |
| `d8.jar` | Android SDK Build-Tools | تحويل الـ bytecode إلى DEX |
| `apksigner.jar` | Android SDK Build-Tools | توقيع APK (v1 + v2 + v3) |
| `ecj.jar` | Eclipse JDT Core (مضمَّن في Build-Tools) | تصريف Java |

المصدر الرسمي: <https://developer.android.com/studio#command-line-tools-only>
انظر `fetch-tools.sh` لخطوات الإحضار. الترخيص: Android SDK License / EPL-2.0،
ولا تُضمَّن هذه الأدوات في أي ملف إخراج.

## أدوات مكتوبة داخل المستودع

| الملف | الغرض |
|---|---|
| `lib/common.sh` | دوال مشتركة: تسجيل، تحقق من المتطلبات، أرقام الإصدار |
| `sync-version.py` | مصدر واحد للإصدار (`package.json`) → كل الملفات |
| `zipalign.py` | محاذاة APK (4 بايت + 16 كيلو للـ `.so`) مع وضع `--verify` |
| `verify-pe.py` | فحص ثنائيات ويندوز: المعمارية، الـ manifest، الأيقونة، النسخة، الحمولة |
| `check.py` | بوابات الإصدار الكاملة (الإصدار، المحتوى، الأصول، JS، APK، EXE) |
| `make_manifest.py` | كتابة `dist/SHA256SUMS.txt` |

## الاستخدام

```bash
bash build-all.sh                 # APK + Windows + المثبّت + البصمات + الفحوص
bash build-all.sh --content       # يعيد توليد data.js من ملفات .docx أولًا

python3 tools/sync-version.py             # انشر إصدار package.json على كل الملفات
python3 tools/sync-version.py --check     # تحقق فقط (يفشل إن كان هناك تعارض)
python3 tools/check.py                    # بوابات الجودة
python3 tools/check.py --skip apk         # تخطّي ما يحتاج JDK
```

## بناء قابل للتكرار

`zipalign.py` و`build-android.sh` يحترمان `SOURCE_DATE_EPOCH`:

```bash
SOURCE_DATE_EPOCH=$(git log -1 --format=%ct) bash build-android.sh
```

## رفع رقم الإصدار

```bash
# 1. عدّل "version" في package.json
# 2. انشر الرقم على كل الملفات
python3 tools/sync-version.py
# 3. أعد البناء والفحص
bash build-all.sh
```

`versionCode` لأندرويد يُحسب تلقائيًا من `MAJOR*10000 + MINOR*100 + PATCH`،
وأسماء ملفات الإخراج تتبع الإصدار (`rebo-android-v1.2.3.apk`).
