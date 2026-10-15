#!/usr/bin/env python3
"""
Recolor a wallpaper with gowall and cache the result.

Prints the path the rest of the pipeline should use — the recolored image on
success, the untouched original whenever gowall is off, missing or fails, so a
broken gowall can never stop a wallpaper from being set.

Usage: gowall_theme.py <image> <theme> [--invert]
  theme     off              pass the original through
            match            build a gowall theme from the live M3 palette
            <name>|<x.json>  any theme `gowall list` reports, or a theme file
  --invert  flip the image's colors first — a daylight photo comes back as night,
            and the palette then lands on the flipped image
"""

import hashlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

CACHE_DIR   = Path.home() / ".cache" / "quickshell" / "gowall"
COLORS_JSON = Path.home() / ".cache" / "quickshell" / "colors.json"
KEEP        = 30
TIMEOUT     = 180

# Ordered darkest → lightest with the accents last. gowall snaps every pixel to
# its nearest palette entry, so the ramp has to span the full luminance range or
# the image collapses into a flat two-tone.
_MATCH_ROLES = [
    "surfaceContainerLowest", "surface", "surfaceContainerLow",
    "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest",
    "surfaceVariant", "outline", "surfaceVariantText", "surfaceText",
    "primaryContainer", "primary", "primaryFixed",
    "secondary", "tertiaryContainer", "tertiary", "tertiaryFixed", "error",
]


def _log(msg: str) -> None:
    print(f"[gowall_theme] {msg}", file=sys.stderr, flush=True)


def _image_hash(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()[:24]


def _match_palette() -> list:
    colors = json.loads(COLORS_JSON.read_text())
    palette, seen = [], set()
    for role in _MATCH_ROLES:
        hexval = str(colors.get(role, "")).strip().lower()
        if hexval.startswith("#") and len(hexval) == 7 and hexval not in seen:
            seen.add(hexval)
            palette.append(hexval)
    if len(palette) < 4:
        raise ValueError(f"palette too small ({len(palette)} colors)")
    return palette


def _write_theme_file(palette: list, key: str) -> Path:
    path = CACHE_DIR / f"match-{key}.json"
    fd, tmp = tempfile.mkstemp(dir=CACHE_DIR, suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump({"name": "quickshell-match", "colors": palette}, f)
    os.replace(tmp, path)
    return path


def resolve_theme_arg(theme: str):
    """(argument for gowall -t, cache key). "match" is materialized into a theme
    file built from the live M3 palette; everything else passes through."""
    if theme.lower() == "kindle":
        from nebula.paths import SHELL_DIR
        return str(SHELL_DIR / "assets" / "gowall" / "kindle.json"), "kindle"
    if theme.lower() != "match":
        return theme, theme
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    palette = _match_palette()
    digest = hashlib.sha256(",".join(palette).encode()).hexdigest()[:16]
    return str(_write_theme_file(palette, digest)), f"match-{digest}"


def _nn_env() -> dict:
    home = CACHE_DIR / "nn-home"
    (home / ".config" / "gowall").mkdir(parents=True, exist_ok=True)
    (home / ".config" / "gowall" / "config.yml").write_text("ColorCorrectionBackend: nn\n")
    env = dict(os.environ)
    env["HOME"] = str(home)
    return env


def recover_palette(theme: str) -> list:
    """The exact colors of a gowall theme, read back out of gowall itself.

    A dense RGB probe converted with the nearest-neighbour backend collapses to
    precisely the theme's palette — nord returns its 16 canonical hexes. Works for
    any theme `gowall list` knows, custom ones included, so nothing here has to
    carry a hand-written copy of a palette that can drift.
    """
    from PIL import Image

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    cache = CACHE_DIR / f"palette-{theme}.json"
    if cache.is_file():
        try:
            palette = json.loads(cache.read_text())
            if palette:
                return palette
        except Exception:
            pass

    theme_arg, _ = resolve_theme_arg(theme)
    steps = list(range(0, 256, 17))
    grid = [(r, g, b) for r in steps for g in steps for b in steps]
    probe, out = CACHE_DIR / "palette-probe.png", CACHE_DIR / "palette-probe-out.png"
    img = Image.new("RGB", (len(grid), 1))
    img.putdata(grid)
    img.resize((len(grid) * 2, 2), Image.NEAREST).save(probe)

    proc = subprocess.run(
        ["gowall", "convert", str(probe), "-t", theme_arg,
         "--output", str(out), "--preview", "false", "--yes"],
        capture_output=True, text=True, timeout=TIMEOUT, env=_nn_env())
    if proc.returncode != 0 or not out.is_file():
        raise RuntimeError((proc.stderr or proc.stdout or "gowall failed").strip().splitlines()[-1])

    converted = Image.open(out).convert("RGB")
    palette = sorted({"#%02x%02x%02x" % px for px in converted.getdata()})
    cache.write_text(json.dumps(palette))
    _log(f"recovered {len(palette)} colors for '{theme}'")
    return palette


def _invert(image: str, out: Path) -> bool:
    proc = subprocess.run(
        ["gowall", "invert", image, "--output", str(out), "--preview", "false", "--yes"],
        capture_output=True, text=True, timeout=TIMEOUT)
    if proc.returncode != 0 or not (out.is_file() and out.stat().st_size > 0):
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        _log(f"invert failed (exit {proc.returncode}): {detail[-1] if detail else 'no output'}")
        return False
    return True


def _prune() -> None:
    files = sorted(CACHE_DIR.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True)
    for stale in files[KEEP:]:
        try:
            stale.unlink()
        except OSError:
            pass


def main() -> int:
    if "--palette" in sys.argv:
        idx = sys.argv.index("--palette")
        if idx + 1 >= len(sys.argv):
            print("--palette needs a theme name", file=sys.stderr)
            return 1
        theme = sys.argv[idx + 1]
        try:
            recover_palette(theme)
        except Exception as e:
            _log(f"cannot recover palette for '{theme}': {e}")
            return 1
        print(CACHE_DIR / f"palette-{theme}.json")
        return 0

    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <image> <theme>", file=sys.stderr)
        return 1

    print(convert(sys.argv[1], sys.argv[2].strip(), "--invert" in sys.argv, "--nn" in sys.argv))
    return 0


def convert(image: str, theme: str, invert: bool = False, nn: bool = False) -> str:
    themed = bool(theme) and theme.lower() not in ("off", "none")

    if not themed and not invert:
        return image

    if not os.path.isfile(image):
        _log(f"image not found: {image}")
        return image

    if shutil.which("gowall") is None:
        _log("gowall is not installed — passing the original through")
        return image

    fresh = not CACHE_DIR.is_dir()
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    if fresh:
        # The greetd greeter (uid greeter) reads the wallpaper straight out of
        # this cache; the inherited default ACL grants r-- , which is not enough
        # to traverse a directory.
        try:
            subprocess.run(["setfacl", "-m", "u:greeter:rx", str(CACHE_DIR)],
                           capture_output=True, timeout=5)
        except Exception:
            pass

    theme_key = "off"
    theme_arg = ""
    if themed:
        try:
            theme_arg, theme_key = resolve_theme_arg(theme)
        except Exception as e:
            _log(f"cannot resolve theme '{theme}': {e}")
            return image

    key = hashlib.sha256(
        f"{_image_hash(image)}|{theme_key}|{'inv' if invert else 'std'}{'|nn' if nn else ''}".encode()).hexdigest()[:24]
    out = CACHE_DIR / f"{key}.png"

    if out.is_file() and out.stat().st_size > 0:
        _log(f"cache hit — {out.name}")
        return str(out)

    try:
        source = image
        if invert:
            # Invert first, the way gowall documents it: the palette then lands on
            # the flipped image rather than being flipped itself.
            flipped = CACHE_DIR / f"{key}-inverted.png"
            if not _invert(image, flipped):
                return image
            if not themed:
                flipped.replace(out)
                _log(f"inverted → {out.name}")
                _prune()
                return str(out)
            source = str(flipped)

        proc = subprocess.run(
            ["gowall", "convert", source, "-t", theme_arg,
             "--output", str(out), "--preview", "false", "--yes"],
            capture_output=True, text=True, timeout=TIMEOUT, env=_nn_env() if nn else None)
    except subprocess.TimeoutExpired:
        _log(f"gowall timed out after {TIMEOUT}s")
        return image

    if proc.returncode != 0 or not (out.is_file() and out.stat().st_size > 0):
        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        _log(f"gowall failed (exit {proc.returncode}): {detail[-1] if detail else 'no output'}")
        try:
            out.unlink()
        except OSError:
            pass
        return image

    if invert:
        try:
            (CACHE_DIR / f"{key}-inverted.png").unlink()
        except OSError:
            pass

    _log(f"converted with '{theme}'{' (inverted)' if invert else ''} → {out.name}")
    _prune()
    return str(out)


if __name__ == "__main__":
    sys.exit(main())
