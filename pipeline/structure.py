"""
Stage 3.5 — DISPLAY SEGMENTATION (paragraph rhythm).

The source cells are walls of text: one 2,197-character cell holds ten separate
ideas.  This module decides where to *show* paragraph breaks.  It never edits:

  * every segment is a *slice* of the original string,
  * concatenating the segments in order reproduces the input byte for byte.

Nothing is summarised, reworded, reordered or dropped.  A break is only ever
inserted at an existing character position; no character is added or removed
(Word renders the break, it is not stored in <w:t>).
"""

# ---- where a break is allowed ------------------------------------------------
# 1. A source newline is real data: the author pressed Enter. Always a break.
STRONG = "\n"

# 2. An enumerator that starts a new item. Only used when it follows sentence
#    punctuation, so "أولاً" mid-sentence never causes a split.
ENUMERATORS = (
    "أولاً", "أولًا", "ثانياً", "ثانيًا", "ثالثاً", "ثالثًا",
    "رابعاً", "رابعًا", "خامساً", "سادساً",
    "أ-", "ب-", "ج-", "د-", "هـ-",
    "1-", "2-", "3-", "4-", "5-", "6-",
    "•",
)

# 3. Sentence enders in Arabic prose.
ENDERS = (". ", "؟ ", "! ", ": ", "… ", "» ")

# ---- paragraph geometry ------------------------------------------------------
# A paragraph of 380-450 characters fills roughly 7-8 lines of the 3.85in
# content column: long enough to read as a paragraph, short enough that the eye
# finds its place again. These are DISPLAY targets, not content limits.
PARA_MAX = 430
PARA_MIN = 80          # never leave a stub paragraph shorter than this behind
PARA_HARD = 900        # a single unpunctuated run longer than this is split at a space


def _sentence_cuts(text):
    """Offsets (exclusive) where a sentence ends, in ascending order."""
    cuts, i, n = [], 0, len(text)
    while i < n:
        for end in ENDERS:
            if text.startswith(end, i):
                j = i + len(end)
                rest = text[j:j + 12].lstrip()
                if rest.startswith(ENUMERATORS) or rest[:1].isupper():
                    cuts.append(j)
                elif end in (". ", "؟ ", "! "):
                    cuts.append(j)
                break
        i += 1
    return sorted(set(cuts))


def _run_cuts(text):
    """Break positions that start an enumerator item (used to open a paragraph)."""
    cuts = []
    for en in ENUMERATORS:
        start = 0
        while True:
            k = text.find(en, start)
            if k == -1:
                break
            start = k + len(en)
            if k == 0:
                cuts.append(k)
                continue
            prev = text[max(0, k - 3):k]
            if prev.rstrip().endswith((".", ":", "؟", "!", "»")):
                cuts.append(k)
    return sorted(set(cuts))


def segments(text):
    """
    Return the ordered list of paragraph strings for one cell value.

    Partition guarantee: "".join(segments(t)) == t  (asserted).
    """
    text = "" if text is None else str(text)
    if not text:
        return [""]

    # 1. hard split on real line breaks, remembering the separator per block
    blocks, buf = [], []
    for ch in text:
        if ch == STRONG:
            blocks.append("".join(buf))
            buf = []
        else:
            buf.append(ch)
    blocks.append("".join(buf))

    out = []
    for bi, block in enumerate(blocks):
        # re-attach the newline to the block it terminated, so the concatenation
        # stays exact when we later re-split on display targets
        piece_out = _split_block(block)
        if bi < len(blocks) - 1:
            piece_out[-1] = piece_out[-1] + STRONG
        out.extend(piece_out)
    assert "".join(out) == text, "segmentation altered the text"
    return out


def _split_block(block):
    """Split one newline-free block on sentence / enumerator targets."""
    if len(block) <= PARA_MAX:
        return [block]

    allowed = sorted(set(_sentence_cuts(block) + _run_cuts(block) + [len(block)]))
    allowed = [c for c in allowed if 0 < c <= len(block)]

    out, start = [], 0
    while start < len(block):
        limit = start + PARA_MAX
        if len(block) - start <= PARA_MAX:
            out.append(block[start:])
            break
        # furthest legal cut that still fits the target width
        cands = [c for c in allowed if start < c <= limit]
        cut = cands[-1] if cands else None
        if cut is None:
            # runaway text without punctuation: cut at the last space
            hard = block.rfind(" ", start, min(start + PARA_HARD, len(block)))
            cut = hard + 1 if hard > start else min(start + PARA_HARD, len(block))
        # avoid leaving a stub behind
        if 0 < len(block) - cut < PARA_MIN:
            later = [c for c in allowed if cut < c <= cut + PARA_MIN]
            if later:
                cut = later[-1]
        out.append(block[start:cut])
        start = cut
    return out or [block]


def pack_rows(segments_list, limit):
    """
    Group whole paragraphs into rows that each fit one screen-height row.

    Whole paragraphs are kept together, so a list item is never cut in half by a
    row boundary. A single paragraph longer than `limit` is split at a sentence
    boundary (last resort: a space).

    Partition guarantee: "".join(flat) == "".join(segments_list).
    """
    flat = [s for s in segments_list]
    packed, cur, cur_len = [], [], 0
    for seg in flat:
        pieces = [seg]
        if len(seg) > limit:
            pieces = _split_to(seg, limit)
        for piece in pieces:
            if cur and cur_len + len(piece) > limit:
                packed.append(cur)
                cur, cur_len = [], 0
            cur.append(piece)
            cur_len += len(piece)
    if cur:
        packed.append(cur)
    assert "".join("".join(p) for p in packed) == "".join(flat)
    return packed or [[""]]


def _split_to(text, limit):
    out, rest = [], text
    while len(rest) > limit:
        window = rest[:limit]
        cut = -1
        for sep in (STRONG, "•", ". ", "، ", " "):
            k = window.rfind(sep)
            if k > limit * 0.45:
                cut = k + (len(sep) if sep != " " else 1)
                break
        if cut <= limit * 0.45:
            cut = limit
        out.append(rest[:cut])
        rest = rest[cut:]
    if rest:
        out.append(rest)
    assert "".join(out) == text
    return out
