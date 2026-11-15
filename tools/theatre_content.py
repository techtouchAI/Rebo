"""Content transcribed from the theatre page of the teacher guide.

«مفردات الأنشطة المسرحية» is a page of the guide whose themes are the material
of the lesson, not an artwork; the scanned page carries no text layer, so the
topics are transcribed here and shipped as a section of their own. The module
has no third-party dependency: both the content builder and the fidelity check
import it, and the check fails on any drift.
"""

from __future__ import annotations

from typing import Dict, List

THEATRE_TITLE = "مفردات الأنشطة المسرحية"
THEATRE_SUBTITLE = "موضوعات الأنشطة المسرحية للمرحلة المتوسطة"
THEATRE_INTRO = (
    "تتضمن مفردات الأنشطة المسرحية تمارين الصوت والإلقاء، ومشاهد مسرحية حياتية، "
    "ومسرحة مفردات المناهج، وعرضاً مسرحياً قصيراً، ووسائل تعليمية، وزيارات مسرحية."
)

THEATRE_TOPICS: List[Dict[str, object]] = [
    {
        "title": "تمارين في الصوت والإلقاء",
        "bullets": [
            "تمارين في الصوت والإلقاء مع التأكيد على استرخاء أجهزة النطق ومخارج الحروف.",
        ],
    },
    {
        "title": "تمارين مشاهد مسرحية حياتية",
        "bullets": [
            "لقاء شخص بعد طول غياب.",
            "حوار بين شخصين مختلفين في الرأي (تقبل الرأي الآخر).",
            "الأعمال الواجب القيام بها بعد النهوض من النوم والتهيؤ ليوم مدرسي.",
            "الخروج من البيت إلى المدرسة في صباح يوم ممطر.",
            "حضور حفلة ميلاد صديق وغيرها.",
        ],
    },
    {
        "title": "التدريب على مسرحة بعض مفردات المناهج وتقديمها",
        "bullets": [
            "مسرحة مفردات اللغة العربية والعلوم والتاريخ وغيرها وتقديمها.",
            "عرض مسرحي قصير (نص موجه مناسب للمرحلة العمرية) يتناول موضوع حقوق الإنسان "
            "والحريات والقيم الإنسانية النبيلة: الوفاء، والصدق، والأمانة، والتآخي، "
            "والتسامح، وتقبل الرأي الآخر.",
        ],
    },
    {
        "title": "عرض أفلام تعليمية",
        "bullets": [
            "عرض أفلام تعليمية عن المهارات الأدائية للصوت والجسم، وفعاليات تفيد التمارين المسرحية.",
        ],
    },
    {
        "title": "زيارات لمشاهدة عروض مسرحية",
        "bullets": [
            "زيارات لمشاهدة عروض مسرحية ومهرجانات.",
        ],
    },
]
