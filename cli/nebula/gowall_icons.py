#!/usr/bin/env python3
"""
Recolor a whole icon theme with a gowall palette.

gowall's own icon route rasterizes each SVG and traces it back to vector, which
cannot scale to tens of thousands of icons. Instead the theme's *palette* goes
through gowall once — every unique hex in the theme is packed into a probe image,
converted, and read back — and the resulting map is substituted straight into the
SVG source, so the icons stay vector and the colors are exactly what gowall would
have produced.

Usage: gowall_icons.py <theme> [--source <IconTheme>] [--apply] [--force]
  theme     any name `gowall list` reports, or "match" for the live M3 palette
  --source  icon theme to recolor (default: the current GTK icon theme)
  --apply   switch the GTK icon theme to the result
  --restore switch back to the theme the active one was generated from
  --preview recolor a handful of icons only, and print `preview=<before>|<after>`

Prints progress as `progress=<done>/<total>` and finishes with `theme=<name>`.
"""

import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path

from nebula.gowall import resolve_theme_arg  # noqa: E402

SEARCH_DIRS = [
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
    Path("/usr/share/icons"),
]
INSTALL_DIR = Path.home() / ".local/share/icons"
STAMP       = ".gowall-stamp"

# Where the icon theme actually lives on this machine. gsettings is last on
# purpose: with QT_QPA_PLATFORMTHEME=qt6ct nothing reads it, so trusting it means
# recoloring a theme no application is using.
_THEME_KEYS = [
    (Path.home() / ".config/qt6ct/qt6ct.conf",    "icon_theme"),
    (Path.home() / ".config/qt5ct/qt5ct.conf",    "icon_theme"),
    (Path.home() / ".config/gtk-3.0/settings.ini", "gtk-icon-theme-name"),
    (Path.home() / ".config/gtk-4.0/settings.ini", "gtk-icon-theme-name"),
]
HEX         = re.compile(r"#([0-9a-fA-F]{6})\b|#([0-9a-fA-F]{3})\b")
RGB         = re.compile(r"rgb\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)")
CHUNK       = 400


def _log(msg):
    print(f"[gowall_icons] {msg}", file=sys.stderr, flush=True)


def _read_key(path, key):
    if not path.is_file():
        return ""
    for line in path.read_text(errors="ignore").splitlines():
        stripped = line.strip()
        if stripped.startswith(key + "="):
            return stripped.split("=", 1)[1].strip().strip("'\"")
    return ""


def _write_key(path, key, value):
    """Replaces the key in place, or adds it under the file's first section.
    Never creates a config file that isn't already there."""
    if not path.is_file():
        return False
    lines = path.read_text(errors="ignore").splitlines()
    for i, line in enumerate(lines):
        if line.strip().startswith(key + "="):
            lines[i] = f"{key}={value}"
            break
    else:
        insert = next((i for i, l in enumerate(lines) if l.strip().startswith("[")), -1)
        if insert < 0:
            return False
        lines.insert(insert + 1, f"{key}={value}")
    path.write_text("\n".join(lines) + "\n")
    return True


def _current_icon_theme():
    for path, key in _THEME_KEYS:
        value = _read_key(path, key)
        if value:
            return value
    try:
        out = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            capture_output=True, text=True, timeout=5)
        return out.stdout.strip().strip("'\"") or "hicolor"
    except Exception:
        return "hicolor"


def _apply_icon_theme(name):
    applied = []
    for path, key in _THEME_KEYS:
        if _write_key(path, key, name):
            applied.append(path.name)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface",
                    "icon-theme", name], capture_output=True)
    applied.append("gsettings")
    _log(f"icon-theme → {name} ({', '.join(applied)})")


def _find_theme(name):
    for base in SEARCH_DIRS:
        path = base / name
        if (path / "index.theme").is_file():
            return path
    return None


def _expand(hexval):
    h = hexval.lower()
    if len(h) == 3:
        return "#" + "".join(c * 2 for c in h)
    return "#" + h


def _collect(theme_dir):
    """Every file the derived theme needs, plus a fingerprint of the source.

    Icon themes are held together by symlinks at every level — Colloid-Dark's
    `apps/scalable` points into Colloid-Light, Papirus-Dark's `32x32` into
    Papirus. A link that leaves the theme has to be materialized or the copy
    would resolve straight back to un-recolored art; a link that stays inside is
    kept as a link so the copy stays small.
    """
    root = str(Path(theme_dir).resolve())
    bases = [root]
    jobs, stats = [], {"newest": 0.0, "size": 0}

    def add_file(path, rel):
        try:
            st = os.stat(path)
            stats["newest"] = max(stats["newest"], st.st_mtime)
            stats["size"] += st.st_size
        except OSError:
            return
        jobs.append(("svg" if path.endswith(".svg") else "copy", path, rel))

    def inside(target):
        return any(target == b or target.startswith(b + os.sep) for b in bases)

    def walk(src, prefix, depth):
        if depth > 12:
            return
        try:
            entries = sorted(os.scandir(src), key=lambda e: e.name)
        except OSError:
            return
        for e in entries:
            if e.name in ("icon-theme.cache", "index.theme", STAMP) and depth == 0:
                continue
            rel = os.path.normpath(os.path.join(prefix, e.name)) if prefix else e.name
            if e.is_symlink():
                target = os.path.realpath(e.path)
                if os.path.isdir(target):
                    if inside(target):
                        jobs.append(("linkdir", os.readlink(e.path), rel))
                    else:
                        bases.append(target)
                        walk(target, rel, depth + 1)
                elif os.path.isfile(target):
                    if inside(target):
                        jobs.append(("link", os.readlink(e.path), rel))
                    else:
                        add_file(target, rel)
                continue
            if e.is_dir():
                walk(e.path, rel, depth + 1)
            elif e.is_file():
                add_file(e.path, rel)

    walk(theme_dir, "", 0)
    return jobs, stats["newest"], stats["size"]


def _collect_colors(jobs):
    colors = set()
    for kind, src, _ in jobs:
        if kind != "svg":
            continue
        try:
            with open(src, encoding="utf-8", errors="ignore") as fh:
                text = fh.read()
                for m in HEX.finditer(text):
                    colors.add(_expand(m.group(1) or m.group(2)))
                for m in RGB.finditer(text):
                    colors.add(_rgb_hex(m))
        except OSError:
            continue
    return sorted(colors)


def _nn_env():
    """gowall's default color correction desaturates flat art — Spotify's green
    lands on grey, Firefox's orange on lavender. Its legacy nearest-neighbour
    backend keeps the hue, which is what icons need. It is only settable in
    ~/.config/gowall/config.yml, and gowall reads that from $HOME, so point HOME
    at a scratch copy rather than editing the user's own config."""
    home = Path.home() / ".cache" / "quickshell" / "gowall" / "nn-home"
    cfg = home / ".config" / "gowall"
    cfg.mkdir(parents=True, exist_ok=True)
    (cfg / "config.yml").write_text("ColorCorrectionBackend: nn\n")
    env = dict(os.environ)
    env["HOME"] = str(home)
    return env


def _map_palette(colors, theme_arg):
    """Pack the palette into a probe image, run it through gowall once, read the
    converted pixels back out. This is gowall's own mapping, not an imitation."""
    from PIL import Image

    tmp_dir = Path.home() / ".cache" / "quickshell" / "gowall"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    probe, out = tmp_dir / "icon-probe.png", tmp_dir / "icon-probe-out.png"

    img = Image.new("RGB", (len(colors), 1))
    img.putdata([tuple(int(c[i:i + 2], 16) for i in (1, 3, 5)) for c in colors])
    img.resize((len(colors) * 4, 4), Image.NEAREST).save(probe)

    proc = subprocess.run(
        ["gowall", "convert", str(probe), "-t", theme_arg,
         "--output", str(out), "--preview", "false", "--yes"],
        capture_output=True, text=True, timeout=120, env=_nn_env())
    if proc.returncode != 0 or not out.is_file():
        raise RuntimeError((proc.stderr or proc.stdout or "gowall failed").strip().splitlines()[-1])

    conv = Image.open(out).convert("RGB")
    return {c: "#%02x%02x%02x" % conv.getpixel((i * 4 + 1, 1)) for i, c in enumerate(colors)}


# Recognizable and colorful — enough spread that the palette's effect is obvious.
_PREVIEW_NAMES = [
    ("apps",   ["firefox", "firefox-browser", "web-browser"]),
    ("places", ["folder", "folder-blue", "user-home"]),
    ("apps",   ["spotify", "spotify-client", "music-player"]),
    ("apps",   ["code", "text-editor", "accessories-text-editor"]),
    ("apps",   ["kitty", "terminal", "utilities-terminal"]),
    ("apps",   ["gimp", "blender", "image-viewer"]),
]


def _find_icon(theme_dir, section, names):
    """Largest available rendering of the first name that exists."""
    roots = [theme_dir / section, theme_dir / f"{section}@2x"]
    for name in names:
        best, best_rank = None, -1
        for root in roots:
            if not root.is_dir():
                continue
            for size_dir in root.iterdir():
                candidate = size_dir / f"{name}.svg"
                if not candidate.is_file():
                    continue
                rank = 10000 if size_dir.name == "scalable" else _int_or_zero(size_dir.name)
                if rank > best_rank:
                    best, best_rank = candidate, rank
        if best is not None:
            return best
    return None


def _int_or_zero(text):
    try:
        return int(text.split("x")[0])
    except ValueError:
        return 0


def _preview(theme, theme_arg, theme_dir):
    out_dir = Path.home() / ".cache" / "quickshell" / "gowall" / "preview" / theme
    out_dir.mkdir(parents=True, exist_ok=True)

    picked = []
    for section, names in _PREVIEW_NAMES:
        found = _find_icon(theme_dir, section, names)
        if found is not None:
            picked.append(found)
    if not picked:
        _log(f"no preview icons found in {theme_dir.name}")
        return 1

    colors = set()
    for src in picked:
        with open(src, encoding="utf-8", errors="ignore") as fh:
            for m in HEX.finditer(fh.read()):
                colors.add(_expand(m.group(1) or m.group(2)))
    mapping = _map_palette(sorted(colors), theme_arg)

    global _MAP
    _MAP = mapping
    for src in picked:
        dst = out_dir / src.name
        with open(src, encoding="utf-8", errors="ignore") as fh:
            text = fh.read()
        dst.write_text(HEX.sub(_sub, text))
        print(f"preview={src}|{dst}", flush=True)
    return 0


_MAP = {}


def _init(mapping):
    global _MAP
    _MAP = mapping


def _sub(match):
    return _MAP.get(_expand(match.group(1) or match.group(2)), match.group(0))


def _rgb_hex(match):
    return "#%02x%02x%02x" % tuple(min(255, int(v)) for v in match.groups())


def _sub_rgb(match):
    return _MAP.get(_rgb_hex(match), match.group(0))


def _build_chunk(args):
    dest_root, jobs = args
    for kind, src, rel in jobs:
        dst = os.path.join(dest_root, rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        try:
            if kind in ("link", "linkdir"):
                if os.path.lexists(dst):
                    os.unlink(dst)
                os.symlink(src, dst)
            elif kind == "svg":
                with open(src, encoding="utf-8", errors="ignore") as fh:
                    text = fh.read()
                with open(dst, "w", encoding="utf-8") as fh:
                    fh.write(RGB.sub(_sub_rgb, HEX.sub(_sub, text)))
            else:
                shutil.copy2(src, dst)
        except OSError:
            continue
    return len(jobs)


def _write_index(theme_dir, dest, derived_name, source_name):
    src_index = theme_dir / "index.theme"
    lines = src_index.read_text(errors="ignore").splitlines() if src_index.is_file() else ["[Icon Theme]"]
    out = []
    for line in lines:
        if line.startswith("Name="):
            out.append(f"Name={derived_name}")
        elif line.startswith("Comment="):
            out.append(f"Comment={source_name} recolored by gowall")
        else:
            out.append(line)
    (dest / "index.theme").write_text("\n".join(out) + "\n")


def _recolor_assets(theme, theme_arg, theme_key):
    from nebula.paths import SHELL_DIR

    src = SHELL_DIR / "assets"
    dest = Path.home() / ".cache" / "quickshell" / "gowall" / f"assets-{theme}"
    jobs = [("svg", str(p), p.name) for p in sorted(src.glob("*.svg"))]
    newest = max((os.path.getmtime(j[1]) for j in jobs), default=0)
    stamp = dest / ".assets-stamp"
    current = stamp.read_text().strip() if stamp.is_file() else ""
    wanted = f"{newest:.0f}|{len(jobs)}|{theme_key}"
    if current != wanted:
        colors = _collect_colors(jobs)
        if colors:
            _init(_map_palette(colors, theme_arg))
            staging = dest.with_name(dest.name + ".building")
            shutil.rmtree(staging, ignore_errors=True)
            staging.mkdir(parents=True, exist_ok=True)
            _build_chunk((str(staging), jobs))
            for keep in ("icon-index.json", "source-index.json"):
                if (dest / keep).is_file():
                    shutil.copy2(dest / keep, staging / keep)
            (staging / ".assets-stamp").write_text(wanted)
            shutil.rmtree(dest, ignore_errors=True)
            staging.rename(dest)
    print(f"assets={dest}", flush=True)


_APP_DIRS = [
    Path.home() / ".local/share/applications",
    Path("/usr/share/applications"),
    Path("/var/lib/flatpak/exports/share/applications"),
    Path.home() / ".local/share/flatpak/exports/share/applications",
]
_CONTEXTS = ["apps", "places", "devices", "mimetypes", "categories", "status", "actions", "emblems"]


def _app_icon_names():
    names = set()
    for base in _APP_DIRS:
        if not base.is_dir():
            continue
        for desktop in base.glob("*.desktop"):
            names.add(desktop.stem)
            names.add(desktop.stem.lower())
            try:
                text = desktop.read_text(errors="ignore")
            except OSError:
                continue
            for line in text.splitlines():
                if line.startswith("Icon=") and not line[5:].startswith("/"):
                    names.add(line[5:].strip())
                elif line.startswith("StartupWMClass="):
                    names.add(line[15:].strip().lower())
    return {n for n in names if n}


_SIZE_DIRS = {}


def _size_dirs(base):
    key = str(base)
    if key not in _SIZE_DIRS:
        out = []
        if base.is_dir():
            sizes = sorted((d.name for d in base.iterdir() if d.is_dir()),
                           key=lambda d: (d != "scalable", -_int_or_zero(d)))
            for size in sizes:
                try:
                    out.append((base / size, set(os.listdir(base / size))))
                except OSError:
                    pass
        _SIZE_DIRS[key] = out
    return _SIZE_DIRS[key]


def _icon_file(theme_dir, name):
    for ctx in _CONTEXTS:
        for folder, files in _size_dirs(theme_dir / ctx):
            for ext in (".svg", ".png"):
                if name + ext in files:
                    path = folder / (name + ext)
                    if path.exists():
                        return str(path)
    return None


def _write_icon_index(derived_dir, source_dir, theme):
    index, source = {}, {}
    for name in sorted(_app_icon_names()):
        path = _icon_file(derived_dir, name)
        if path:
            index[name] = path
        original = _icon_file(source_dir, name)
        if original:
            source[name] = original
    dest = Path.home() / ".cache" / "quickshell" / "gowall" / f"assets-{theme}"
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "icon-index.json").write_text(json.dumps(index))
    (dest / "source-index.json").write_text(json.dumps(source))
    _log(f"indexed {len(index)} app icons")


def _finish(derived, apply_theme):
    if apply_theme:
        _apply_icon_theme(derived)
    print(f"theme={derived}")


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <theme> [--source NAME] [--force]", file=sys.stderr)
        return 1

    if "--restore" in sys.argv:
        active = _current_icon_theme()
        if not active.startswith("gowall-"):
            _log(f"icon theme is already {active}")
            print(f"theme={active}")
            return 0
        try:
            original = json.loads((INSTALL_DIR / active / STAMP).read_text())["source"]
        except Exception as e:
            _log(f"cannot tell what {active} was built from: {e}")
            return 1
        _apply_icon_theme(original)
        print(f"theme={original}")
        return 0

    theme = sys.argv[1].strip()
    force = "--force" in sys.argv
    preview_only = "--preview" in sys.argv
    apply_theme = "--apply" in sys.argv
    source_name = _current_icon_theme()
    if "--source" in sys.argv:
        idx = sys.argv.index("--source")
        if idx + 1 < len(sys.argv):
            source_name = sys.argv[idx + 1]

    # The active theme is usually one of ours already — recolor what it came from,
    # never a copy of a copy.
    if source_name.startswith("gowall-"):
        try:
            source_name = json.loads((INSTALL_DIR / source_name / STAMP).read_text())["source"]
        except Exception:
            _log(f"cannot tell what '{source_name}' was built from — pass --source")
            return 1

    theme_dir = _find_theme(source_name)
    if theme_dir is None:
        _log(f"icon theme not found: {source_name}")
        return 1

    if shutil.which("gowall") is None:
        _log("gowall is not installed")
        return 1

    if preview_only:
        try:
            theme_arg, _ = resolve_theme_arg(theme)
        except Exception as e:
            _log(f"cannot resolve theme '{theme}': {e}")
            return 1
        return _preview(theme, theme_arg, theme_dir)

    t_start = time.time()
    derived = f"gowall-{source_name}-{theme}"
    dest = INSTALL_DIR / derived

    jobs, newest, total_size = _collect(theme_dir)

    try:
        theme_arg, theme_key = resolve_theme_arg(theme)
    except Exception as e:
        _log(f"cannot resolve theme '{theme}': {e}")
        return 1

    fingerprint = hashlib.sha256(
        f"{source_name}|{theme_key}|nn|{len(jobs)}|{newest:.0f}|{total_size}".encode()).hexdigest()[:24]

    stamp = dest / STAMP
    if not force and stamp.is_file():
        try:
            if json.loads(stamp.read_text()).get("fingerprint") == fingerprint:
                _log(f"up to date — {derived}")
                if "/" not in theme:
                    _write_icon_index(dest, theme_dir, theme)
                    _recolor_assets(theme, theme_arg, theme_key)
                _finish(derived, apply_theme)
                return 0
        except Exception:
            pass

    colors = _collect_colors(jobs)
    if not colors:
        _log(f"no colors found in {source_name}")
        return 1
    _log(f"{source_name}: {len(jobs)} files, {len(colors)} unique colors, "
         f"{total_size / 1048576:.0f}MB")

    try:
        mapping = _map_palette(colors, theme_arg)
    except Exception as e:
        _log(f"palette mapping failed: {e}")
        return 1

    staging = INSTALL_DIR / (derived + ".building")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True, exist_ok=True)

    chunks = [(str(staging), jobs[i:i + CHUNK]) for i in range(0, len(jobs), CHUNK)]
    done = 0
    with ProcessPoolExecutor(initializer=_init, initargs=(mapping,)) as pool:
        for count in pool.map(_build_chunk, chunks):
            done += count
            print(f"progress={done}/{len(jobs)}", flush=True)

    _write_index(theme_dir, staging, derived, source_name)
    stamp_data = {"fingerprint": fingerprint, "source": source_name, "theme": theme,
                  "files": len(jobs), "colors": len(colors), "bytes": total_size}
    (staging / STAMP).write_text(json.dumps(stamp_data))

    shutil.rmtree(dest, ignore_errors=True)
    staging.rename(dest)

    # One generated theme at a time — each is a full copy of the source.
    for old in INSTALL_DIR.glob("gowall-*"):
        if old.name != derived and (old / STAMP).is_file():
            shutil.rmtree(old, ignore_errors=True)
            _log(f"removed stale {old.name}")

    _log(f"built {derived} in {time.time() - t_start:.1f}s")
    if "/" not in theme:
        _write_icon_index(dest, theme_dir, theme)
        _recolor_assets(theme, theme_arg, theme_key)
    _finish(derived, apply_theme)
    return 0


if __name__ == "__main__":
    sys.exit(main())
