"""Instantiate the static Arabic weights used by the template and the previewer."""
import os, sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.normpath(os.path.join(HERE, "..", "templates", "assets"))
SRC_CANDIDATES = [
    "/usr/local/lib/python3.11/dist-packages/fontpkg_noto_naskh_arabic/files/NotoNaskhArabic[wght].ttf",
]

def main():
    src = next((p for p in SRC_CANDIDATES if os.path.exists(p)), None)
    if not src:
        print("variable source font not found; install fontpkg-noto-naskh-arabic")
        return 1
    for weight, name in ((400, "Regular"), (700, "Bold")):
        f = TTFont(src)
        inst = instantiateVariableFont(f, {"wght": weight}, inplace=True)
        out = os.path.join(ASSETS, "NotoNaskhArabic-%s.ttf" % name)
        inst.save(out)
        print("wrote", out, os.path.getsize(out), "bytes")
    return 0

if __name__ == "__main__":
    sys.exit(main())
