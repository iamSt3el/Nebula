import argparse
import json
import math
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from nebula.paths import CACHE_DIR, COLORS, SETTINGS

NAME = "nebula-orbit"
OUT = CACHE_DIR / "grub" / NAME
FONT_CACHE = CACHE_DIR / "grub" / "fonts"
TARGET = Path("/boot/grub/themes") / NAME
DEFAULTS = Path("/etc/default/grub")

RING = 380
TICK = 16
DIM = 10
TICKS = 40
SHAPE = 236
ROW = 76
ROW_GAP = 4
CAP = ROW // 2
MENU_W = 720
ICON = 52
ICON_GAP = 20
MENU_FONT = 26
HOST_FONT = 26
HINT_FONT = 21
COUNT_FONT = 120

COOKIE9 = ("M92.2 75.1C90.3 78.3 87.4 80.8 83.7 82.0C79.9 83.2 76.7 85.8 74.9 89.3C71.2 96.2 63.0 99.2 55.7 96.3"
           "C52.1 94.8 47.9 94.8 44.3 96.3C37.0 99.2 28.8 96.2 25.1 89.3C23.3 85.8 20.1 83.2 16.3 82.0C8.9 79.6 4.5 71.9 6.2 64.3"
           "C7.0 60.4 6.3 56.4 4.2 53.0C0.0 46.4 1.5 37.7 7.7 33.0C10.8 30.5 12.9 27.0 13.4 23.0C14.5 15.3 21.2 9.6 29.0 9.9"
           "C33.0 10.1 36.9 8.7 39.8 6.0C45.6 0.8 54.4 0.8 60.2 6.0C63.1 8.7 67.0 10.1 71.0 9.9C78.8 9.6 85.5 15.3 86.6 23.0"
           "C87.1 27.0 89.2 30.5 92.3 33.0C98.5 37.7 100.0 46.4 95.8 53.0C93.7 56.4 93.0 60.4 93.8 64.3C94.7 68.1 94.0 71.9 92.2 75.1Z")

ICONS = {
    "arch": 0xE86B, "linux": 0xE86B, "gnu-linux": 0xE86B,
    "submenu": 0xE429,
    "windows": 0xF088,
    "efi": 0xE322,
    "recovery": 0xE869,
    "os": 0xEB8E, "unknown": 0xEB8E,
}

PREVIEW_ROWS = [("arch", "Arch Linux"), ("submenu", "Advanced options for Arch Linux"),
                ("windows", "Windows Boot Manager"), ("efi", "UEFI Firmware Settings")]


def font_file(family: str, style: str = "") -> Path:
    pattern = f"{family}:style={style}" if style else family
    out = subprocess.run(["fc-match", "-f", "%{family}\n%{file}", pattern], capture_output=True, text=True).stdout
    found, _, path = out.partition("\n")
    if family.lower() not in found.lower() or not path:
        raise SystemExit(f"font not found: {pattern} (fc-match gave {found or 'nothing'})")
    return Path(path.strip())


def symbols_file() -> Path:
    for p in [Path("/usr/share/fonts/Material_Symbols_Rounded/static/MaterialSymbolsRounded_Filled_48pt-Medium.ttf"),
              Path.home() / ".local/share/fonts/static/MaterialSymbolsRounded_Filled_48pt-Medium.ttf"]:
        if p.exists():
            return p
    return font_file("Material Symbols Rounded")


def rubik_weight(weight: int) -> Path:
    src = font_file("Rubik")
    if "wght" not in src.name:
        return src
    FONT_CACHE.mkdir(parents=True, exist_ok=True)
    dst = FONT_CACHE / f"Rubik-{weight}.ttf"
    if dst.exists():
        return dst
    if not shutil.which("uvx"):
        print(f"uvx not found, using {src.name} at its default weight", file=sys.stderr)
        return src
    subprocess.run(["uvx", "--from", "fonttools", "fonttools", "varLib.instancer", str(src), f"wght={weight}",
                    "-o", str(dst)], check=True, capture_output=True)
    return dst


def colors() -> dict:
    return json.loads(COLORS.read_text())


def host_line() -> str:
    name = ""
    try:
        name = (json.loads(SETTINGS.read_text()).get("general", {}).get("displayName") or "").strip()
    except (OSError, ValueError):
        pass
    if not name:
        name = (Path.home().name or "user").capitalize()
    chassis = subprocess.run(["hostnamectl", "chassis"], capture_output=True, text=True).stdout.strip()
    noun = {"laptop": "laptop", "desktop": "desktop", "tablet": "tablet", "convertible": "laptop"}.get(chassis, "computer")
    return f"{name}'s {noun}"


def svg_png(svg: str, path: Path) -> None:
    subprocess.run(["rsvg-convert", "-o", str(path)], input=svg.encode(), check=True)


def tick_centres(radius: float) -> list:
    return [(RING / 2 + radius * math.cos(-math.pi / 2 + i * 2 * math.pi / TICKS),
             RING / 2 + radius * math.sin(-math.pi / 2 + i * 2 * math.pi / TICKS)) for i in range(TICKS)]


def draw_assets(c: dict, out: Path) -> None:
    radius = RING // 2 - TICK // 2 - 1
    dots = "".join(f'<circle cx="{x:.2f}" cy="{y:.2f}" r="{DIM / 2}" fill="{c["outlineVariant"]}"/>'
                   for x, y in tick_centres(radius))
    off = (RING - SHAPE) / 2
    svg_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{RING}" height="{RING}">{dots}'
            f'<g transform="translate({off} {off}) scale({SHAPE / 100})"><path d="{COOKIE9}" fill="{c["primaryContainer"]}"/></g></svg>',
            out / "orbit_center.png")
    svg_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{TICK}" height="{TICK}">'
            f'<circle cx="{TICK / 2}" cy="{TICK / 2}" r="{TICK / 2}" fill="{c["primary"]}"/></svg>', out / "orbit_tick.png")
    fill = c["primary"]
    svg_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{CAP}" height="{ROW}">'
            f'<path d="M{CAP} 0A{CAP} {CAP} 0 0 0 {CAP} {ROW}Z" fill="{fill}"/></svg>', out / "select_w.png")
    svg_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="{CAP}" height="{ROW}">'
            f'<path d="M0 0A{CAP} {CAP} 0 0 1 0 {ROW}Z" fill="{fill}"/></svg>', out / "select_e.png")
    svg_png(f'<svg xmlns="http://www.w3.org/2000/svg" width="4" height="{ROW}"><rect width="4" height="{ROW}" fill="{fill}"/></svg>',
            out / "select_c.png")

    icons = out / "icons"
    icons.mkdir(exist_ok=True)
    glyph_font = ImageFont.truetype(str(symbols_file()), 30 * 4)
    for name, cp in ICONS.items():
        big = Image.new("RGBA", (ICON * 4, ICON * 4), (0, 0, 0, 0))
        d = ImageDraw.Draw(big)
        d.ellipse((0, 0, ICON * 4 - 1, ICON * 4 - 1), fill=c["surfaceContainerHighest"])
        d.text((ICON * 2, ICON * 2), chr(cp), font=glyph_font, fill=c["primary"], anchor="mm")
        big.resize((ICON, ICON), Image.LANCZOS).save(icons / f"{name}.png")


def pf2_name(path: Path) -> str:
    data = path.read_bytes()
    i = 0
    while i + 8 <= len(data):
        tag = data[i:i + 4]
        size = int.from_bytes(data[i + 4:i + 8], "big")
        if tag == b"NAME":
            return data[i + 8:i + 8 + size].rstrip(b"\0").decode()
        i += 8 + size
    raise SystemExit(f"no NAME in {path}")


def make_font(ttf: Path, size: int, family: str, out: Path) -> str:
    dst = out / f"{family.lower().replace(' ', '_')}_{size}.pf2"
    subprocess.run(["grub-mkfont", "-s", str(size), "-n", family, "-o", str(dst), str(ttf)], check=True, capture_output=True)
    return pf2_name(dst)


def count_top(titan: Path) -> int:
    f = ImageFont.truetype(str(titan), COUNT_FONT)
    ascent, _ = f.getmetrics()
    _, y0, _, y1 = f.getbbox("3", anchor="ls")
    return round(RING / 2 - ascent - (y0 + y1) / 2)


def theme_txt(c: dict, fonts: dict, host: str, number_top: int) -> str:
    return f'''title-text: ""
desktop-color: "{c["surface"]}"
terminal-font: "Unifont Regular 16"
terminal-left: "0"
terminal-top: "0"
terminal-width: "100%"
terminal-height: "100%"
terminal-border: "0"

+ circular_progress {{
  id = "__timeout__"
  left = 50%-{RING // 2}
  top = 50%-470
  width = {RING}
  height = {RING}
  center_bitmap = "orbit_center.png"
  tick_bitmap = "orbit_tick.png"
  num_ticks = {TICKS}
  start_angle = -64
  ticks_disappear = true
}}

+ label {{
  id = "__timeout__"
  left = 50%-{RING // 2}
  top = 50%-{470 - number_top}
  width = {RING}
  height = {COUNT_FONT + 40}
  align = "center"
  text = "%d"
  font = "{fonts["count"]}"
  color = "{c["primaryContainerText"]}"
}}

+ label {{
  left = 0
  top = 50%-54
  width = 100%
  height = 40
  align = "center"
  text = "{host}"
  font = "{fonts["host"]}"
  color = "{c["surfaceVariantText"]}"
}}

+ boot_menu {{
  left = 50%-{MENU_W // 2 - CAP}
  top = 50%+8
  width = {MENU_W - 2 * CAP}
  height = {5 * ROW + 4 * ROW_GAP}
  item_font = "{fonts["menu"]}"
  selected_item_font = "{fonts["menu"]}"
  item_color = "{c["surfaceText"]}"
  selected_item_color = "{c["primaryText"]}"
  icon_width = {ICON}
  icon_height = {ICON}
  item_icon_space = {ICON_GAP}
  item_height = {ROW}
  item_padding = 0
  item_spacing = {ROW_GAP}
  selected_item_pixmap_style = "select_*.png"
  scrollbar = false
}}

+ label {{
  left = 0
  top = 100%-140
  width = 100%
  height = 30
  align = "center"
  text = "Enter start      E edit      C console"
  font = "{fonts["hint"]}"
  color = "{c["outline"]}"
}}
'''


def build(out: Path = OUT) -> Path:
    c = colors()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    draw_assets(c, out)
    titan = font_file("Titan One")
    medium = rubik_weight(500)
    regular = rubik_weight(400)
    fonts = {
        "menu": make_font(medium, MENU_FONT, "Rubik Medium", out),
        "host": make_font(regular, HOST_FONT, "Rubik", out),
        "hint": make_font(regular, HINT_FONT, "Rubik", out),
        "count": make_font(titan, COUNT_FONT, "Titan One", out),
    }
    (out / "theme.txt").write_text(theme_txt(c, fonts, host_line(), count_top(titan)))
    return out


def preview(src: Path, dst: Path, width: int = 1920, height: int = 1080, left: float = 0.6) -> Path:
    c = colors()
    img = Image.new("RGBA", (width, height), c["surface"])
    cx, cy = width // 2, height // 2
    ring_x, ring_y = cx - RING // 2, cy - 470
    img.alpha_composite(Image.open(src / "orbit_center.png"), (ring_x, ring_y))
    tick = Image.open(src / "orbit_tick.png")
    lit = round(TICKS * left)
    for i, (x, y) in enumerate(tick_centres(RING // 2 - TICK // 2 - 1)):
        if i < lit:
            img.alpha_composite(tick, (ring_x + round(x - TICK / 2), ring_y + round(y - TICK / 2)))
    d = ImageDraw.Draw(img)
    titan = ImageFont.truetype(str(font_file("Titan One")), COUNT_FONT)
    d.text((cx, ring_y + count_top(font_file("Titan One"))), "3", font=titan, fill=c["primaryContainerText"], anchor="ma")
    rubik = ImageFont.truetype(str(rubik_weight(400)), HOST_FONT)
    d.text((cx, cy - 54), host_line(), font=rubik, fill=c["surfaceVariantText"], anchor="ma")
    menu_font = ImageFont.truetype(str(rubik_weight(500)), MENU_FONT)
    x0 = cx - MENU_W // 2
    for i, (icon, label) in enumerate(PREVIEW_ROWS):
        y = cy + 8 + i * (ROW + ROW_GAP)
        if i == 0:
            d.rounded_rectangle((x0, y, x0 + MENU_W, y + ROW), radius=CAP, fill=c["primary"])
        img.alpha_composite(Image.open(src / "icons" / f"{icon}.png"), (x0 + CAP, y + (ROW - ICON) // 2))
        d.text((x0 + CAP + ICON + ICON_GAP, y + ROW // 2), label, font=menu_font,
               fill=c["primaryText"] if i == 0 else c["surfaceText"], anchor="lm")
    hint = ImageFont.truetype(str(rubik_weight(400)), HINT_FONT)
    d.text((cx, height - 140), "Enter start      E edit      C console", font=hint, fill=c["outline"], anchor="ma")
    img.convert("RGB").save(dst)
    return dst


def install(dry: bool) -> int:
    src = build()
    theme = TARGET / "theme.txt"
    steps = [
        ["sudo", "install", "-d", str(TARGET)],
        ["sudo", "cp", "-rT", str(src), str(TARGET)],
        ["sudo", "cp", "-n", str(DEFAULTS), str(DEFAULTS) + ".nebula-bak"],
        ["sudo", "sed", "-i", "-E", f's|^#?GRUB_THEME=.*|GRUB_THEME="{theme}"|', str(DEFAULTS)],
        ["sudo", "sed", "-i", "-E", 's|^#?GRUB_GFXMODE=.*|GRUB_GFXMODE=1920x1080,auto|', str(DEFAULTS)],
        ["sudo", "grub-mkconfig", "-o", "/boot/grub/grub.cfg"],
    ]
    for cmd in steps:
        print("$ " + " ".join(cmd))
        if not dry and subprocess.run(cmd).returncode != 0:
            print("stopped; nothing after this step ran", file=sys.stderr)
            return 1
    if not dry:
        print(f"installed {NAME}; the old /etc/default/grub is at {DEFAULTS}.nebula-bak")
    return 0


def main():
    parser = argparse.ArgumentParser(prog="nebula grub", description="Nebula GRUB theme from the current palette")
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_build = sub.add_parser("build", help=f"write the theme to {OUT}")
    p_build.add_argument("--out", default=str(OUT))
    p_prev = sub.add_parser("preview", help="render a PNG of the boot screen")
    p_prev.add_argument("--out", default=str(CACHE_DIR / "grub" / "preview.png"))
    p_inst = sub.add_parser("install", help=f"copy to {TARGET}, set GRUB_THEME and regenerate grub.cfg (sudo)")
    p_inst.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.cmd == "build":
        print(build(Path(args.out)))
        return 0
    if args.cmd == "preview":
        with tempfile.TemporaryDirectory() as tmp:
            src = build(Path(tmp) / NAME)
            print(preview(src, Path(args.out)))
        return 0
    return install(args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
