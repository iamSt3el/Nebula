import importlib.util
import json
import os
import shutil
import sys

from nebula.paths import HOME

TOOLS = [
    ("quickshell",    "quickshell",     "The shell itself"),
    ("hyprctl",       "hyprland",       "Compositor"),
    ("hypridle",      "hypridle",       "Idle and sleep timeouts"),
    ("matugen",       "matugen-bin",    "Album-art colours"),
    ("cliphist",      "cliphist",       "Clipboard"),
    ("wl-copy",       "wl-clipboard",   "Copy and paste"),
    ("wtype",         "wtype",          "Paste from the clipboard pocket"),
    ("brightnessctl", "brightnessctl",  "Brightness"),
    ("grimblast",     "grimblast-git",  "Screenshots"),
    ("slurp",         "slurp",          "Region selection"),
    ("swappy",        "swappy",         "Annotation"),
    ("hyprpicker",    "hyprpicker",     "Colour picker"),
    ("magick",        "imagemagick",    "Image tools"),
    ("wf-recorder",   "wf-recorder",    "Recording"),
    ("ffmpeg",        "ffmpeg",         "Recording thumbnails"),
    ("cava",          "cava",           "Visualiser"),
    ("qalc",          "libqalculate",   "Calculator"),
    ("kdeconnect-cli", "kdeconnect",    "Phone panel"),
    ("sshfs",         "sshfs",          "Browsing the phone"),
    ("ffmpegthumbnailer", "ffmpegthumbnailer", "Phone video thumbnails"),
    ("qrencode",      "qrencode",       "Wi-Fi QR code"),
    ("playerctl",     "playerctl",      "Media keys"),
    ("tesseract",     "tesseract",      "Live Text"),
    ("mpv",           "mpv",            "Soundscape"),
    ("paplay",        "libpulse",       "Sounds"),
    ("notify-send",   "libnotify",      "Notifications from scripts"),
    ("jq",            "jq",             "Clipboard pocket"),
    ("ddcutil",       "ddcutil",        "Monitor brightness over DDC"),
    ("gowall",        "gowall",         "Gowall palettes"),
]

MODULES = [
    ("materialyoucolor", "python-materialyoucolor", "Wallpaper colours"),
    ("PIL",              "python-pillow",           "Image scaling and previews"),
]


def check():
    rows = []
    for cmd, pkg, what in TOOLS:
        rows.append({"kind": "command", "name": cmd, "package": pkg, "what": what,
                     "ok": shutil.which(cmd) is not None})
    for mod, pkg, what in MODULES:
        rows.append({"kind": "python", "name": mod, "package": pkg, "what": what,
                     "ok": importlib.util.find_spec(mod) is not None})
    tcmalloc = "/usr/lib/libtcmalloc_minimal.so.4"
    rows.append({"kind": "file", "name": "libtcmalloc_minimal", "package": "gperftools",
                 "what": "Lower memory use (nebula start preloads it)", "ok": os.path.exists(tcmalloc)})
    hypr_lua = HOME / ".config" / "hypr" / "hyprland.lua"
    rows.append({"kind": "file", "name": "~/.config/hypr/hyprland.lua", "package": "",
                 "what": "Lua Hyprland config (hyprland.conf is not supported)", "ok": hypr_lua.is_file()})
    templates = HOME / ".config" / "matugen" / "templates"
    rows.append({"kind": "file", "name": str(templates).replace(str(HOME), "~", 1),
                 "package": "", "what": "App colour templates", "ok": templates.is_dir()})
    return rows


def run(as_json: bool) -> int:
    rows = check()
    missing = [r for r in rows if not r["ok"]]
    if as_json:
        print(json.dumps({"python": sys.executable, "checks": rows}))
        return 0
    tty = sys.stdout.isatty()
    good = "\033[32m✓\033[0m" if tty else "ok  "
    bad = "\033[31m✗\033[0m" if tty else "MISS"
    for r in rows:
        tail = f"  ({r['package']})" if not r["ok"] and r["package"] else ""
        print(f"  {good if r['ok'] else bad} {r['name']:<22} {r['what']}{tail}")
    print(f"\npython: {sys.executable}")
    pkgs = sorted({r["package"] for r in missing if r["package"]})
    if pkgs:
        print("Install: yay -S " + " ".join(pkgs))
    elif not missing:
        print("Everything Nebula needs is here.")
    return 1 if missing else 0
