#!/usr/bin/env python3
"""
Generate Material You colors from a wallpaper image and apply to all app templates.

Caching layers:
  1. score cache  — primary HCT int per image hash (avoids re-quantizing same image)
  2. colors cache — full output JSON per image+variant+mode (instant repeat access)

Usage: gen_colors.py <image> <scheme-variant> <mode> [--source P] [--display P]
  scheme-variant  content | expressive | fidelity | fruitsalad | monochrome |
                  neutral | rainbow | tonalspot | vibrant
  mode            dark | light
  --source        the untouched wallpaper behind <image>, recorded as
                  "sourceWallpaper" so re-applies never feed a gowall-recolored
                  image back into the pipeline (default: <image>)
  --display       the image actually shown on screen, recorded as "wallpaper"
                  (default: <image>)
  --keep-icon-theme
                  leave the GTK icon theme alone (a gowall icon theme owns it)
  --palette-file  JSON array of hex colors (a gowall theme, recovered by
                  gowall_theme.py --palette). The scheme is then built from that
                  fixed palette instead of from the wallpaper.
"""

import colorsys
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from materialyoucolor.dislike.dislike_analyzer import DislikeAnalyzer
from materialyoucolor.dynamiccolor.material_dynamic_colors import MaterialDynamicColors
from materialyoucolor.hct import Hct
from materialyoucolor.quantize import ImageQuantizeCelebi, QuantizeCelebi
from materialyoucolor.scheme.scheme_content import SchemeContent
from materialyoucolor.score.score import Score, ScoreOptions
from materialyoucolor.scheme.scheme_expressive import SchemeExpressive
from materialyoucolor.scheme.scheme_fidelity import SchemeFidelity
from materialyoucolor.scheme.scheme_fruit_salad import SchemeFruitSalad
from materialyoucolor.scheme.scheme_monochrome import SchemeMonochrome
from materialyoucolor.scheme.scheme_neutral import SchemeNeutral
from materialyoucolor.scheme.scheme_rainbow import SchemeRainbow
from materialyoucolor.scheme.scheme_tonal_spot import SchemeTonalSpot
from materialyoucolor.scheme.scheme_vibrant import SchemeVibrant
from materialyoucolor.utils.math_utils import sanitize_degrees_int

from nebula import apps as theme_apps

_HOME       = Path.home()
CACHE_DIR   = Path.home() / ".cache" / "quickshell"
OUTPUT_PATH = CACHE_DIR / "colors.json"

# Extra plain-copy targets: apps that just want the raw colors.json (same
# format as OUTPUT_PATH) rather than a matugen-style rendered template.
_EXTRA_COPY_PATHS = [
    Path.home() / ".config" / "orbit" / "colors.json",
]

_SCHEMES = {
    "content":    SchemeContent,
    "expressive": SchemeExpressive,
    "fidelity":   SchemeFidelity,
    "fruitsalad": SchemeFruitSalad,
    "monochrome": SchemeMonochrome,
    "neutral":    SchemeNeutral,
    "rainbow":    SchemeRainbow,
    "tonalspot":  SchemeTonalSpot,
    "vibrant":    SchemeVibrant,
}

# MaterialDynamicColors attr name → our JSON key (for quickshell colors.json)
_COLOR_MAP = {
    "primary":                    "primary",
    "onPrimary":                  "primaryText",
    "primaryContainer":           "primaryContainer",
    "onPrimaryContainer":         "primaryContainerText",
    "primaryFixed":               "primaryFixed",
    "primaryFixedDim":            "primaryFixedDim",
    "onPrimaryFixed":             "onPrimaryFixed",
    "onPrimaryFixedVariant":      "onPrimaryFixedVariant",
    "secondary":                  "secondary",
    "onSecondary":                "secondaryText",
    "secondaryContainer":         "secondaryContainer",
    "onSecondaryContainer":       "secondaryContainerText",
    "secondaryFixed":             "secondaryFixed",
    "secondaryFixedDim":          "secondaryFixedDim",
    "onSecondaryFixed":           "onSecondaryFixed",
    "onSecondaryFixedVariant":    "onSecondaryFixedVariant",
    "tertiary":                   "tertiary",
    "onTertiary":                 "tertiaryText",
    "tertiaryContainer":          "tertiaryContainer",
    "onTertiaryContainer":        "tertiaryContainerText",
    "tertiaryFixed":              "tertiaryFixed",
    "tertiaryFixedDim":           "tertiaryFixedDim",
    "onTertiaryFixed":            "onTertiaryFixed",
    "onTertiaryFixedVariant":     "onTertiaryFixedVariant",
    "error":                      "error",
    "onError":                    "errorText",
    "errorContainer":             "errorContainer",
    "onErrorContainer":           "errorContainerText",
    "surface":                    "surface",
    "onSurface":                  "surfaceText",
    "surfaceVariant":             "surfaceVariant",
    "onSurfaceVariant":           "surfaceVariantText",
    "outline":                    "outline",
    "outlineVariant":             "outlineVariant",
    "shadow":                     "shadow",
    "scrim":                      "scrim",
    "inverseSurface":             "inverseSurface",
    "inverseOnSurface":           "inverseSurfaceText",
    "inversePrimary":             "inversePrimary",
    "surfaceDim":                 "surfaceDim",
    "surfaceBright":              "surfaceBright",
    "surfaceContainerLowest":     "surfaceContainerLowest",
    "surfaceContainerLow":        "surfaceContainerLow",
    "surfaceContainer":           "surfaceContainer",
    "surfaceContainerHigh":       "surfaceContainerHigh",
    "surfaceContainerHighest":    "surfaceContainerHighest",
}

# Our JSON key → matugen snake_case name (for app templates)
_KEY_TO_MATUGEN = {
    "primary":                  "primary",
    "primaryText":              "on_primary",
    "primaryContainer":         "primary_container",
    "primaryContainerText":     "on_primary_container",
    "primaryFixed":             "primary_fixed",
    "primaryFixedDim":          "primary_fixed_dim",
    "onPrimaryFixed":           "on_primary_fixed",
    "onPrimaryFixedVariant":    "on_primary_fixed_variant",
    "secondary":                "secondary",
    "secondaryText":            "on_secondary",
    "secondaryContainer":       "secondary_container",
    "secondaryContainerText":   "on_secondary_container",
    "secondaryFixed":           "secondary_fixed",
    "secondaryFixedDim":        "secondary_fixed_dim",
    "onSecondaryFixed":         "on_secondary_fixed",
    "onSecondaryFixedVariant":  "on_secondary_fixed_variant",
    "tertiary":                 "tertiary",
    "tertiaryText":             "on_tertiary",
    "tertiaryContainer":        "tertiary_container",
    "tertiaryContainerText":    "on_tertiary_container",
    "tertiaryFixed":            "tertiary_fixed",
    "tertiaryFixedDim":         "tertiary_fixed_dim",
    "onTertiaryFixed":          "on_tertiary_fixed",
    "onTertiaryFixedVariant":   "on_tertiary_fixed_variant",
    "error":                    "error",
    "errorText":                "on_error",
    "errorContainer":           "error_container",
    "errorContainerText":       "on_error_container",
    "surface":                  "surface",
    "surfaceText":              "on_surface",
    "surfaceVariant":           "surface_variant",
    "surfaceVariantText":       "on_surface_variant",
    "outline":                  "outline",
    "outlineVariant":           "outline_variant",
    "shadow":                   "shadow",
    "scrim":                    "scrim",
    "inverseSurface":           "inverse_surface",
    "inverseSurfaceText":       "inverse_on_surface",
    "inversePrimary":           "inverse_primary",
    "surfaceDim":               "surface_dim",
    "surfaceBright":            "surface_bright",
    "surfaceContainerLowest":   "surface_container_lowest",
    "surfaceContainerLow":      "surface_container_low",
    "surfaceContainer":         "surface_container",
    "surfaceContainerHigh":     "surface_container_high",
    "surfaceContainerHighest":  "surface_container_highest",
}


# ── Color utilities ────────────────────────────────────────────────────────────

def _hex_to_rgb(hex_color: str) -> tuple:
    h = hex_color.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def _rgb_to_hex(r: int, g: int, b: int) -> str:
    return f"#{r:02x}{g:02x}{b:02x}"


def _lighten(hex_color: str, amount: float) -> str:
    """Adjust lightness of a hex color by `amount` percentage points."""
    r, g, b = _hex_to_rgb(hex_color)
    h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
    l = max(0.0, min(1.0, l + amount / 100))
    r2, g2, b2 = colorsys.hls_to_rgb(h, l, s)
    return _rgb_to_hex(round(r2 * 255), round(g2 * 255), round(b2 * 255))


def _set_alpha(hex_color: str, alpha: str) -> str:
    r, g, b = _hex_to_rgb(hex_color)
    return f"rgba({r}, {g}, {b}, {alpha})"


# ── Matugen-name dict ──────────────────────────────────────────────────────────

def _build_matugen_dict(our_colors: dict) -> dict:
    """Build sorted dict of matugen snake_case names → hex values."""
    result = {}
    for our_key, matugen_name in _KEY_TO_MATUGEN.items():
        if our_key in our_colors:
            result[matugen_name] = our_colors[our_key]
    # Material You 2 compat aliases
    if "surface" in our_colors:
        result["background"] = our_colors["surface"]
    if "surfaceText" in our_colors:
        result["on_background"] = our_colors["surfaceText"]
    if all(k in our_colors for k in _DERIVED_NEEDS):
        result.update(_derived_colors(our_colors))
    return dict(sorted(result.items()))


_DERIVED_NEEDS = ("surface", "surfaceContainerLowest", "surfaceContainer", "surfaceContainerHigh",
                  "surfaceVariant", "surfaceText", "primary")
_DERIVED_PREFIXES = ("term_", "success", "on_success", "warning", "on_warning", "qt_", "pywal_")

_ANSI_REFS = {"red": "#e5484d", "green": "#46a758", "yellow": "#e5b600",
              "blue": "#3e7bf0", "magenta": "#c254d6", "cyan": "#12a5b8"}


def _hct_of(hex_color: str) -> Hct:
    return Hct.from_int(0xFF000000 | int(hex_color.lstrip("#"), 16))


def _rel_lum(hex_color: str) -> float:
    def ch(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = _hex_to_rgb(hex_color)
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def _contrast(a: str, b: str) -> float:
    la, lb = _rel_lum(a), _rel_lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)


def _toward(hue: float, target: float, cap: float) -> float:
    d = ((target - hue + 180) % 360) - 180
    return (hue + max(-cap, min(cap, d * 0.5))) % 360


def _legible(hue: float, chroma: float, tone: float, bg: str, dark: bool) -> str:
    step = 1 if dark else -1
    for _ in range(100):
        hex_color = _hex(Hct.from_hct(hue, chroma, tone))
        if _contrast(hex_color, bg) >= 4.5 or not 0 <= tone <= 100:
            return hex_color
        tone += step
    return hex_color


def _is_dark(c: dict) -> bool:
    return _hct_of(c["surface"]).tone < 50


def _mix(a: str, b: str, t: float) -> str:
    ra, ga, ba = _hex_to_rgb(a)
    rb, gb, bb = _hex_to_rgb(b)
    return _rgb_to_hex(round(ra * t + rb * (1 - t)), round(ga * t + gb * (1 - t)), round(ba * t + bb * (1 - t)))


def _derived_colors(c: dict) -> dict:
    out = _terminal_colors(c)
    dark = _is_dark(c)
    for role, slot in (("success", "term_green"), ("warning", "term_yellow")):
        src = _hct_of(out[slot])
        tones = (80, 20, 30, 90) if dark else (40, 100, 90, 10)
        names = (role, f"on_{role}", f"{role}_container", f"on_{role}_container")
        for name, tone in zip(names, tones):
            out[name] = _hex(Hct.from_hct(src.hue, max(src.chroma, 40), tone))
    grey = _hct_of(c["surfaceContainerHigh"])
    bevel = (30, 24, 10, 4) if dark else (100, 96, 80, 60)
    for name, tone in zip(("qt_light", "qt_midlight", "qt_mid", "qt_dark"), bevel):
        out[name] = _hex(Hct.from_hct(grey.hue, grey.chroma, tone))
    out["qt_disabled"] = _mix(c["surfaceText"], c["surfaceContainer"], 0.38)
    out["pywal_color0"] = c["surface"] if dark else c["surfaceText"]
    out["pywal_color7"] = out["term_white"] if dark else c["surfaceContainerHigh"]
    return out


def _terminal_colors(c: dict) -> dict:
    dark = _is_dark(c)
    bg = c["surfaceContainerLowest"] if dark else c["surface"]
    seed = _hct_of(c["primary"]).hue
    out = {"term_background": bg}
    for name, ref in _ANSI_REFS.items():
        hue = _toward(_hct_of(ref).hue, seed, 8 if name == "red" else 15)
        chroma = 60 if name == "yellow" else 50
        lift = 8 if name == "yellow" and dark else 0
        tone, bright_tone = (70, 82) if dark else (44, 34)
        out[f"term_{name}"] = _legible(hue, chroma, tone + lift, bg, dark)
        out[f"term_bright_{name}"] = _legible(hue, chroma + 8, min(bright_tone + lift, 92), bg, dark)
    grey = _hct_of(c["surfaceVariant"])
    tones = (22, 56, 82, 95) if dark else (18, 48, 64, 78)
    for name, tone in zip(("black", "bright_black", "white", "bright_white"), tones):
        out[f"term_{name}"] = _hex(Hct.from_hct(grey.hue, min(grey.chroma, 10), tone))
    return out


# ── Template engine ────────────────────────────────────────────────────────────

def _render_template(template: str, matugen: dict, wallpaper: str) -> str:
    """Render a matugen-style template string with Material You colors."""
    result = template

    # <* for name, value in colors *>...<* endfor *>
    loop_re = re.compile(
        r"<\*\s*for\s+name,\s*value\s+in\s+colors\s*\*>(.*?)<\*\s*endfor\s*\*>",
        re.DOTALL,
    )
    def _expand_loop(m: re.Match) -> str:
        inner = m.group(1)
        lines = []
        for name, hex_val in matugen.items():
            if name.startswith(_DERIVED_PREFIXES):
                continue
            stripped = hex_val.lstrip("#")
            r, g, b = _hex_to_rgb(hex_val)
            line = inner
            line = line.replace("{{name}}", name)
            line = line.replace("{{value.default.hex}}", hex_val)
            line = line.replace("{{value.default.hex_stripped}}", stripped)
            line = line.replace("{{value.default.rgba}}", f"rgba({r}, {g}, {b}, 1.0)")
            lines.append(line)
        return "".join(lines)
    result = loop_re.sub(_expand_loop, result)

    # {{image}}
    result = result.replace("{{image}}", wallpaper)

    # Templates may use {{ spaces }} or {{nospaces}} — \s* handles both forms.

    # {{ colors.X.Y.rgba | set_alpha: N }}
    def _repl_alpha(m: re.Match) -> str:
        hex_val = matugen.get(m.group(1), "#000000")
        return _set_alpha(hex_val, m.group(2))
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.[a-z]+\s*\|\s*set_alpha:\s*([\d.]+)\s*\}\}",
        _repl_alpha, result,
    )

    # {{ colors.X.Y.hex | lighten: N }}
    def _repl_lighten(m: re.Match) -> str:
        hex_val = matugen.get(m.group(1), "#000000")
        return _lighten(hex_val, float(m.group(2)))
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.hex\s*\|\s*lighten:\s*([-\d.]+)\s*\}\}",
        _repl_lighten, result,
    )

    # {{ base16.base08.Y.hex | lighten: N }}  → use error color
    def _repl_base16_lighten(m: re.Match) -> str:
        hex_val = matugen.get("error", "#ff0000")
        return _lighten(hex_val, float(m.group(1)))
    result = re.sub(
        r"\{\{\s*base16\.base08\.[a-z]+\.hex\s*\|\s*lighten:\s*([-\d.]+)\s*\}\}",
        _repl_base16_lighten, result,
    )

    # {{ colors.X.Y.hex_stripped }}
    def _repl_stripped(m: re.Match) -> str:
        return matugen.get(m.group(1), "#000000").lstrip("#")
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.hex_stripped\s*\}\}",
        _repl_stripped, result,
    )

    # {{ colors.X.Y.hex }}
    def _repl_hex(m: re.Match) -> str:
        return matugen.get(m.group(1), "#000000")
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.hex\s*\}\}",
        _repl_hex, result,
    )

    def _repl_hsl(m: re.Match) -> str:
        r, g, b = _hex_to_rgb(matugen.get(m.group(1), "#000000"))
        h, l, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        return {"hue": f"{h * 360:.1f}", "saturation": f"{sat * 100:.1f}", "lightness": f"{l * 100:.1f}"}[m.group(2)]
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.(hue|saturation|lightness)\s*\}\}",
        _repl_hsl, result,
    )

    # {{ colors.X.Y.rgba }}  (standalone, without filter)
    def _repl_rgba(m: re.Match) -> str:
        hex_val = matugen.get(m.group(1), "#000000")
        r, g, b = _hex_to_rgb(hex_val)
        return f"rgba({r}, {g}, {b}, 1.0)"
    result = re.sub(
        r"\{\{\s*colors\.([a-z0-9_]+)\.[a-z]+\.rgba\s*\}\}",
        _repl_rgba, result,
    )

    return result


# ── Apply all app templates ────────────────────────────────────────────────────

def _report(app_id: str, status: str, message: str = "", backups: int = 0) -> None:
    print("[theme-app] " + json.dumps({"id": app_id, "status": status,
                                       "message": message, "backups": backups}), flush=True)


def _apply_app_templates(our_colors: dict, wallpaper: str, enabled=None) -> None:
    matugen = _build_matugen_dict(our_colors)
    t0 = time.time()
    manifest = theme_apps.load_manifest()
    explicit = enabled is not None
    mode = "dark" if "surface" not in our_colors or _is_dark(our_colors) else "light"
    hook_env = {**os.environ, "NEBULA_MODE": mode}

    for app in theme_apps.APPS:
        name = app["id"]
        if app.get("papirus"):
            continue
        if explicit and name not in enabled:
            continue
        if explicit and not theme_apps.is_installed(app):
            _report(name, "missing", "Not installed")
            continue

        written, backups, errors = 0, 0, []
        for input_path, output_path in theme_apps.targets(app):
            if not input_path.exists():
                print(f"[gen_colors] skip {name}: template not found ({input_path})", flush=True)
                errors.append(f"Template {input_path.name} is missing")
                continue
            if not output_path.parent.exists() and not explicit:
                print(f"[gen_colors] skip {name}: output dir missing ({output_path.parent})", flush=True)
                continue
            try:
                rendered = _render_template(input_path.read_text(), matugen, wallpaper)
                if theme_apps.backup_if_user_file(app, output_path, manifest):
                    backups += 1
                    print(f"[gen_colors] backup {name}: {output_path}.bak", flush=True)
                _atomic_write(output_path, rendered)
                theme_apps.record(output_path, rendered, manifest)
                written += 1
                print(f"[gen_colors] wrote {name} → {output_path}", flush=True)
            except Exception as e:
                print(f"[gen_colors] ERROR {name}: {e}", file=sys.stderr)
                errors.append(str(e))

        hook = app.get("hook")
        if hook and written:
            try:
                subprocess.Popen(hook, shell=True, env=hook_env,
                                 stdout=subprocess.DEVNULL,
                                 stderr=subprocess.DEVNULL)
                print(f"[gen_colors] hook {name}: {hook}", flush=True)
            except Exception as e:
                print(f"[gen_colors] hook ERROR {name}: {e}", file=sys.stderr)
                errors.append(f"Reload failed: {e}")

        if explicit:
            if errors:
                _report(name, "error", errors[0], backups)
            elif written:
                _report(name, "ok", f"{written} file{'s' if written != 1 else ''} written", backups)
            else:
                _report(name, "skipped", "Nothing to write")

    theme_apps.save_manifest(manifest)
    print(f"[gen_colors] app templates done in {(time.time()-t0)*1000:.0f}ms", flush=True)


# ── Fluent icon theme sync ────────────────────────────────────────────────────
# Local change: this was Papirus. The folder-recolouring helper
# (papirus-folders) had no papirus icon theme on this machine, and the gsettings
# call below kept overwriting the icon theme. It now only pins the Fluent theme
# that is actually installed, and skips the papirus-folders recolour entirely.
# Back up before pulling: this is a tracked file.

# Search roots for icon themes; each candidate is looked up as <root>/<name>.
_ICON_THEME_ROOTS = [
    Path("/usr/share/icons"),
    Path("/usr/local/share/icons"),
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
]


def _fluent_theme_for(mode: str) -> str:
    """Return the installed Fluent variant matching the current colour mode."""
    candidates = ["Fluent-dark", "Fluent"] if mode == "dark" else ["Fluent-light", "Fluent"]
    for name in candidates:
        if any((root / name).is_dir() for root in _ICON_THEME_ROOTS):
            return name
    return ""


def _determine_papirus_hue(r: int, g: int, b: int, brightness: int, use_pale: bool) -> str:
    if b > r and b > g:
        r_ratio = (r * 100) // b if b > 0 else 0
        g_ratio = (g * 100) // b if b > 0 else 0
        rg_diff = abs(r - g)
        if r_ratio > 70 and g_ratio > 70:
            if rg_diff < 15:
                return "blue"
            elif r > g:
                return "violet"
            else:
                return "cyan"
        elif r_ratio > 60 and r > g:
            return "violet"
        elif g_ratio > 60 and g > r:
            return "cyan"
        else:
            return "blue"
    elif r > g and r > b:
        if g > b + 30:
            rg_ratio = (g * 100) // r if r > 0 else 0
            if use_pale:
                return "palebrown" if rg_ratio > 70 and brightness < 220 else "paleorange"
            else:
                return "brown" if rg_ratio > 70 and brightness < 180 else "orange"
        elif b > g + 20:
            return "pink"
        else:
            return "pink" if use_pale else "red"
    elif g > r and g > b:
        return "yellow" if r > b + 30 else "green"
    else:
        return "grey"


def _map_to_papirus_color(hex_color: str) -> str:
    """Map a hex color (with or without #) to the nearest Papirus folder color name."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

    max_val = max(r, g, b)
    min_val = min(r, g, b)
    brightness = max_val
    saturation = 0 if max_val == 0 else ((max_val - min_val) * 100) // max_val

    if saturation < 20:
        if brightness < 85:
            return "black"
        elif brightness < 170:
            return "grey"
        else:
            return "white"
    elif saturation < 60 and brightness > 180:
        return _determine_papirus_hue(r, g, b, brightness, use_pale=True)
    else:
        return _determine_papirus_hue(r, g, b, brightness, use_pale=False)


def _sync_papirus_colors(primary_hex: str, mode: str, keep_icon_theme: bool = False, enabled=None) -> None:
    """Pin the GTK icon theme to the installed Fluent variant.

    Local change: was "recolor Papirus folder icons and switch GTK icon theme to
    Papirus". papirus-folders has nothing to recolour without a papirus icon
    theme installed, and the gsettings call overwrote the user's icon theme on
    every colour-scheme regeneration. The papirus-folders invocation is dropped;
    the icon theme is only set when it differs from what is already active, so
    this is a no-op on most runs. The function name is kept so the four existing
    call sites keep working.
    """
    if keep_icon_theme:
        # A gowall icon theme is active. Leave it alone.
        print("[gen_colors] gowall icons active — leaving the icon theme alone", flush=True)
        return

    icon_theme = _fluent_theme_for(mode)
    if not icon_theme:
        print("[gen_colors] no Fluent theme found — leaving the icon theme alone", flush=True)
        return

    current = ""
    try:
        current = subprocess.run(
            ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"],
            capture_output=True, text=True, timeout=10,
        ).stdout.strip().strip("'")
    except Exception:
        pass

    if current == icon_theme:
        print(f"[gen_colors] icon theme already {icon_theme}", flush=True)
        return

    if enabled is not None:
        _report("papirus", "ok", f"Icon theme {current or 'unset'} → {icon_theme}")
    print(f"[gen_colors] icon theme {current or 'unset'} → {icon_theme}", flush=True)

    try:
        subprocess.Popen(
            ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", icon_theme],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except Exception as e:
        print(f"[gen_colors] icon-theme ERROR: {e}", file=sys.stderr)


# ── Font sync ──────────────────────────────────────────────────────────────────

# Body font → monospace equivalent (for terminal)
_FONT_TO_MONO = {
    "Adwaita Sans":    "Adwaita Mono",
    "Cantarell":       "Source Code Pro",
    "DejaVu Sans":     "DejaVu Sans Mono",
    "Fira Sans":       "FiraCode Nerd Font",
    "Liberation Sans": "Liberation Mono",
    "Noto Sans":       "Noto Sans Mono",
    "Readex Pro":      "Source Code Pro",
    "Rubik":           "Source Code Pro",
}

# Font size multiplier per fontScale setting
_FONT_SCALE_PT = {
    "small":      10,
    "normal":     12,
    "large":      13,
    "extralarge": 15,
}

# Nerd font PUA ranges → FiraCode NF for nerd font icons in kitty
_NF_SYMBOL_MAP = (
    "U+23FB-U+23FE,U+2665,U+26A1,U+2B58,"
    "U+E000-U+E00A,U+E0A0-U+E0C8,U+E0CA,U+E0CC-U+E0D4,"
    "U+E200-U+E2A9,U+E300-U+E3E3,U+E5FA-U+E6B1,"
    "U+E700-U+E7C5,U+EA60-U+EBEB,"
    "U+F000-U+F2E0,U+F300-U+F372,U+F400-U+F532,"
    "U+F0001-U+F1AF0"
)
_NF_SYMBOL_FONT = "FiraCode Nerd Font"

_QS_SETTINGS = _HOME / ".cache" / "quickshell" / "settings.json"
_KITTY_CUSTOM = _HOME / ".config" / "kitty" / "custom.conf"


def _apply_fonts(enabled=None) -> None:
    try:
        settings = json.loads(_QS_SETTINGS.read_text())
    except Exception as e:
        print(f"[gen_colors] font sync: cannot read settings.json: {e}", file=sys.stderr)
        return

    general    = settings.get("general", {})
    body_font  = general.get("defaultFont", "Adwaita Sans")
    font_scale = general.get("fontScale", "normal")
    font_size  = _FONT_SCALE_PT.get(font_scale, 11)
    mono_font  = _FONT_TO_MONO.get(body_font, "Source Code Pro")

    # Write kitty custom.conf (overrides font_family from kitty.conf)
    kitty_conf = (
        f"# Auto-generated by gen_colors.py\n"
        f"font_family      {mono_font}\n"
        f"bold_font        auto\n"
        f"italic_font      auto\n"
        f"bold_italic_font auto\n"
        f"font_size        {font_size}.0\n"
        f"\n"
        f"# Nerd font icons via FiraCode NF (powerline + MDI + devicons)\n"
        f"symbol_map {_NF_SYMBOL_MAP} {_NF_SYMBOL_FONT}\n"
    )
    if (enabled is None or "kitty" in enabled) and _KITTY_CUSTOM.parent.is_dir():
        try:
            manifest = theme_apps.load_manifest()
            theme_apps.backup_if_user_file({"id": "kitty", "whole": True}, _KITTY_CUSTOM, manifest)
            _atomic_write(_KITTY_CUSTOM, kitty_conf)
            theme_apps.record(_KITTY_CUSTOM, kitty_conf, manifest)
            theme_apps.save_manifest(manifest)
            print(f"[gen_colors] font sync: kitty → {mono_font} {font_size}pt", flush=True)
        except Exception as e:
            print(f"[gen_colors] font sync ERROR kitty: {e}", file=sys.stderr)

    # Apply system font via gsettings
    gs_cmds = [
        f'gsettings set org.gnome.desktop.interface font-name "{body_font} {font_size}"',
        f'gsettings set org.gnome.desktop.interface monospace-font-name "{mono_font} {font_size}"',
        f'gsettings set org.gnome.desktop.interface document-font-name "{body_font} {font_size}"',
    ]
    for cmd in gs_cmds:
        try:
            subprocess.Popen(cmd, shell=True,
                             stdout=subprocess.DEVNULL,
                             stderr=subprocess.DEVNULL)
        except Exception as e:
            print(f"[gen_colors] font sync gsettings ERROR: {e}", file=sys.stderr)
    print(f"[gen_colors] font sync: gsettings → {body_font} {font_size}pt", flush=True)


# ── Core color generation ──────────────────────────────────────────────────────

def _image_hash(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()[:24]


_QUANTIZE_AREA = 384 * 384


def _quantize(image_path: str) -> dict:
    try:
        from PIL import Image
        with Image.open(image_path) as im:
            w, h = im.size
            s = min(1.0, (_QUANTIZE_AREA / (w * h)) ** 0.5)
            nw, nh = max(1, round(w * s)), max(1, round(h * s))
            im.draft("RGB", (nw * 2, nh * 2))
            small = im.convert("RGB").resize((nw, nh), Image.Resampling.BOX)
            pixels = getattr(small, "get_flattened_data", small.getdata)()
            return QuantizeCelebi(list(pixels), 128)
    except Exception as e:
        print(f"[gen_colors] downsample failed ({e}) — quantizing full image", file=sys.stderr)
        return ImageQuantizeCelebi(image_path, 1, 128)


def _quantize_and_score(image_path: str) -> Hct:
    quantized = _quantize(image_path)

    colors_hct = []
    hue_population = [0] * 360
    population_sum = 0
    for rgb, population in quantized.items():
        hct = Hct.from_int(rgb)
        colors_hct.append(hct)
        hue_population[int(hct.hue)] += population
        population_sum += population

    hue_excited = [0.0] * 360
    for hue in range(360):
        prop = hue_population[hue] / population_sum
        for i in range(hue - 14, hue + 16):
            hue_excited[int(sanitize_degrees_int(i))] += prop

    scored = []
    for hct in colors_hct:
        hue  = int(sanitize_degrees_int(round(hct.hue)))
        prop = hue_excited[hue]
        cw   = 0.1 if hct.chroma < 48.0 else 0.3
        scored.append((prop * 100.0 * 0.7 + (hct.chroma - 48.0) * cw, hct))
    scored.sort(reverse=True)

    for cutoff in range(20, -1, -1):
        for _, hct in scored:
            if hct.chroma > cutoff and hct.tone > cutoff * 3:
                return DislikeAnalyzer.fix_if_disliked(hct)
    return DislikeAnalyzer.fix_if_disliked(scored[0][1])


_FALLBACK_SEED = 0xFF4285F4
_MAX_SEEDS = 4


def _cache_base(img_hash: str) -> Path:
    return CACHE_DIR / "color_cache" / img_hash


def _chosen_seed(img_hash: str) -> int:
    try:
        return max(0, int((_cache_base(img_hash) / "seed.txt").read_text().strip()))
    except Exception:
        return 0


def _auto_primary(image_path: str, img_hash: str) -> Hct:
    score_cache = _cache_base(img_hash) / "score.txt"
    try:
        return Hct.from_int(int(score_cache.read_text()))
    except Exception:
        pass
    primary = _quantize_and_score(image_path)
    score_cache.parent.mkdir(parents=True, exist_ok=True)
    score_cache.write_text(str(primary.to_int()))
    return primary


def _seeds(image_path: str, img_hash: str) -> list:
    seeds_cache = _cache_base(img_hash) / "seeds.json"
    try:
        return [int(x) for x in json.loads(seeds_cache.read_text())]
    except Exception:
        pass
    out = [_auto_primary(image_path, img_hash).to_int()]
    for argb in Score.score(_quantize(image_path), ScoreOptions(desired=8)):
        if argb == _FALLBACK_SEED:
            continue
        h = DislikeAnalyzer.fix_if_disliked(Hct.from_int(argb))
        if h.chroma < 24 or not 30 <= h.tone <= 80:
            continue
        if all(_hue_gap(h.hue, Hct.from_int(o).hue) >= 20 for o in out):
            out.append(h.to_int())
        if len(out) == _MAX_SEEDS:
            break
    seeds_cache.parent.mkdir(parents=True, exist_ok=True)
    seeds_cache.write_text(json.dumps(out))
    return out


def seed_primary(image_path: str, img_hash: str, idx: int):
    if idx <= 0:
        return None
    seeds = _seeds(image_path, img_hash)
    return Hct.from_int(seeds[idx]) if idx < len(seeds) else None


def seeds_report(image_path: str, variant: str, mode: str) -> dict:
    variant = variant.removeprefix("scheme-")
    img_hash = _image_hash(image_path)
    seeds = _seeds(image_path, img_hash)
    chosen = _chosen_seed(img_hash)
    is_dark = mode.lower() != "light"
    rows = []
    for argb in seeds:
        sc = _build_scheme(Hct.from_int(argb), variant, is_dark)
        rows.append({"seed": "#%06x" % (argb & 0xFFFFFF), "primary": sc["primary"],
                     "secondaryContainer": sc["secondaryContainer"], "tertiary": sc["tertiary"]})
    return {"chosen": chosen if chosen < len(seeds) else 0, "seeds": rows}


def set_seed(image_path: str, idx: int) -> None:
    f = _cache_base(_image_hash(image_path)) / "seed.txt"
    if idx <= 0:
        f.unlink(missing_ok=True)
        return
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(str(idx))


def _build_scheme(primary: Hct, variant: str, is_dark: bool) -> dict:
    SchemeClass = _SCHEMES.get(variant, SchemeVibrant)
    scheme = SchemeClass(source_color_hct=primary, is_dark=is_dark, contrast_level=0.0)

    dyn = MaterialDynamicColors()
    if hasattr(dyn, "all_colors"):
        raw = {c.name: c.get_hct(scheme).to_int() for c in dyn.all_colors}
    else:
        raw = {}
        for attr in vars(MaterialDynamicColors):
            obj = getattr(MaterialDynamicColors, attr)
            if hasattr(obj, "get_hct"):
                raw[attr] = obj.get_hct(scheme).to_int()

    output = {}
    for src, dst in _COLOR_MAP.items():
        if src in raw:
            argb = raw[src] if isinstance(raw[src], int) else raw[src].to_int()
            output[dst] = f"#{argb & 0xFFFFFF:06x}"
    return output


# ── Fixed palette → Material roles ────────────────────────────────────────────
#
# A gowall theme is a flat list of colors with no notion of roles, so the palette
# is read as two ramps: neutrals carry every surface, accents carry primary /
# secondary / tertiary / error. Roles that the palette cannot fill are synthesized
# at the tone M3 asks for, in the hue of the nearest palette color — so contrast
# holds even for a palette with only three greys, and nothing is hand-mapped
# per theme.

def _neutral_cutoff(chromas: list) -> float:
    """Where a palette stops being grey. No fixed threshold works across themes —
    catppuccin's greys reach chroma 20 while gruvbox's accents start at 30 — but
    every palette has a visible gap between the two families, so split at the
    widest gap in the plausible band."""
    ordered = sorted(chromas)
    best, cutoff = 0.0, 20.0
    for low, high in zip(ordered, ordered[1:]):
        if 5.0 <= low <= 30.0 and (high - low) > best:
            best, cutoff = high - low, (low + high) / 2
    return cutoff

# role → (dark tone, light tone), M3's own values
_SURFACE_TONES = {
    "surfaceContainerLowest":  (4, 100),
    "surface":                 (6, 98),
    "surfaceDim":              (6, 87),
    "surfaceContainerLow":     (10, 96),
    "surfaceContainer":        (12, 94),
    "surfaceContainerHigh":    (17, 92),
    "surfaceContainerHighest": (22, 90),
    "surfaceBright":           (24, 98),
    "surfaceVariant":          (30, 90),
    "outlineVariant":          (30, 80),
    "outline":                 (60, 50),
    "surfaceVariantText":      (80, 30),
    "surfaceText":             (90, 10),
    "inverseSurface":          (90, 20),
    "inverseSurfaceText":      (20, 95),
}

# accent family → (role suffix, dark tone, light tone)
_ACCENT_TONES = [
    ("",               80, 40),
    ("Text",           20, 100),
    ("Container",      30, 90),
    ("ContainerText",  90, 10),
    ("Fixed",          90, 90),
    ("FixedDim",       80, 80),
]
_ON_FIXED_TONES = [("onFIXED", 10, 10), ("onFIXEDVariant", 30, 30)]


def _hex(hct: Hct) -> str:
    return f"#{hct.to_int() & 0xFFFFFF:06x}"


def _at_tone(source: Hct, tone: float) -> Hct:
    return Hct.from_hct(source.hue, source.chroma, tone)


def _nearest_tone(pool: list, tone: float) -> Hct:
    return min(pool, key=lambda h: abs(h.tone - tone))


def _hue_gap(a: float, b: float) -> float:
    d = abs(a - b) % 360
    return min(d, 360 - d)


def _pick_accent(accents: list, neutrals: list, prefer_tone: float) -> Hct:
    """A theme's signature color is the hue it spends the most colors on — nord's
    four frost blues, gruvbox's yellow-greens — not simply its most saturated one.
    Ties break toward the hue the palette also tinted its greys with, which is how
    a theme signs its neutrals. Then take the member already closest to the tone
    the role needs, so it lands in the UI as itself."""
    def cluster(seed):
        return [h for h in accents if _hue_gap(h.hue, seed.hue) <= 40.0]

    tint = neutrals[len(neutrals) // 2].hue if neutrals else 0.0
    biggest = max(accents, key=lambda h: (len(cluster(h)), -_hue_gap(h.hue, tint)))
    return min(cluster(biggest), key=lambda h: abs(h.tone - prefer_tone))


def _build_palette_scheme(palette: list, is_dark: bool) -> dict:
    hcts = [Hct.from_int(0xFF000000 | int(h.lstrip("#"), 16)) for h in palette]
    cutoff = _neutral_cutoff([h.chroma for h in hcts])
    neutrals = sorted([h for h in hcts if h.chroma < cutoff], key=lambda h: h.tone)
    accents  = sorted([h for h in hcts if h.chroma >= cutoff], key=lambda h: -h.chroma)
    if not neutrals:
        neutrals = sorted(hcts, key=lambda h: h.tone)
    if not accents:
        accents = sorted(hcts, key=lambda h: -h.chroma)[:3]

    out = {"shadow": "#000000", "scrim": "#000000"}

    # Surfaces. The container ladder is rank-mapped onto the palette's own dark
    # neutrals rather than nearest-tone matched: nord's four greys all sit near
    # tone 21-38, so nearest-tone would collapse every card onto one flat color.
    dark_side  = [h for h in neutrals if h.tone < 50] or neutrals[:1]
    light_side = [h for h in neutrals if h.tone >= 50] or neutrals[-1:]
    ground = dark_side if is_dark else list(reversed(light_side))

    ladder = ["surfaceContainerLowest", "surface", "surfaceContainerLow",
              "surfaceContainer", "surfaceContainerHigh", "surfaceContainerHighest"]
    last = len(ground) - 1
    for i, role in enumerate(ladder):
        # Lowest and surface share the ground; the rest climb the ramp.
        idx = 0 if i < 2 else round((i - 1) * last / (len(ladder) - 2))
        out[role] = _hex(ground[min(idx, last)])
    if len({out[r] for r in ladder}) == 1:
        # A palette with a single usable ground tone still needs steps.
        base = ground[0]
        for role in ladder:
            out[role] = _hex(_at_tone(base, _SURFACE_TONES[role][0 if is_dark else 1]))

    out["surfaceDim"] = out["surface"]
    out["surfaceBright"] = _hex(ground[last] if is_dark else ground[0])

    for role in ("surfaceVariant", "outlineVariant", "outline", "surfaceVariantText",
                 "surfaceText", "inverseSurface", "inverseSurfaceText"):
        tone = _SURFACE_TONES[role][0 if is_dark else 1]
        pool = dark_side if tone < 50 else light_side
        # Text and outlines want the *greyest* candidate near the tone, not merely
        # the nearest: a pale yellow can sit at tone 90 and would make body text
        # yellow if tone alone decided it.
        pick = min(pool, key=lambda h: abs(h.tone - tone) + h.chroma * 0.6)
        out[role] = _hex(pick if abs(pick.tone - tone) <= 14 else _at_tone(pick, tone))

    primary = _pick_accent(accents, neutrals, prefer_tone=80 if is_dark else 40)
    error   = min(accents, key=lambda h: _hue_gap(h.hue, 25.0) - h.chroma / 10.0)
    rest    = [h for h in accents if h is not primary and h is not error] or accents
    secondary = max(rest, key=lambda h: _hue_gap(h.hue, primary.hue))
    rest2 = [h for h in rest if h is not secondary] or rest
    tertiary = max(rest2, key=lambda h: _hue_gap(h.hue, primary.hue) + _hue_gap(h.hue, secondary.hue))

    for family, source in (("primary", primary), ("secondary", secondary),
                           ("tertiary", tertiary), ("error", error)):
        for suffix, dark_tone, light_tone in _ACCENT_TONES:
            tone = dark_tone if is_dark else light_tone
            if family == "error" and suffix in ("Fixed", "FixedDim"):
                continue
            key = family + suffix
            base = source if abs(source.tone - tone) <= 10 else _at_tone(source, tone)
            out[key] = _hex(base)
        if family != "error":
            out[f"on{family.capitalize()}Fixed"] = _hex(_at_tone(source, 10))
            out[f"on{family.capitalize()}FixedVariant"] = _hex(_at_tone(source, 30))

    out["inversePrimary"] = _hex(_at_tone(primary, 40 if is_dark else 80))
    return out


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _write_colors_json(content: str) -> None:
    """Writes colors.json to OUTPUT_PATH plus every plain-copy target in
    _EXTRA_COPY_PATHS (e.g. the file manager's own config dir)."""
    _atomic_write(OUTPUT_PATH, content)
    for path in _EXTRA_COPY_PATHS:
        try:
            _atomic_write(path, content)
            print(f"[gen_colors] copied colors.json → {path}", flush=True)
        except Exception as e:
            print(f"[gen_colors] ERROR copying colors.json to {path}: {e}", file=sys.stderr)


# ── Entry point ────────────────────────────────────────────────────────────────

def _flag(name: str, default: str) -> str:
    if name in sys.argv[4:]:
        idx = sys.argv.index(name)
        if idx + 1 < len(sys.argv):
            value = sys.argv[idx + 1]
            if os.path.isfile(value):
                return value
            print(f"[gen_colors] WARNING: {name} not a file: {value}", file=sys.stderr)
    return default


def _apps_arg():
    if "--apps" not in sys.argv:
        return None
    idx = sys.argv.index("--apps")
    return theme_apps.parse_ids(sys.argv[idx + 1] if idx + 1 < len(sys.argv) else "")


def _apps_only() -> None:
    try:
        our_colors = json.loads(OUTPUT_PATH.read_text())
    except Exception as e:
        print(f"[gen_colors] ERROR: cannot read {OUTPUT_PATH}: {e}", file=sys.stderr)
        sys.exit(1)
    enabled = _apps_arg()
    if enabled is None:
        enabled = theme_apps.enabled_ids()
    mode = sys.argv[sys.argv.index("--mode") + 1] if "--mode" in sys.argv[:-1] else "dark"
    _apply_app_templates(our_colors, our_colors.get("wallpaper", ""), enabled)
    _sync_papirus_colors(our_colors.get("primary", ""), mode, "--keep-icon-theme" in sys.argv, enabled)
    print("[theme-app] done", flush=True)


def main() -> None:
    if "--apps-only" in sys.argv:
        _apps_only()
        return

    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <image> <variant> <mode>", file=sys.stderr)
        sys.exit(1)

    image_path = sys.argv[1]
    variant    = sys.argv[2].removeprefix("scheme-")
    mode       = sys.argv[3].lower()
    is_dark    = mode != "light"

    if not os.path.isfile(image_path):
        print(f"[gen_colors] ERROR: image not found: {image_path}", file=sys.stderr)
        sys.exit(1)

    source_path  = _flag("--source", image_path)
    display_path = _flag("--display", image_path)
    keep_icons   = "--keep-icon-theme" in sys.argv
    enabled      = _apps_arg()
    if enabled is None:
        enabled = theme_apps.enabled_ids()

    palette = None
    palette_file = _flag("--palette-file", "")
    if palette_file:
        try:
            palette = [c for c in json.loads(Path(palette_file).read_text()) if isinstance(c, str)]
        except Exception as e:
            print(f"[gen_colors] ERROR reading palette {palette_file}: {e}", file=sys.stderr)
            palette = None
        if palette and len(palette) < 4:
            print(f"[gen_colors] palette too small ({len(palette)}) — falling back to the wallpaper",
                  file=sys.stderr)
            palette = None

    t_start = time.time()
    if palette:
        # The scheme depends only on the palette, so the wallpaper is not part of
        # the cache identity here.
        img_hash = "palette-" + hashlib.sha256(",".join(palette).encode()).hexdigest()[:16]
        variant = "palette"
    else:
        img_hash = _image_hash(image_path)
    seed_idx    = 0 if palette else _chosen_seed(img_hash)
    cache_base  = CACHE_DIR / "color_cache" / img_hash
    score_cache = cache_base / "score.txt"
    color_cache = cache_base / (f"{variant}_{mode}_s{seed_idx}.json" if seed_idx else f"{variant}_{mode}.json")

    # ── Fast path: full colors cached ─────────────────────────────────────
    if color_cache.exists():
        cached = color_cache.read_text()
        our_colors = json.loads(cached)
        our_colors["wallpaper"]       = display_path
        our_colors["sourceWallpaper"] = source_path
        _write_colors_json(json.dumps(our_colors, indent=4))
        print(f"[gen_colors] cache hit ({(time.time()-t_start)*1000:.0f}ms) — {img_hash[:8]}_{variant}_{mode}")
        _apply_app_templates(our_colors, display_path, enabled)
        _apply_fonts(enabled)
        _sync_papirus_colors(our_colors.get("primary", ""), mode, keep_icons, enabled)
        return

    if palette:
        t0 = time.time()
        our_colors = _build_palette_scheme(palette, is_dark)
        print(f"[gen_colors] palette scheme ({len(palette)} colors): "
              f"{(time.time()-t0)*1000:.0f}ms", flush=True)
        our_colors["wallpaper"] = image_path
        cache_base.mkdir(parents=True, exist_ok=True)
        color_cache.write_text(json.dumps(our_colors, indent=4))

        our_colors["wallpaper"]       = display_path
        our_colors["sourceWallpaper"] = source_path
        content = json.dumps(our_colors, indent=4)
        _write_colors_json(content)
        print(f"[gen_colors] done in {(time.time()-t_start)*1000:.0f}ms — "
              f"primary: {our_colors.get('primary', '?')}")
        _apply_app_templates(our_colors, display_path, enabled)
        _apply_fonts(enabled)
        _sync_papirus_colors(our_colors.get("primary", ""), mode, keep_icons, enabled)
        return

    # ── Medium path: primary HCT cached ───────────────────────────────────
    primary = None
    if score_cache.exists():
        try:
            primary = Hct.from_int(int(score_cache.read_text()))
            print(f"[gen_colors] score cache hit — skipping quantize", flush=True)
        except Exception:
            primary = None

    # ── Slow path: quantize image ──────────────────────────────────────────
    if primary is None:
        t0 = time.time()
        primary = _quantize_and_score(image_path)
        print(f"[gen_colors] quantize+score: {(time.time()-t0)*1000:.0f}ms", flush=True)
        cache_base.mkdir(parents=True, exist_ok=True)
        score_cache.write_text(str(primary.to_int()))

    chosen = seed_primary(image_path, img_hash, seed_idx)
    if chosen is not None:
        primary = chosen
        print(f"[gen_colors] using seed {seed_idx}: #{primary.to_int() & 0xFFFFFF:06x}", flush=True)

    # ── Generate scheme ────────────────────────────────────────────────────
    t0 = time.time()
    our_colors = _build_scheme(primary, variant, is_dark)
    print(f"[gen_colors] scheme gen: {(time.time()-t0)*1000:.0f}ms", flush=True)

    our_colors["wallpaper"] = image_path
    cache_base.mkdir(parents=True, exist_ok=True)
    color_cache.write_text(json.dumps(our_colors, indent=4))

    our_colors["wallpaper"]       = display_path
    our_colors["sourceWallpaper"] = source_path
    content = json.dumps(our_colors, indent=4)
    _write_colors_json(content)

    print(f"[gen_colors] done in {(time.time()-t_start)*1000:.0f}ms — primary: {our_colors.get('primary', '?')}")

    _apply_app_templates(our_colors, display_path, enabled)
    _apply_fonts(enabled)
    _sync_papirus_colors(our_colors.get("primary", ""), mode, keep_icons, enabled)


if __name__ == "__main__":
    main()
