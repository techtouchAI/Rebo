"""Build a contact sheet of rendered pages (visual verification helper)."""
import sys
from PIL import Image, ImageDraw


def sheet(paths, out, cols=4, w=300):
    ims = [Image.open(p).convert("RGB") for p in paths]
    th = [im.resize((w, int(im.size[1] * w / im.size[0])), Image.LANCZOS) for im in ims]
    h = max(t.size[1] for t in th) + 22
    rows = (len(th) + cols - 1) // cols
    canvas = Image.new("RGB", (cols * (w + 8), rows * (h + 8)), "white")
    d = ImageDraw.Draw(canvas)
    for i, t in enumerate(th):
        r, c = divmod(i, cols)
        x, y = c * (w + 8), r * (h + 8)
        canvas.paste(t, (x, y + 18))
        d.text((x + 4, y + 4), paths[i].split("/")[-1], fill="black")
    canvas.save(out)
    return out


if __name__ == "__main__":
    print(sheet(sys.argv[2:], sys.argv[1]))
