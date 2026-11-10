"""
Stage 3.7 -- ASSESSMENT CLOSURE.

The brief is explicit: a question may not test information the plan no longer
shows, and condensing may not remove what an answer needs.

So the quiz is not decoration bolted on at the end -- it is a CONSTRAINT on the
condensation:

    1. parse the source's own questions and answer key (never rewritten),
    2. take each keyed correct answer,
    3. prove that answer still appears in the condensed content,
    4. where it does not, re-admit the unit that carries it (in source order).

That makes "the answer key matches the content" a checkable property instead of
an intention.
"""
from __future__ import annotations

import re

from .didactic import _flat

# «أ) نص الخيار» inside a multiple-choice stem
_OPTION = re.compile(r"([\u0621-\u064A])\)\s*([^\n]{2,400})")
# «1 ـ أ» / «1 - أ» in the key line
_KEY_MC = re.compile(r"(\d{1,2})\s*[ـ\-–]\s*([أ-ي])\b")
_KEY_TF = re.compile(r"(\d{1,2})\s*[ـ\-–]\s*(صح|خطأ)")


def _parse_mc(text):
    """[(stem, [(letter, option)])]"""
    out = []
    cur = None
    for line in text.split("\n"):
        s = line.strip()
        if not s:
            continue
        m = re.match(r"^(\d{1,2})\.\s*(.+)$", s)
        if m:
            cur = {"n": int(m.group(1)), "stem": m.group(2).strip(),
                   "options": []}
            out.append(cur)
            for lm, opt in _OPTION.findall(cur["stem"]):
                cur["options"].append((lm, opt.strip()))
            continue
        if cur is not None:
            for lm, opt in _OPTION.findall(s):
                cur["options"].append((lm, opt.strip()))
    return out


def extract(appendix):
    """
    Read the source's assessment block.

    Returns {'mc': [...], 'tf': [...], 'key': {...}, 'raw': [text]}
    The question text is kept byte-for-byte; only its stops are recognised.
    """
    texts = [a.get("text", "") for a in appendix if a.get("text")]
    mc, tf, key, raw = [], [], {}, list(texts)

    for t in texts:
        if "الاختيار" in _flat(t) or "مفتاح" in _flat(t):
            continue
        for line in t.split("\n"):
            line = line.strip()
            if re.match(r"^\d{1,2}\.", line) and ("( )" in line or "()" in line):
                tf.append({"n": len(tf) + 1, "text": line})
    for t in texts:
        found = _parse_mc(t)
        if found and any(o for q in found for o in q["options"]):
            mc.extend(found)

    for t in texts:
        low = _flat(t)
        if "الاختيار من متعدد" not in low:
            continue
        # The key is ONE sentence: «الاختيار من متعدد: 1 ـ أ، 2 ـ ج، 3 ـ ب
        #  الصح والخطأ: 1 ـ صح، 2 ـ خطأ، 3 ـ صح».  Each half restarts its own
        # numbering, so they are read on separate substrings and never share a
        # counter.
        k = t.find("الصح والخطأ")
        mc_part, tf_part = (t[:k], t[k:]) if k > 0 else (t, "")
        for n, letter in _KEY_MC.findall(mc_part):
            key.setdefault("mc", {})[int(n)] = letter
        for n, val in _KEY_TF.findall(tf_part or ""):
            key.setdefault("tf", {})[int(n)] = val
    return {"mc": mc, "tf": tf, "key": key, "raw": raw}


def correct_answers(quiz):
    """The keyed correct option texts, which the plan must still teach."""
    out = []
    for q in quiz["mc"]:
        letter = quiz["key"].get("mc", {}).get(q["n"])
        if not letter:
            continue
        for lm, opt in q["options"]:
            if lm == letter:
                out.append({"kind": "mc", "n": q["n"], "text": opt})
    return out


def _present(answer, teaching):
    """Is this answer still shown, verbatim, anywhere in the taught content?"""
    needle = _flat(answer)
    if not needle:
        return True
    for s in teaching["sections"]:
        if needle in _flat(s.get("title", "")):
            return True
        for a in s["axes"]:
            if needle in _flat(a.get("title", "")):
                return True
            for b in a["blocks"]:
                if needle in _flat(b["text"]):
                    return True
    return False


def validate(quiz, teaching):
    """
    Returns (ok, rows).  `rows` records, per question, whether its keyed answer
    is still taught.  A failure is a real defect: the reader cannot answer it.
    """
    rows, ok = [], True
    for ans in correct_answers(quiz):
        good = _present(ans["text"], teaching)
        ok = ok and good
        rows.append({"kind": ans["kind"], "n": ans["n"],
                     "answer": ans["text"], "taught": good})
    return ok, rows


# --------------------------------------------------------------------------- #
# generated questions -- derived, never invented
# --------------------------------------------------------------------------- #
# The source's own quiz stays verbatim.  These add the other formats the brief
# lists, but ONLY where the plan itself supplies the evidence:
#   definition  a term the plan defines with «هو / هي / يعني / عبارة عن»
#   enumeration an axis the plan itself presents as an ordered list
#   comparison  two axes the plan explicitly contrasts (تختلف / بينما / في حين)
# A generator with no evidence returns None: no question is manufactured to fill
# a format.

TERM_STOP = ("ومن", "وهو", "وهي", "كما", "هذا", "ذلك", "التي", "الذي", "أن",
             "في", "من", "على", "إن", "ان")


def _axes(teaching):
    return [a for s in teaching["sections"] for a in s["axes"]]


def definition_question(teaching):
    """A term the plan itself defines, asked in the brief's format."""
    for a in _axes(teaching):
        for b in a["blocks"]:
            for m in re.finditer(
                    r"(?:^|[.\n،]\s*)([\u0621-\u064A]{2,}(?:\s[\u0621-\u064A]{2,}){0,2})"
                    r"\s*:?\s*(?:هو|هي|يعني|تعني|عبارة عن)\s", b["text"]):
                term = m.group(1).strip()
                if term.split()[0] in TERM_STOP:
                    continue
                if not (1 <= len(term.split()) <= 3):
                    continue
                # the answer is the defining unit, verbatim
                return {"kind": "definition",
                        "prompt": "عرّف: %s" % term,
                        "answer": b["text"]}
    return None


def enumeration_question(teaching):
    """An axis the plan presents as a list of independent items."""
    for a in _axes(teaching):
        bullets = [b for b in a["blocks"] if b["kind"] == "bullet"]
        if len(bullets) >= 3:
            return {"kind": "enumeration",
                    "prompt": "عدّد ما يذكره الدرس في «%s»."
                              % (a.get("title") or "هذا المحور"),
                    "answer": " / ".join(b["text"] for b in bullets[:4])}
        if len(a["blocks"]) >= 5 and a.get("title"):
            return {"kind": "enumeration",
                    "prompt": "اذكر أهم ما ورد في «%s»." % a["title"],
                    "answer": " / ".join(b["text"] for b in a["blocks"][:3])}
    return None


CONTRAST = ("تختلف", "يختلف", "بينما", "في حين", "على العكس", "أما ")


def comparison_question(teaching):
    """
    Only when the plan ITSELF contrasts two topics.  The brief forbids
    inventing a comparison the source does not make.
    """
    for sec in teaching["sections"]:
        axes = [a for a in sec["axes"] if a["blocks"] and a.get("title")]
        for i in range(len(axes) - 1):
            one, two = axes[i], axes[i + 1]
            body = " ".join(b["text"] for b in one["blocks"] + two["blocks"])
            if not any(c in body for c in CONTRAST):
                continue
            return {"kind": "comparison",
                    "prompt": "قارن بين «%s» و«%s» كما وردت المقارنة في الدرس."
                              % (one["title"], two["title"]),
                    "answer": "؛ ".join(
                        [one["blocks"][0]["text"], two["blocks"][0]["text"]])}
    return None


def generated(teaching):
    """Extra questions, each backed by printed content. Missing evidence = no
    question of that kind."""
    out = []
    for fn in (definition_question, enumeration_question,
               comparison_question):
        q = fn(teaching)
        if q:
            out.append(q)
    return out
