import html
from datetime import date, timedelta
from pathlib import Path

from nebula.kindle_ac import CSS, H, W, tabs_html, to_portrait

DAYS = 380
CONDS = {"sunny": "Sunny", "clear": "Clear", "partly": "Partly cloudy", "cloudy": "Cloudy", "fog": "Fog",
         "rain": "Rain", "snow": "Snow", "storm": "Storm", "na": "–"}
COND_ICONS = {"sunny": "sun", "clear": "moon", "partly": "partly", "cloudy": "cloud", "fog": "fog",
              "rain": "rain", "snow": "snow", "storm": "storm"}

REGIONS = {
    "khour": (24, 86, 330, 241),
    "kmin": (24, 337, 330, 241),
    "kday": (376, 86, 400, 194),
    "koutv": (379, 330, 211, 140),
    "koutc": (590, 322, 176, 146),
    "khol": (376, 508, 400, 70),
}


def tile(text, dark, corner=""):
    bg, fg = ("#000000", "#FFFFFF") if dark else ("#EEEEEE", "#000000")
    tag = (f'<div style="position:absolute;right:22px;top:16px;font-size:22px;font-weight:600;letter-spacing:1px">{corner}</div>'
           if corner else "")
    return (f'<div style="position:absolute;inset:0;border-radius:34px;background:{bg};color:{fg};display:flex;align-items:center;'
            f'justify-content:center;font-family:\'Titan One\',sans-serif;font-size:210px;line-height:1">{text}{tag}</div>')


def day_panel(d, holidays):
    monday = d - timedelta(days=d.weekday())
    cells = []
    for i in range(7):
        x = monday + timedelta(days=i)
        today, hol = x == d, x in holidays
        bg = "#000000" if today else "#FFFFFF" if hol else "#EEEEEE"
        fg = "#FFFFFF" if today else "#000000"
        border = "border:3px solid #000000;" if hol and not today else ""
        cells.append(f'<div style="position:absolute;left:{i * 58}px;top:124px;width:52px;height:70px;box-sizing:border-box;border-radius:16px;'
                     f'background:{bg};color:{fg};{border}display:flex;flex-direction:column;align-items:center;justify-content:center;gap:1px">'
                     f'<div style="font-size:13px;font-weight:600">{x:%a}</div><div style="font-size:22px;font-weight:600">{x.day}</div></div>')
    return (f'<div style="position:absolute;left:0;top:0;font-family:\'Titan One\',sans-serif;font-size:54px;line-height:1">{d:%A}</div>'
            f'<div style="position:absolute;left:2px;top:64px;font-size:24px;font-weight:500">{d.day} {d:%B %Y}</div>'
            + "".join(cells))


def holiday_pill(d, upcoming):
    nxt = next(((hd, name) for hd, name in upcoming if hd >= d), None)
    if not nxt:
        return ""
    hd, name = nxt
    when = "Today" if hd == d else "Tomorrow" if (hd - d).days == 1 else f"{hd:%a} {hd.day} {hd:%b}"
    return (f'<div style="position:absolute;inset:0;border-radius:999px;background:#000000;color:#FFFFFF;display:flex;align-items:center;'
            f'gap:10px;padding:0 18px;font-size:17px">'
            f'<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round" style="flex:none">'
            f'<rect x="3" y="5" width="18" height="16" rx="3"></rect><path d="M3 10h18M8 3v4M16 3v4"></path></svg>'
            f'<div style="font-weight:600;white-space:nowrap">{when}</div>'
            f'<div style="font-weight:500;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{html.escape(name)}</div></div>')


def value(text):
    return (f'<div style="position:absolute;left:14px;bottom:6px;font-family:\'Titan One\',sans-serif;font-size:104px;'
            f'line-height:1">{text}</div>')


def cond(key, label):
    from nebula.kindle import ICONS
    icon = ICONS.get(COND_ICONS.get(key, ""), "")
    svg = (f'<svg width="96" height="96" viewBox="0 0 48 48" fill="none" stroke="#000000" stroke-width="3" stroke-linecap="round" '
           f'stroke-linejoin="round">{icon}</svg>' if icon else "")
    return (f'<div style="position:absolute;inset:0;display:flex;flex-direction:column;align-items:flex-end;justify-content:center;'
            f'gap:8px;padding-right:12px">{svg}<div style="font-size:22px;font-weight:500;white-space:nowrap">{label}</div></div>')


def card(label):
    return ('<div style="position:absolute;left:376px;top:296px;width:400px;height:196px;box-sizing:border-box;border:3px solid #000000;'
            f'border-radius:22px"></div><div style="position:absolute;left:393px;top:310px;font-size:15px;font-weight:600;'
            f'letter-spacing:1.5px">{label}</div>')


def holidays_ahead(start):
    from nebula import kindle as k
    rows, seen, d = [], set(), start
    while d <= start + timedelta(days=DAYS + 400):
        hol = k.next_holiday(d)
        if not hol or hol[0] in seen:
            if not hol:
                break
            d = hol[0] + timedelta(days=1)
            continue
        seen.add(hol[0])
        rows.append(hol)
        d = hol[0] + timedelta(days=1)
    return rows


def items(start, place):
    upcoming = holidays_ahead(start)
    hol_days = {hd for hd, _ in upcoming}
    out = []
    for h in range(24):
        h12 = h % 12 or 12
        out.append(("khour", tile(str(h12), True, "am" if h < 12 else "pm"), f"hour-{h:02d}"))
    for m in range(60):
        out.append(("kmin", tile(f"{m:02d}", False), f"min-{m:02d}"))
    for i in range(DAYS):
        d = start + timedelta(days=i)
        out.append(("kday", day_panel(d, hol_days), f"day-{d:%Y%m%d}"))
        out.append(("khol", holiday_pill(d, upcoming), f"hol-{d:%Y%m%d}"))
    out.append(("kday", "", "day-none"))
    out.append(("khol", "", "hol-none"))
    for t in list(range(0, 51)) + ["na"]:
        out.append(("koutv", value(f"{t}°" if t != "na" else "–"), f"outv-{t}"))
    for key, label in CONDS.items():
        out.append(("koutc", cond(key, label), f"outc-{key}"))
    return out


def page_html(place):
    return (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}body{{width:{W}px;height:{H}px;overflow:hidden}}</style></head><body>'
            f'{tabs_html("clock")}'
            f'<div style="position:absolute;right:24px;top:36px;font-size:16px;font-weight:500;color:#222222">{html.escape(place)}</div>'
            f'{card("OUTSIDE")}</body></html>')


def box(name, inner, x, y):
    rw, rh = REGIONS[name][2], REGIONS[name][3]
    return f'<div class="box" style="left:{x}px;top:{y}px;width:{rw}px;height:{rh}px;background:#FFFFFF">{inner}</div>'


def render_chunks(entries, width=1400, limit=12000):
    from nebula import kindle as k
    sheets, cur, x, y, row_h = [], [], 0, 0, 0
    for name, inner, key in entries:
        rw, rh = REGIONS[name][2], REGIONS[name][3]
        if x + rw > width:
            x, y, row_h = 0, y + row_h + 4, 0
        if y + rh > limit:
            sheets.append((cur, y + row_h))
            cur, x, y, row_h = [], 0, 0, 0
        cur.append((name, inner, key, x, y))
        x += rw + 4
        row_h = max(row_h, rh)
    if cur:
        sheets.append((cur, y + row_h))
    for cells, total in sheets:
        body = "".join(box(n, inner, cx, cy) for n, inner, _, cx, cy in cells)
        page = (f'<!doctype html><html><head><meta charset="utf-8"><style>{CSS}body{{width:{width}px;height:{total}px;overflow:hidden}}</style></head>'
                f'<body>{body}</body></html>')
        sheet = k.screenshot(page, width, total)
        for n, _, key, cx, cy in cells:
            rw, rh = REGIONS[n][2], REGIONS[n][3]
            yield key, sheet.crop((cx, cy, cx + rw, cy + rh))


def build(out_dir, rotate="ccw", place=""):
    from nebula import kindle as k
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    for old in out_dir.glob("*.png"):
        old.unlink()
    angle = {"cw": 90, "ccw": -90}.get(rotate, 0)
    bg = k.screenshot(page_html(place), W, H)
    k.snap(bg.rotate(angle, expand=True) if angle else bg).save(out_dir / "background.png", optimize=True)
    count = 0
    for key, img in render_chunks(items(date.today(), place)):
        k.snap(img.rotate(angle, expand=True) if angle else img).save(out_dir / f"{key}.png", optimize=True)
        count += 1
    lines = [f'R_{name}="{" ".join(str(v) for v in to_portrait(rect, rotate))}"' for name, rect in REGIONS.items()]
    (out_dir / "layout.sh").write_text("\n".join(lines) + "\n")
    return out_dir, count
