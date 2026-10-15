import html
from math import pi
from pathlib import Path

W, H = 800, 600
TEMPS = range(16, 31)
MODES = [("cool", "Cool", "M12 2v20M4 6l16 12M20 6L4 18"),
         ("dry", "Dry", "M12 3c3 4 6 7 6 11a6 6 0 0 1-12 0c0-4 3-7 6-11z"),
         ("fan", "Fan", "M12 12c0-5 2-8 5-8s3 4-5 8zM12 12c5 0 8 2 8 5s-4 3-8-5zM12 12c0 5-2 8-5 8s-3-4 5-8zM12 12c-5 0-8-2-8-5s4-3 8 5z"),
         ("auto", "Auto", "M4 20l8-16 8 16M7 14h10")]
FANS = [("auto", "Auto"), ("quiet", "Quiet"), ("low", "Low"), ("medium", "Med"), ("high", "High")]
POWER = {"cool": "Cooling", "dry": "Drying", "fan": "Fan only", "auto": "Auto", "heat": "Heating",
         "off": "AC is off", "offline": "AC offline"}
HEADS = {"online": "online", "offline": "offline", "busy": "sending…", "login": "check login"}

REGIONS = {
    "dial": (40, 143, 368, 210),
    "room": (56, 375, 168, 44),
    "out": (232, 375, 176, 44),
    "power": (438, 86, 338, 96),
    "mode": (438, 218, 338, 72),
    "fan": (438, 326, 338, 60),
    "swing": (438, 422, 108, 74),
    "eco": (553, 422, 108, 74),
    "display": (668, 422, 108, 74),
    "powerful": (438, 504, 108, 74),
    "nanoe": (553, 504, 108, 74),
    "clean": (668, 504, 108, 74),
    "head": (536, 24, 240, 46),
}

BG = {"dial": "#EEEEEE", "room": "#EEEEEE", "out": "#EEEEEE"}

CSS = """html,body{margin:0;background:#FFFFFF}
body{font-family:Rubik,sans-serif;color:#000000;position:relative}
.box{position:absolute;overflow:hidden;box-sizing:border-box}
.display{font-family:'Titan One',sans-serif}
.cap{position:absolute;font-size:14px;font-weight:600;letter-spacing:1.5px}
.btn{position:absolute;display:flex;align-items:center;justify-content:center;box-sizing:border-box}"""


def arc(on):
    r, sweep = 84, 0.75
    c = 2 * pi * r
    return c * sweep, c


def dial(temp, powered):
    track, full = arc(True)
    pct = (temp - TEMPS[0]) / (TEMPS[-1] - TEMPS[0])
    fg = "#000000" if powered else "#BBBBBB"
    num = "#000000" if powered else "#555555"
    minus_bg, minus_fg = ("#FFFFFF", "#000000")
    plus_bg, plus_fg = ("#000000", "#FFFFFF") if powered else ("#FFFFFF", "#000000")
    return (f'<div class="btn" style="left:0;top:69px;width:72px;height:72px;border-radius:999px;background:{minus_bg};border:3px solid #000000">'
            f'<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="{minus_fg}" stroke-width="2.6" stroke-linecap="round"><path d="M5 12h14"></path></svg></div>'
            f'<div style="position:absolute;left:84px;top:5px;width:200px;height:200px">'
            f'<svg width="200" height="200" viewBox="0 0 200 200" style="position:absolute;left:0;top:0">'
            f'<circle cx="100" cy="100" r="84" fill="none" stroke="#CCCCCC" stroke-width="18" stroke-dasharray="{track:.1f} {full:.1f}" stroke-linecap="round" transform="rotate(135 100 100)"></circle>'
            f'<circle cx="100" cy="100" r="84" fill="none" stroke="{fg}" stroke-width="18" stroke-dasharray="{max(0.5, track * pct):.1f} {full:.1f}" stroke-linecap="round" transform="rotate(135 100 100)"></circle></svg>'
            f'<div style="position:absolute;left:0;top:0;width:200px;height:200px;display:flex;flex-direction:column;align-items:center;justify-content:center">'
            f'<div style="font-size:14px;font-weight:600;letter-spacing:1.5px;color:#222222">{"SET TO" if powered else "WAS SET"}</div>'
            f'<div class="display" style="font-size:72px;line-height:1;color:{num}">{temp}°</div></div></div>'
            f'<div class="btn" style="left:296px;top:69px;width:72px;height:72px;border-radius:999px;background:{plus_bg};border:3px solid #000000">'
            f'<svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="{plus_fg}" stroke-width="2.6" stroke-linecap="round"><path d="M5 12h14M12 5v14"></path></svg></div>')


def pill(text, width):
    return (f'<div class="btn" style="left:0;top:0;width:{width}px;height:44px;border-radius:999px;background:#FFFFFF;'
            f'font-size:17px;font-weight:600">{text}</div>')


def power(state):
    on = state not in ("off", "offline")
    bg, fg, sub = ("#000000", "#FFFFFF", "#DDDDDD") if on else ("#FFFFFF", "#000000", "#222222")
    hint = "tap to turn off" if on else ("tap to turn on" if state == "off" else "check Wi-Fi on the AC")
    border = "" if on else "border:3px solid #000000;"
    knob_bg, knob_fg = ("#FFFFFF", "#000000") if on else ("#000000", "#FFFFFF")
    return (f'<div style="position:absolute;inset:0;border-radius:26px;background:{bg};color:{fg};{border}box-sizing:border-box;'
            f'display:flex;align-items:center;justify-content:space-between;padding:0 18px">'
            f'<div style="display:flex;flex-direction:column;gap:2px"><div style="font-size:26px;font-weight:600">{POWER[state]}</div>'
            f'<div style="font-size:15px;font-weight:500;color:{sub}">{hint}</div></div>'
            f'<div class="btn" style="position:relative;width:64px;height:64px;border-radius:999px;background:{knob_bg}">'
            f'<svg width="30" height="30" viewBox="0 0 24 24" fill="none" stroke="{knob_fg}" stroke-width="2.6" stroke-linecap="round"><path d="M12 3v8"></path><path d="M6.3 7.3a8 8 0 1 0 11.4 0"></path></svg></div></div>')


def buttons(items, active, powered, height, gap, icons):
    n = len(items)
    width = (338 - gap * (n - 1)) / n
    out = []
    for i, item in enumerate(items):
        key, label = item[0], item[1]
        on = key == active
        if on and powered:
            bg, fg, border = "#000000", "#FFFFFF", "none"
        elif on:
            bg, fg, border = "#FFFFFF", "#000000", "3px solid #000000"
        else:
            bg, fg, border = "#EEEEEE", "#000000", "none"
        icon = (f'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="{fg}" stroke-width="2.2" stroke-linecap="round" '
                f'stroke-linejoin="round"><path d="{item[2]}"></path></svg>') if icons else ""
        out.append(f'<div class="btn" style="left:{i * (width + gap):.1f}px;top:0;width:{width:.1f}px;height:{height}px;border-radius:18px;'
                   f'background:{bg};color:{fg};border:{border};flex-direction:column;gap:2px;font-size:{15 if icons else 16}px;font-weight:600">{icon}{label}</div>')
    return "".join(out)


TOGGLES = {
    "swing": ("Swing", "M4 8c4-4 12-4 16 0M7 12c3-2.5 7-2.5 10 0M10 16c1.2-1 2.8-1 4 0"),
    "eco": ("Eco", "M5 19c0-9 6-14 15-14 0 9-5 15-14 15M5 19l7-7"),
    "display": ("Display", "M3 5h18v11H3zM8 20h8M12 16v4"),
    "powerful": ("Powerful", "M13 2L4 14h7l-1 8 9-12h-7z"),
    "nanoe": ("Nanoe", "M12 2v4M12 18v4M2 12h4M18 12h4M5 5l3 3M16 16l3 3M5 19l3-3M16 8l3-3"),
    "clean": ("Clean", "M12 3c3 4 6 7 6 11a6 6 0 0 1-12 0c0-4 3-7 6-11zM9 14a3 3 0 0 0 3 3"),
}


def toggle(kind, on):
    label, path = TOGGLES[kind]
    bg, fg, border = ("#000000", "#FFFFFF", "none") if on else ("#FFFFFF", "#000000", "2px solid #000000")
    return (f'<div class="btn" style="left:0;top:0;width:108px;height:74px;border-radius:18px;background:{bg};color:{fg};border:{border};'
            f'flex-direction:column;gap:4px;font-size:15px;font-weight:600"><svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="{fg}" '
            f'stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="{path}"></path></svg>{label}</div>')


def head(state):
    dot = ('<svg width="12" height="12" viewBox="0 0 24 24" fill="#000000"><circle cx="12" cy="12" r="7"></circle></svg>'
           if state == "online" else
           '<svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="3"><circle cx="12" cy="12" r="7"></circle></svg>')
    bg = "#000000" if state == "busy" else "#EEEEEE"
    fg = "#FFFFFF" if state == "busy" else "#000000"
    if state == "busy":
        dot = dot.replace("#000000", "#FFFFFF")
    return (f'<div style="position:absolute;right:0;top:0;height:46px;display:flex;align-items:center;gap:8px;background:{bg};color:{fg};'
            f'border-radius:999px;padding:0 16px;font-size:16px;font-weight:600">{dot}MirAIe · {HEADS[state]}</div>')


def region_html(name, state):
    if name == "dial":
        return dial(state[0], state[1])
    if name == "room":
        return pill(f"Room {state}°" if state != "na" else "Room –", 168)
    if name == "out":
        return pill(f"Outside {state}°" if state != "na" else "Outside –", 176)
    if name == "power":
        return power(state)
    if name == "mode":
        return buttons(MODES, state[0], state[1], 72, 6, True)
    if name == "fan":
        return buttons(FANS, state[0], state[1], 60, 6, False)
    if name in TOGGLES:
        return toggle(name, state)
    if name == "head":
        return head(state)
    raise KeyError(name)


def variants():
    out = []
    for t in TEMPS:
        for p in (True, False):
            out.append(("dial", (t, p), f"dial-{'on' if p else 'off'}-{t}"))
    for r in list(range(10, 46)) + ["na"]:
        out.append(("room", r, f"room-{r}"))
    for o in list(range(0, 51)) + ["na"]:
        out.append(("out", o, f"out-{o}"))
    for s in POWER:
        out.append(("power", s, f"power-{s}"))
    for p in (True, False):
        for m in [m[0] for m in MODES] + ["none"]:
            out.append(("mode", (m, p), f"mode-{'on' if p else 'off'}-{m}"))
        for f in [f[0] for f in FANS] + ["none"]:
            out.append(("fan", (f, p), f"fan-{'on' if p else 'off'}-{f}"))
    for k in TOGGLES:
        for v in (True, False):
            out.append((k, v, f"{k}-{'on' if v else 'off'}"))
    for h in HEADS:
        out.append(("head", h, f"head-{h}"))
    return out


def box(name, inner, x=None, y=None):
    rx, ry, rw, rh = REGIONS[name]
    x = rx if x is None else x
    y = ry if y is None else y
    return f'<div class="box" style="left:{x}px;top:{y}px;width:{rw}px;height:{rh}px;background:{BG.get(name, "#FFFFFF")}">{inner}</div>'


TABS = [("ac", "AC"), ("clock", "Clock"), ("frame", "Frame")]
TAB_STEP = 110
TABS_W = 6 + len(TABS) * TAB_STEP
SYS_REGION = (372, 24, 156, 46)
WIFI = ("off", "1", "2", "3")


def wifi_svg(state):
    on = {"off": 0, "1": 1, "2": 2, "3": 3}[state]
    arcs = ["M8.5 15.5a5 5 0 0 1 7 0", "M5 12a10 10 0 0 1 14 0", "M1.5 8.5a15 15 0 0 1 21 0"]
    paths = "".join(f'<path d="{d}" stroke="{"#000000" if i < on else "#BBBBBB"}"></path>' for i, d in enumerate(arcs))
    cross = '<path d="M3 3l18 18" stroke="#000000"></path>' if state == "off" else ""
    return (f'<svg width="26" height="26" viewBox="0 0 24 24" fill="none" stroke-width="2.4" stroke-linecap="round">{paths}'
            f'<circle cx="12" cy="19" r="1.6" fill="{"#000000" if on else "#BBBBBB"}" stroke="none"></circle>{cross}</svg>')


def battery_svg(pct, charging):
    fill = max(0, min(100, pct)) / 100 * 22
    bolt = ('<path d="M15 4.5l-4.5 6h3.5l-2 4.5 5-6.5h-3.5z" fill="#FFFFFF" stroke="#000000" stroke-width="0.8" stroke-linejoin="round"></path>'
            if charging else "")
    return (f'<svg width="34" height="20" viewBox="0 0 30 18" fill="none">'
            f'<rect x="1.2" y="2" width="25" height="14" rx="3.5" stroke="#000000" stroke-width="2"></rect>'
            f'<rect x="27.5" y="6.5" width="2" height="5" rx="1" fill="#000000"></rect>'
            f'<rect x="3.2" y="4" width="{fill:.1f}" height="10" rx="2" fill="#000000"></rect>{bolt}</svg>')


def sys_html(wifi, pct, charging):
    return (f'<div style="position:absolute;left:0;top:0;width:156px;height:46px;box-sizing:border-box;border-radius:999px;background:#EEEEEE;'
            f'display:flex;align-items:center;justify-content:center;gap:8px;font-family:Rubik,sans-serif;font-size:16px;font-weight:600;color:#000000">'
            f'{wifi_svg(wifi)}{battery_svg(pct, charging)}{pct}%</div>')


def build_sys(out_dir, rotate):
    from nebula import kindle as k
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    angle = {"cw": 90, "ccw": -90}.get(rotate, 0)
    keys, cells = [], []
    for w in WIFI:
        for pct in range(0, 101, 5):
            for chg in (0, 1):
                keys.append(f"sys-{w}-{pct}-{chg}")
                cells.append(sys_html(w, pct, bool(chg)))
    cols = 8
    rows = (len(cells) + cols - 1) // cols
    body = "".join(f'<div style="position:absolute;left:{(i % cols) * 160}px;top:{(i // cols) * 50}px;width:156px;height:46px">{c}</div>'
                   for i, c in enumerate(cells))
    page = (f'<!doctype html><html><head><meta charset="utf-8"><style>html,body{{margin:0;background:#FFFFFF}}'
            f'body{{width:{cols * 160}px;height:{rows * 50}px;position:relative;overflow:hidden}}</style></head><body>{body}</body></html>')
    sheet = k.screenshot(page, cols * 160, rows * 50)
    for i, key in enumerate(keys):
        x, y = (i % cols) * 160, (i // cols) * 50
        img = sheet.crop((x, y, x + 156, y + 46))
        k.snap(img.rotate(angle, expand=True) if angle else img).save(out_dir / f"{key}.png", optimize=True)
    (out_dir / "layout.sh").write_text(f'R_sys="{" ".join(str(v) for v in to_portrait(SYS_REGION, rotate))}"\n')
    return len(keys)


def tabs_html(active):
    out = [f'<div style="position:absolute;left:24px;top:22px;width:{TABS_W}px;height:50px;border-radius:999px;background:#EEEEEE"></div>']
    for i, (key, label) in enumerate(TABS):
        on = key == active
        style = "background:#000000;color:#FFFFFF;" if on else "color:#000000;"
        out.append(f'<div style="position:absolute;left:{29 + i * TAB_STEP}px;top:27px;width:{TAB_STEP - 4}px;height:40px;border-radius:999px;'
                   f'display:flex;align-items:center;justify-content:center;font-family:Rubik,sans-serif;font-size:17px;font-weight:600;{style}">{label}</div>')
    return "".join(out)


def page_html():
    tabs = tabs_html("ac")
    card = '<div style="position:absolute;left:24px;top:86px;width:400px;height:492px;border-radius:30px;background:#EEEEEE"></div>'
    caps = ('<div class="cap" style="left:442px;top:196px">MODE</div>'
            '<div class="cap" style="left:442px;top:304px">FAN</div>'
            '<div class="cap" style="left:442px;top:400px">OPTIONS</div>')
    presets = ('<div class="btn" style="left:40px;top:447px;width:176px;height:74px;border-radius:20px;background:#FFFFFF;justify-content:flex-start;gap:12px;padding-left:14px">'
               '<div class="btn" style="position:relative;width:46px;height:46px;border-radius:14px;background:#000000;color:#FFFFFF;font-size:17px;font-weight:600">24°</div>'
               '<div style="display:flex;flex-direction:column"><div style="font-size:18px;font-weight:600">Cool</div><div style="font-size:13px;font-weight:500;color:#222222">fan auto</div></div></div>'
               '<div class="btn" style="left:232px;top:447px;width:176px;height:74px;border-radius:20px;background:#FFFFFF;justify-content:flex-start;gap:12px;padding-left:14px">'
               '<div class="btn" style="position:relative;width:46px;height:46px;border-radius:14px;background:#000000;color:#FFFFFF;font-size:17px;font-weight:600">26°</div>'
               '<div style="display:flex;flex-direction:column"><div style="font-size:18px;font-weight:600">Night</div><div style="font-size:13px;font-weight:500;color:#222222">fan low</div></div></div>')
    defaults = {"dial": (24, True), "room": "na", "out": "na", "power": "cool", "mode": ("cool", True),
                "fan": ("auto", True), "swing": True, "eco": False, "display": True, "powerful": False,
                "nanoe": False, "clean": False, "head": "online"}
    regions = "".join(box(n, region_html(n, s)) for n, s in defaults.items())
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}body{{width:{W}px;height:{H}px;overflow:hidden}}</style></head>'
            f'<body>{tabs}{card}{caps}{presets}{regions}</body></html>')


def atlas_html(items):
    cells, x, y, row_h, width = [], 0, 0, 0, 1400
    for name, state, key in items:
        rw, rh = REGIONS[name][2], REGIONS[name][3]
        if x + rw > width:
            x, y, row_h = 0, y + row_h + 4, 0
        cells.append((key, x, y, rw, rh))
        x += rw + 4
        row_h = max(row_h, rh)
    body = "".join(box(name, region_html(name, state), cx, cy) for (name, state, _), (_, cx, cy, _, _) in zip(items, cells))
    total = y + row_h
    page = (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}body{{width:{width}px;height:{total}px;overflow:hidden}}</style></head>'
            f'<body>{body}</body></html>')
    return page, cells, width, total


HITS = {
    "minus": (40, 178, 96, 140),
    "plus": (312, 178, 96, 140),
    "power": (438, 86, 338, 96),
    "preset_cool": (40, 447, 176, 74),
    "preset_night": (232, 447, 176, 74),
    "swing": (438, 422, 108, 74),
    "eco": (553, 422, 108, 74),
    "display": (668, 422, 108, 74),
    "powerful": (438, 504, 108, 74),
    "nanoe": (553, 504, 108, 74),
    "clean": (668, 504, 108, 74),
}


def hits():
    out = dict(HITS)
    for i, (key, _) in enumerate(TABS):
        left = 24 if i == 0 else 29 + i * TAB_STEP
        right = 24 + TABS_W if i == len(TABS) - 1 else 29 + (i + 1) * TAB_STEP
        out[f"tab_{key}"] = (left, 22, right - left, 50)
    for items, prefix, top, height, gap in ((MODES, "mode", 218, 72, 6), (FANS, "fan", 326, 60, 6)):
        n = len(items)
        width = (338 - gap * (n - 1)) / n
        for i, item in enumerate(items):
            out[f"{prefix}_{item[0]}"] = (round(438 + i * (width + gap)), top, round(width), height)
    return out


def to_portrait(rect, rotate):
    x, y, w, h = rect
    if rotate == "cw":
        return (y, W - (x + w), h, w)
    if rotate == "ccw":
        return (H - (y + h), x, h, w)
    return rect


def build(out_dir, rotate="ccw"):
    from nebula import kindle as k
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    angle = {"cw": 90, "ccw": -90}.get(rotate, 0)

    bg = k.screenshot(page_html(), W, H)
    k.snap(bg.rotate(angle, expand=True) if angle else bg).save(out_dir / "background.png", optimize=True)

    items = variants()
    page, cells, aw, ah = atlas_html(items)
    sheet = k.screenshot(page, aw, ah)
    for key, cx, cy, cw, ch in cells:
        img = sheet.crop((cx, cy, cx + cw, cy + ch))
        k.snap(img.rotate(angle, expand=True) if angle else img).save(out_dir / f"{key}.png", optimize=True)

    lines = [f'AC_ROTATE={rotate}']
    for name, rect in REGIONS.items():
        lines.append(f'R_{name}="{" ".join(str(v) for v in to_portrait(rect, rotate))}"')
    for name, rect in hits().items():
        lines.append(f'T_{name}="{" ".join(str(v) for v in to_portrait(rect, rotate))}"')
    (out_dir / "layout.sh").write_text("\n".join(lines) + "\n")
    return out_dir, len(cells)
