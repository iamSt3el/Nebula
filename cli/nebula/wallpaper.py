import json
import os
import random
import subprocess
import sys
from pathlib import Path

from nebula import settings
from nebula.paths import COLORS, HOME

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".bmp"}


def _self(args):
    r = subprocess.run([sys.executable, "-m", "nebula", *args], capture_output=True, text=True)
    if r.stderr:
        sys.stderr.write(r.stderr)
    lines = [l for l in r.stdout.splitlines() if l.strip()]
    return lines[-1].strip() if lines else ""


def _scheme(args) -> None:
    from nebula import scheme
    saved = sys.argv
    sys.argv = ["nebula scheme generate", *args]
    try:
        scheme.main()
    except SystemExit as e:
        if e.code not in (None, 0):
            print(f"[nebula] scheme generate exited with {e.code}", file=sys.stderr)
    finally:
        sys.argv = saved


def defaults() -> dict:
    t = settings.section("theme")
    g = settings.section("general")
    scheme = "scheme-custom" if g.get("palette") == "custom" else t.get("matugenScheme", "scheme-content")
    return {
        "scheme": scheme,
        "mode": t.get("matugenTheme", "dark"),
        "gowall": t.get("gowallTheme", "off"),
        "icons": "on" if t.get("gowallIcons") else "off",
        "invert": "on" if t.get("gowallInvert") else "off",
        "shell": "on" if t.get("gowallShell") else "off",
    }


def apply(wallpaper, scheme, mode, gowall="off",
          icons="off", invert="off", shell="off") -> int:
    if not os.path.isfile(wallpaper):
        print(f"[nebula] no such image: {wallpaper}", file=sys.stderr)
        return 1
    mode = mode.lower()
    gw = (gowall or "off").lower()
    display = wallpaper

    palette_on = gw not in ("", "off", "none")
    invert_on = invert.lower() == "on"
    inv = ["--invert"] if invert_on else []
    icons_on = palette_on and icons.lower() == "on"
    keep = ["--keep-icon-theme"] if icons_on else []
    shell_on = palette_on and shell.lower() == "on" and gw != "match"

    pal = []
    if shell_on:
        palette_file = _self(["gowall", "--palette", gowall])
        if palette_file and os.path.isfile(palette_file):
            pal = ["--palette-file", palette_file]

    if palette_on and gw == "match":
        _scheme([wallpaper, scheme, mode, *keep])
        converted = _self(["gowall", wallpaper, "match", *inv])
        if converted and os.path.isfile(converted):
            display = converted
        _scheme([wallpaper, scheme, mode, "--display", display, *keep])
    elif palette_on or invert_on:
        converted = _self(["gowall", wallpaper, gowall, *inv])
        if converted and os.path.isfile(converted):
            display = converted
        _scheme([display, scheme, mode, "--source", wallpaper, *keep, *pal])
    else:
        _scheme([wallpaper, scheme, mode])

    if icons_on:
        _self(["gowall-icons", gowall, "--apply"])
    return 0


def current() -> str:
    try:
        c = json.loads(COLORS.read_text())
    except Exception:
        return ""
    return c.get("sourceWallpaper") or c.get("wallpaper") or ""


def wallpaper_dir() -> Path:
    d = settings.section("general").get("wallpaperDir") or str(HOME / "wallpaper")
    return Path(os.path.expanduser(d))


def pick_random(folder: Path) -> str:
    now = current()
    files = [str(p) for p in folder.rglob("*")
             if p.is_file() and p.suffix.lower() in IMAGE_EXTS and "/." not in str(p)]
    choices = [f for f in files if f != now] or files
    return random.choice(choices) if choices else ""
