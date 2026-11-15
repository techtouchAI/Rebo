"""Transcribed index of the fourteen topic drawings of the art-education booklet.

``التربية_الفنية_14_موضوعا_صورة_واحدة_لكل_موضوع.docx`` is a pure picture
document: one full page per topic and no text layer at all, so the caption of
every page exists only as pixels inside the image itself. The captions are
therefore transcribed here, exactly as they are drawn on the pages, and the
document order of the images is the order below. Both the content builder and
the fidelity check import this module; the check also proves that every shipped
asset is byte-identical to the image of its source page.

Each drawing is attached to the curriculum topic whose own source text states
what the drawing shows (see ``topicId``), so the reader can place the picture at
the start of that topic. The mapping is a structural link between two source
documents, not new content:

* «تصميم غلاف كتاب» / «بطاقة معايدة» / «بطاقة دعوة» →
  ``g1-u2/t2`` «التصميم الطباعي: تصميم الصحف والمجلات وأغلفة الكتب والبطاقات…»
* «تصميم إعلان» → ``g1-u2/t1`` «يظهر التصميم في أغلفة الكتب والبطاقات … والإعلانات»
* «تصميم زخارف بالحروف العربية» → ``g2-u2/t1`` «الخط العربي عنصراً تشكيلياً»
* «رسم أشكال هندسية منتظمة» → ``g2-u2/t2`` «الأشكال الهندسية المنتظمة»
* «تكوين زخرفي يعتمد على التكرار» → ``g1-u2/t4`` «قواعد التنظيم الزخرفي»
* «رسم وحدات زخرفية طبيعية أو هندسية» → ``g1-u2/t3`` «الوحدات الزخرفية ومصادرها»
* «تصميم زخرفة تعتمد على التماثل والتناظر» و«التوزيع النجمي» →
  ``g2-u2/t3`` «قواعد التصميم الزخرفي»
* «رسم جسم مع إظهار الضوء والظل» → ``g3-u1/t1`` «الضوء والظل وإظهار الحجم»
* «رسم الظل الساقط على سطح» و«تظليل الأشكال … تدرج القيم» →
  ``g2-u1/t5`` «الضوء والظل والتظليل»
* «رسم موضوع من الطبيعة» → ``g1-u1/t1`` «مصادر الموضوع الفني»
"""

from __future__ import annotations

from typing import Dict, List

DRAWINGS_TITLE = "موضوعات مصوّرة"
DRAWINGS_SUBTITLE = "صورة واحدة لكل موضوع من موضوعات الرسم"
DRAWINGS_INTRO = (
    "أربعة عشر موضوعاً عملياً في الرسم والتصميم والزخرفة، لكل موضوع صورة واحدة "
    "من المصدر نفسه. تظهر صورة كل موضوع في بداية الموضوع المرتبط به داخل الوحدة، "
    "وتُجمع كلها هنا وفي معرض اللوحات."
)

#: The fourteen pages of the source document, in document order. `unitId` and
#: `topicId` place the drawing at the start of the curriculum topic it shows.
DRAWINGS: List[Dict[str, str]] = [
    {"title": "تصميم غلاف كتاب", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم بطاقة معايدة", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم بطاقة دعوة", "unitId": "g1-u2", "topicId": "t2"},
    {"title": "تصميم إعلان", "unitId": "g1-u2", "topicId": "t1"},
    {"title": "تصميم زخارف بالحروف العربية", "unitId": "g2-u2", "topicId": "t1"},
    {"title": "رسم أشكال هندسية منتظمة", "unitId": "g2-u2", "topicId": "t2"},
    {"title": "تكوين زخرفي يعتمد على التكرار", "unitId": "g1-u2", "topicId": "t4"},
    {"title": "رسم وحدات زخرفية طبيعية أو هندسية", "unitId": "g1-u2", "topicId": "t3"},
    {"title": "تصميم زخرفة تعتمد على التماثل والتناظر", "unitId": "g2-u2", "topicId": "t3"},
    {"title": "رسم تكوين زخرفي بالتوزيع النجمي", "unitId": "g2-u2", "topicId": "t3"},
    {"title": "رسم جسم مع إظهار الضوء والظل", "unitId": "g3-u1", "topicId": "t1"},
    {"title": "رسم الظل الساقط على سطح", "unitId": "g2-u1", "topicId": "t5"},
    {"title": "تظليل الأشكال باستخدام تدرج القيم", "unitId": "g2-u1", "topicId": "t5"},
    {"title": "رسم موضوع من الطبيعة", "unitId": "g1-u1", "topicId": "t1"},
]
