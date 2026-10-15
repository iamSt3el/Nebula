#!/usr/bin/env python3
import os
import sys

KEEP = 8


def main():
    src, out, w, h = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    if os.path.exists(out) and os.path.getmtime(out) >= os.path.getmtime(src):
        print(out)
        return

    from PIL import Image

    flags = sys.argv[5:]
    if "--eink" in flags:
        from nebula import gowall
        src = gowall.convert(src, "kindle", nn=True)

    im = Image.open(src)
    im.draft("RGB", (w, h))
    im = im.convert("L").convert("RGB") if "--grey" in flags or "--eink" in flags else im.convert("RGB")
    scale = max(w / im.width, h / im.height)
    if scale < 1:
        im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)

    os.makedirs(os.path.dirname(out), exist_ok=True)
    tmp = out + ".tmp"
    im.save(tmp, "JPEG", quality=92)
    os.replace(tmp, out)

    folder = os.path.dirname(out)
    files = sorted((os.path.join(folder, f) for f in os.listdir(folder) if f.endswith(".jpg")),
                   key=os.path.getmtime, reverse=True)
    for stale in files[KEEP:]:
        os.remove(stale)
    print(out)


if __name__ == "__main__":
    main()
