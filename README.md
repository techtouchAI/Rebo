# مشروع خطط التربية الفنية — القالب ومحرك التحويل

خطّط أسبوعية لمادة التربية الفنية (المرحلة المتوسطة) على قالب موحّد مطابق
للتصميم المرجعي `تصميم الخطة.jpg`.

## الحالة

* **المرحلة 0 + 1 مكتملة** — القالب، محرّك التحويل، وعينتان (`19` الأصغر، `14` الأكبر).
* الملفات الأصلية **لم تُعدَّل** (بصمات SHA-256 في `baseline/manifest.json`).
* التوليد الكامل للملفات الـ14 **لم يبدأ** بانتظار المراجعة.

## البنية

```
pipeline/     محرّك التحويل (extract → clean → model → render)
tools/        بناء العيّنات، تدقيق الفقدان، المعاينة البصرية
tests/        23 اختبار Regression
samples/      العيّنات + النموذج الوسيط + سجل التغييرات
baseline/     بصمات الملفات الأصلية
templates/    القالب والأصول (بانر، تذييل، خطوط)
docs/         تقارير وأدلة بصرية
محتوى مكتمل/  المرجع البصري القديم (لم يُعدَّل)
```

## التشغيل

```bash
python3 tools/make_fonts.py
python3 tools/build_sample.py 19 14
python3 tools/check_lossless.py 19_*.docx 14_*.docx
python3 -m pytest tests/test_pipeline.py -q
python3 tools/render_preview.py samples/plan_19.docx out.pdf page
```

## المتطلبات

`python-docx`, `lxml`, `pytest`, `pillow`, `reportlab`, `arabic-reshaper`,
`python-bidi`, `pymupdf`, `fonttools`, `fontpkg-noto-naskh-arabic`.

## الوثائق

* `تقرير_تحليلي_وخطة_التعديل.md` — التحليل الأولي
* `تقرير_المرحلة_0_و1.md` — تقرير التنفيذ الحالي
