#!/usr/bin/env python3
"""Rasterise the project's SVG illustrations for local visual review.

Only the small SVG subset used by ``assets/illustrations`` is supported:
rect / circle / ellipse / line / polygon / polyline / path (M L H V C Q Z),
fill / stroke / stroke-width / stroke-dasharray / opacity.  This keeps the
preview honest: what renders here renders in ``flutter_svg`` as well.

    python3 tools/preview_svg.py out_dir
"""

from __future__ import annotations

import math
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

from PIL import Image, ImageDraw

NS = "{http://www.w3.org/2000/svg}"
SCALE = 2  # supersampling factor


def _parse_color(value: str | None, opacity: float = 1.0):
    if value is None or value in ("none", "transparent"):
        return None
    value = value.strip()
    if value.startswith("#"):
        hexa = value[1:]
        if len(hexa) == 3:
            hexa = "".join(ch * 2 for ch in hexa)
        rgb = tuple(int(hexa[i:i + 2], 16) for i in (0, 2, 4))
        if len(hexa) == 8:
            alpha = int(hexa[6:8], 16)
            return rgb + (int(alpha * opacity),)
        return rgb + (int(255 * opacity),)
    named = {
        "white": (255, 255, 255),
        "black": (0, 0, 0),
        "none": None,
    }
    if value in named:
        return named[value]
    raise ValueError(f"unsupported colour: {value}")


def _num(value: str | None, default: float = 0.0) -> float:
    if value is None:
        return default
    return float(re.sub(r"[a-zA-Z%]", "", value))


def _dashes(value: str | None):
    if not value:
        return None
    parts = [float(p) for p in re.split(r"[,\s]+", value.strip()) if p]
    return parts or None


def _sample_cubic(p0, p1, p2, p3, steps=24):
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        mt = 1 - t
        x = (mt ** 3) * p0[0] + 3 * (mt ** 2) * t * p1[0] + 3 * mt * (t ** 2) * p2[0] + (t ** 3) * p3[0]
        y = (mt ** 3) * p0[1] + 3 * (mt ** 2) * t * p1[1] + 3 * mt * (t ** 2) * p2[1] + (t ** 3) * p3[1]
        points.append((x, y))
    return points


def _sample_quad(p0, p1, p2, steps=20):
    points = []
    for i in range(1, steps + 1):
        t = i / steps
        mt = 1 - t
        x = (mt ** 2) * p0[0] + 2 * mt * t * p1[0] + (t ** 2) * p2[0]
        y = (mt ** 2) * p0[1] + 2 * mt * t * p1[1] + (t ** 2) * p2[1]
        points.append((x, y))
    return points


TOKEN_RE = re.compile(r"([MmLlHhVvCcQqZz])|(-?\d*\.?\d+(?:[eE][-+]?\d+)?)")


def path_to_subpaths(d: str):
    tokens = []
    for cmd, num in TOKEN_RE.findall(d):
        tokens.append(cmd if cmd else float(num))
    subpaths = []
    current = []
    pos = (0.0, 0.0)
    start = (0.0, 0.0)
    i = 0
    command = None
    while i < len(tokens):
        token = tokens[i]
        if isinstance(token, str):
            command = token
            i += 1
            if command in "Zz":
                if current:
                    current.append(start)
                    subpaths.append(current)
                    current = []
                pos = start
            continue
        if command is None:
            i += 1
            continue
        upper = command.upper()
        relative = command.islower()
        if upper in "ML":
            x, y = tokens[i], tokens[i + 1]
            i += 2
            point = (pos[0] + x, pos[1] + y) if relative else (x, y)
            if not current:
                current = [point]
                start = point
            else:
                current.append(point)
            pos = point
        elif upper == "H":
            x = tokens[i]
            i += 1
            point = (pos[0] + x, pos[1]) if relative else (x, pos[1])
            current.append(point)
            pos = point
        elif upper == "V":
            y = tokens[i]
            i += 1
            point = (pos[0], pos[1] + y) if relative else (pos[0], y)
            current.append(point)
            pos = point
        elif upper == "C":
            pts = tokens[i:i + 6]
            i += 6
            if relative:
                pts = [pos[0] + pts[0], pos[1] + pts[1], pos[0] + pts[2], pos[1] + pts[3],
                       pos[0] + pts[4], pos[1] + pts[5]]
            if not current:
                current = [pos]
                start = pos
            current.extend(_sample_cubic(pos, (pts[0], pts[1]), (pts[2], pts[3]), (pts[4], pts[5])))
            pos = (pts[4], pts[5])
        elif upper == "Q":
            pts = tokens[i:i + 4]
            i += 4
            if relative:
                pts = [pos[0] + pts[0], pos[1] + pts[1], pos[0] + pts[2], pos[1] + pts[3]]
            if not current:
                current = [pos]
                start = pos
            current.extend(_sample_quad(pos, (pts[0], pts[1]), (pts[2], pts[3])))
            pos = (pts[2], pts[3])
        else:
            i += 1
    if current:
        subpaths.append(current)
    return subpaths


def _dashed_polyline(points, dashes):
    """Split a polyline into dash segments."""
    if not dashes:
        return [points]
    pattern = dashes * 40
    segments = []
    current = []
    pattern_index = 0
    remaining = pattern[0]
    drawing = True
    for index in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[index], points[index + 1]
        seg_len = math.hypot(x1 - x0, y1 - y0)
        travelled = 0.0
        while travelled < seg_len:
            step = min(remaining, seg_len - travelled)
            ratio0 = travelled / seg_len if seg_len else 0
            ratio1 = (travelled + step) / seg_len if seg_len else 0
            p0 = (x0 + (x1 - x0) * ratio0, y0 + (y1 - y0) * ratio0)
            p1 = (x0 + (x1 - x0) * ratio1, y0 + (y1 - y0) * ratio1)
            if drawing:
                if not current:
                    current = [p0]
                current.append(p1)
            elif current:
                segments.append(current)
                current = []
            travelled += step
            remaining -= step
            if remaining <= 1e-6:
                pattern_index = (pattern_index + 1) % len(pattern)
                remaining = pattern[pattern_index]
                drawing = not drawing
    if current:
        segments.append(current)
    return segments


def render(svg_path: Path, target: Path, background=(247, 242, 233)) -> None:
    root = ET.parse(svg_path).getroot()
    viewbox = root.get("viewBox")
    if viewbox:
        _, _, vb_w, vb_h = [float(v) for v in re.split(r"[,\s]+", viewbox.strip())]
    else:
        vb_w = _num(root.get("width"), 800)
        vb_h = _num(root.get("height"), 520)
    width = int(vb_w * SCALE)
    height = int(vb_h * SCALE)
    image = Image.new("RGBA", (width, height), background + (255,))
    draw = ImageDraw.Draw(image, "RGBA")

    def scaled(points):
        return [(x * SCALE, y * SCALE) for x, y in points]

    def merged(element, inherited):
        attrs = dict(inherited)
        for key in ("fill", "stroke", "stroke-width", "stroke-dasharray", "opacity",
                    "fill-opacity", "stroke-opacity"):
            if element.get(key) is not None:
                attrs[key] = element.get(key)
        return attrs

    def common(element, inherited):
        attrs = merged(element, inherited)
        opacity = float(attrs.get("opacity", 1))
        fill_opacity = float(attrs.get("fill-opacity", 1)) * opacity
        stroke_opacity = float(attrs.get("stroke-opacity", 1)) * opacity
        fill = _parse_color(attrs.get("fill"), fill_opacity)
        stroke = _parse_color(attrs.get("stroke"), stroke_opacity)
        stroke_width = _num(attrs.get("stroke-width"), 1.0) * SCALE
        dashes = _dashes(attrs.get("stroke-dasharray"))
        if dashes:
            dashes = [d * SCALE for d in dashes]
        return fill, stroke, stroke_width, dashes

    def draw_shape(element, inherited=None):
        inherited = inherited or {}
        tag = element.tag.replace(NS, "")
        style = merged(element, inherited)
        fill, stroke, stroke_width, dashes = common(element, inherited)
        if tag == "rect":
            x, y = _num(element.get("x")), _num(element.get("y"))
            w, h = _num(element.get("width")), _num(element.get("height"))
            radius = _num(element.get("rx") or element.get("ry"))
            box = [x * SCALE, y * SCALE, (x + w) * SCALE, (y + h) * SCALE]
            if radius and dashes:
                draw.rounded_rectangle(box, radius=radius * SCALE, outline=stroke, width=max(1, int(stroke_width)))
            elif radius:
                draw.rounded_rectangle(box, radius=radius * SCALE, fill=fill,
                                       outline=stroke, width=max(1, int(stroke_width)) if stroke else 0)
            elif dashes:
                for seg in _dashed_polyline([(box[0], box[1]), (box[2], box[1]), (box[2], box[3]),
                                             (box[0], box[3]), (box[0], box[1])], dashes):
                    draw.line(scaled(seg), fill=stroke, width=max(1, int(stroke_width)))
            else:
                draw.rectangle(box, fill=fill, outline=stroke,
                               width=max(1, int(stroke_width)) if stroke else 0)
        elif tag in ("circle", "ellipse"):
            cx, cy = _num(element.get("cx")), _num(element.get("cy"))
            if tag == "circle":
                rx = ry = _num(element.get("r"))
            else:
                rx, ry = _num(element.get("rx")), _num(element.get("ry"))
            box = [(cx - rx) * SCALE, (cy - ry) * SCALE, (cx + rx) * SCALE, (cy + ry) * SCALE]
            if dashes:
                points = [(cx + rx * math.cos(a), cy + ry * math.sin(a))
                          for a in [i * math.pi / 36 for i in range(73)]]
                for seg in _dashed_polyline(points, dashes):
                    draw.line(scaled(seg), fill=stroke, width=max(1, int(stroke_width)))
            else:
                draw.ellipse(box, fill=fill, outline=stroke,
                             width=max(1, int(stroke_width)) if stroke else 0)
        elif tag == "line":
            points = [(_num(element.get("x1")), _num(element.get("y1"))),
                      (_num(element.get("x2")), _num(element.get("y2")))]
            for seg in _dashed_polyline(points, dashes):
                draw.line(scaled(seg), fill=stroke or (0, 0, 0, 255), width=max(1, int(stroke_width)))
        elif tag in ("polygon", "polyline"):
            raw = element.get("points", "")
            values = [float(v) for v in re.split(r"[,\s]+", raw.strip()) if v]
            points = list(zip(values[0::2], values[1::2]))
            if tag == "polygon" and not dashes:
                draw.polygon(scaled(points), fill=fill, outline=stroke,
                             width=max(1, int(stroke_width)) if stroke else 1)
            else:
                if fill and tag == "polygon":
                    draw.polygon(scaled(points), fill=fill,
                                 outline=stroke, width=max(1, int(stroke_width)) if stroke else 1)
                else:
                    for seg in _dashed_polyline(points, dashes):
                        draw.line(scaled(seg), fill=stroke or (0, 0, 0, 255),
                                  width=max(1, int(stroke_width)))
        elif tag == "path":
            for subpath in path_to_subpaths(element.get("d", "")):
                if len(subpath) < 2:
                    continue
                if fill and not dashes:
                    draw.polygon(scaled(subpath), fill=fill)
                if stroke:
                    for seg in _dashed_polyline(subpath, dashes):
                        draw.line(scaled(seg), fill=stroke, width=max(1, int(stroke_width)))
        elif tag in ("g", "svg"):
            for child in element:
                draw_shape(child, style)

    draw_shape(root)
    image = image.convert("RGB").resize((int(vb_w), int(vb_h)), Image.LANCZOS)
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, "PNG")


def main() -> None:
    out_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/preview")
    source_dir = Path(__file__).resolve().parents[1] / "assets" / "illustrations"
    count = 0
    for svg in sorted(source_dir.glob("*.svg")):
        target = out_dir / (svg.stem + ".png")
        render(svg, target)
        count += 1
    print(f"rendered {count} illustrations into {out_dir}")


if __name__ == "__main__":
    main()
