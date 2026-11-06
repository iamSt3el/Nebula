import argparse
import html
import json
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from datetime import date, datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from string import Template
from urllib.parse import parse_qs, urlparse

from nebula.paths import CACHE_DIR, SETTINGS

WIDTH, HEIGHT = 600, 800
OUT_DIR = CACHE_DIR / "kindle"
CHROMES = ("google-chrome-stable", "google-chrome", "chromium", "chromium-browser")
WEATHER_MAX_AGE = 45 * 60

SUN = '<circle cx="24" cy="24" r="9"></circle><path d="M24 4v6M24 38v6M4 24h6M38 24h6M9.9 9.9l4.2 4.2M33.9 33.9l4.2 4.2M9.9 38.1l4.2-4.2M33.9 14.1l4.2-4.2"></path>'
MOON = '<path d="M36 30A15 15 0 0 1 19 8a15 15 0 1 0 17 22z"></path>'
CLOUD = '<path d="M14 36h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 36z"></path>'
PARTLY = '<path d="M17 8v3M8.5 11.5l2 2M5 20h3M25.5 11.5l-2 2"></path><path d="M11 22a6 6 0 0 1 11.6-2.2"></path><path d="M18 40h18a7 7 0 0 0 0-14 9.5 9.5 0 0 0-18-1.5A7.8 7.8 0 0 0 18 40z"></path>'
RAIN = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M16 36l-2 6M24 36l-2 6M32 36l-2 6"></path>'
STORM = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M25 32l-5 7h6l-4 7"></path>'
SNOW = '<path d="M14 30h20a8 8 0 0 0 0-16 11 11 0 0 0-21-2A9 9 0 0 0 14 30z"></path><path d="M17 37v6M14 40h6M31 37v6M28 40h6"></path>'
FOG = '<path d="M8 18h32M6 26h36M10 34h28"></path>'

PAGE = Template("""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<style>
html,body{margin:0;background:#FFFFFF}
body{width:600px;height:800px;overflow:hidden;font-family:Rubik,sans-serif;color:#000000}
.page{width:600px;height:800px;box-sizing:border-box;padding:32px 36px 28px;display:flex;flex-direction:column;gap:16px}
.display{font-family:'Titan One',sans-serif}
.row{display:flex}
.chip{border:2px solid #000000;border-radius:14px;padding:10px 12px;display:flex;flex-direction:column;gap:2px}
.chip .k{font-size:15px;font-weight:500;color:#222222}
.chip .v{font-size:26px;font-weight:600}
.chip .u{font-size:15px}
.cap{font-size:15px;font-weight:600;letter-spacing:1.5px;color:#000000}
.bar{display:flex;flex-direction:column;align-items:center;justify-content:flex-end;gap:6px;height:136px}
.bar .t{font-size:17px;font-weight:600}
.bar .b{width:100%;border-radius:8px 8px 3px 3px}
.bar .l{font-size:15px;font-weight:500;color:#222222}
.sun{flex:1;display:flex;align-items:center;gap:8px;background:#DDDDDD;border-radius:12px;padding:10px 12px;font-size:18px}
.day{border:2px solid #000000;border-radius:14px;padding:12px 14px;display:flex;align-items:center;justify-content:space-between}
</style></head>
<body><div class="page">
<div class="row" style="justify-content:space-between;align-items:flex-end">
<div style="display:flex;flex-direction:column;gap:2px">
<div class="display" style="font-size:46px;line-height:1">$weekday</div>
<div style="font-size:22px;font-weight:500;color:#111111">$longdate</div>
</div>
<div style="display:flex;flex-direction:column;align-items:flex-end;gap:4px;font-size:16px;color:#222222">
<div style="font-weight:600;color:#000000">$place</div>
<div>$stamp</div>
</div>
</div>
<div class="row" style="align-items:center;gap:22px;border-top:3px solid #000000;padding-top:18px">
<svg data-slot="icon" width="118" height="118" viewBox="0 0 48 48" fill="none" stroke="#000000" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">$icon</svg>
<div class="display" style="font-size:150px;line-height:0.9">$temp</div>
<div style="display:flex;flex-direction:column;gap:6px;margin-left:auto;text-align:right">
<div style="font-size:30px;font-weight:600">$desc</div>
<div style="font-size:20px;font-weight:500;color:#111111">$feels</div>
<div style="font-size:20px;font-weight:500;color:#111111">$hilo</div>
</div>
</div>
<div style="display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:10px">
<div class="chip"><div class="k">Humidity</div><div class="v">$humidity</div></div>
<div class="chip"><div class="k">Wind</div><div class="v">$wind <span class="u">$windunit</span></div></div>
<div class="chip"><div class="k">UV</div><div class="v">$uv</div></div>
<div class="chip"><div class="k">Rain</div><div class="v">$rain</div></div>
</div>
<div style="display:flex;flex-direction:column;gap:8px">
<div class="cap">TODAY</div>
<div style="display:grid;grid-template-columns:repeat(8,minmax(0,1fr));gap:8px;align-items:end;height:136px">$bars</div>
</div>
<div class="row" style="gap:10px">
<div class="sun"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round"><path d="M4 18h16M7 18a5 5 0 0 1 10 0M12 4v4M9.5 6.5 12 4l2.5 2.5"></path></svg>$sunrise</div>
<div class="sun"><svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="2" stroke-linecap="round"><path d="M4 18h16M7 18a5 5 0 0 1 10 0M12 8V4M9.5 5.5 12 8l2.5-2.5"></path></svg>$sunset</div>
<div class="sun" style="flex:1.3">$daylight</div>
</div>
<div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px">$days</div>
$footer
</div>$probe</body></html>
""")


def load_settings():
    try:
        with open(SETTINGS) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def weather_data(settings):
    from nebula import weather as w
    cache = w.load_cache()
    wx = settings.get("weather", {})
    name = ("auto" if wx.get("useGeoFile") else (wx.get("location") or cache.get("location") or "")).strip()
    try:
        age = time.time() - Path(w.CACHE).stat().st_mtime
    except OSError:
        age = None
    stale = age is None or age > WEATHER_MAX_AGE or cache.get("location") != name
    if stale and name:
        try:
            lat, lon, area = w.geocode(name, cache)
            cache = {"location": name, "lat": lat, "lon": lon, "area": area, "data": w.build(name, lat, lon, area)}
            w.save_cache(cache)
        except (OSError, ValueError, KeyError, LookupError, TypeError, IndexError):
            pass
    return cache


def next_holiday(today):
    from nebula import holidays as h
    cc = (load_settings().get("general", {}).get("holidayCountry") or h.detect_country() or "").upper()
    rows = []
    for year in (today.year, today.year + 1):
        try:
            with open(Path(h.CACHE_DIR) / f"{cc}-{year}.json") as f:
                rows += json.load(f)
        except (OSError, ValueError):
            pass
    for r in sorted(rows, key=lambda r: r.get("date", "")):
        try:
            d = date.fromisoformat(r["date"])
        except (KeyError, ValueError):
            continue
        if d >= today:
            return d, r.get("name", "")
    return None


def icon_for(code, desc):
    c = str(code)
    if desc == "Clear":
        return MOON
    if c == "113":
        return SUN
    if c == "116":
        return PARTLY
    if c in ("248", "260"):
        return FOG
    if c in ("386", "389"):
        return STORM
    if c in ("179", "326", "332", "338", "368", "371"):
        return SNOW
    if c == "122":
        return CLOUD
    return RAIN


def clock24(text):
    try:
        return datetime.strptime(text.strip(), "%I:%M %p").strftime("%H:%M")
    except ValueError:
        return text


def minutes(hhmm):
    h, m = hhmm.split(":")
    return int(h) * 60 + int(m)


def summary(desc):
    words = {"Overcast": "Cloudy", "Mainly clear": "Mostly sunny"}
    return words.get(desc, desc)


def day_label(hourly):
    descs = [x["weatherDesc"][0]["value"] for x in hourly]
    if any("rain" in d.lower() or "thunder" in d.lower() for d in descs):
        return "Rain likely"
    late = descs[len(descs) // 2:]
    if any(d in ("Overcast", "Partly cloudy") for d in late) and descs[0] in ("Sunny", "Clear", "Mainly clear"):
        return "Clouds later"
    return summary(max(set(descs), key=descs.count))


PROBE = """<style>body.tpl [data-slot]{color:transparent!important}body.tpl svg[data-slot]{visibility:hidden}body.tpl .bar .b{visibility:hidden}</style>
<script>
(function () {
  var out = [];
  var els = document.querySelectorAll('[data-slot]');
  for (var i = 0; i < els.length; i++) {
    var e = els[i], r = e.getBoundingClientRect(), cs = getComputedStyle(e);
    out.push({slot: e.getAttribute('data-slot'), align: e.getAttribute('data-align') || 'left',
              x: r.left, y: r.top, w: r.width, h: r.height, right: r.right,
              size: parseFloat(cs.fontSize), family: cs.fontFamily, weight: cs.fontWeight, color: cs.color});
  }
  var bars = document.querySelectorAll('.bar .b');
  for (var j = 0; j < bars.length; j++) {
    var b = bars[j].getBoundingClientRect();
    out.push({slot: 'col' + j, x: b.left, y: b.bottom, w: b.width, h: 0});
  }
  var pre = document.createElement('pre');
  pre.id = 'rects';
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
  document.body.className = 'tpl';
})();
</script>"""


def build_html(battery=None, slots=False):
    def sl(name, value, align="left"):
        if not slots:
            return value
        return f'<span data-slot="{name}" data-align="{align}">{value}</span>'

    settings = load_settings()
    metric = settings.get("weather", {}).get("useMetric", True)
    cache = weather_data(settings)
    data = cache.get("data") or {}
    now = datetime.now()
    today = now.date()
    u = "C" if metric else "F"

    cur = (data.get("current_condition") or [{}])[0]
    days = data.get("weather") or []
    t0 = days[0] if days else {}
    hourly = t0.get("hourly") or []
    slot = min(now.hour // 3, max(len(hourly) - 1, 0))
    rain_now = hourly[slot].get("chanceofrain", "0") if hourly else "0"

    desc = (cur.get("weatherDesc") or [{"value": ""}])[0]["value"]
    temps = [int(h.get(f"temp{u}", 0)) for h in hourly] or [0]
    lo, hi = min(temps) - 4, max(temps) + 1
    bars = []
    for i, h in enumerate(hourly):
        t = int(h.get(f"temp{u}", 0))
        px = round(14 + (t - lo) / max(hi - lo, 1) * 70)
        fill = "#000000" if i == slot else "#999999"
        bars.append(f'<div class="bar"><div class="t">{sl(f"bart{i}", f"{t}°", "center")}</div><div class="b" style="height:{px}px;background:{fill}"></div>'
                    f'<div class="l">{int(h.get("time", "0")) // 100:02d}</div></div>')

    astro = (t0.get("astronomy") or [{}])[0]
    rise, sets = clock24(astro.get("sunrise", "")), clock24(astro.get("sunset", ""))
    try:
        span = minutes(sets) - minutes(rise)
        daylight = f"{span // 60} h {span % 60:02d} m light"
    except ValueError:
        daylight = ""

    cards = []
    for n, d in enumerate(days[1:3], start=1):
        name = date.fromisoformat(d["date"]).strftime("%A")
        cards.append(f'<div class="day"><div style="display:flex;flex-direction:column"><div style="font-size:20px;font-weight:600">{sl(f"d{n}name", name)}</div>'
                     f'<div style="font-size:15px;font-weight:500;color:#222222">{sl(f"d{n}desc", html.escape(day_label(d.get("hourly") or [])))}</div></div>'
                     f'<div style="font-size:22px;font-weight:600">{sl(f"d{n}hi", str(d.get(f"maxtemp{u}", "")) + "°", "right")} '
                     f'<span style="color:#444444">{sl(f"d{n}lo", str(d.get(f"mintemp{u}", "")) + "°", "right")}</span></div></div>')

    footer = ""
    hol = next_holiday(today)
    if hol or slots:
        hd, hname = hol or (today, "")
        when = "Today" if hd == today else "Tomorrow" if (hd - today).days == 1 else hd.strftime("%a %-d %b")
        ftag = 'data-slot="footer" data-align="box" ' if slots else ""
        footer = (f'<div {ftag}style="margin-top:auto;display:flex;align-items:center;gap:10px;background:#000000;color:#FFFFFF;border-radius:14px;padding:12px 16px;font-size:18px">'
                  '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="#FFFFFF" stroke-width="2" stroke-linecap="round"><rect x="3" y="5" width="18" height="16" rx="3"></rect><path d="M3 10h18M8 3v4M16 3v4"></path></svg>'
                  f'<div style="font-weight:600;white-space:nowrap">{sl("when", when)}</div><div style="color:#FFFFFF;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">{sl("hname", html.escape(hname) or "Holiday")}</div></div>')

    stamp = f"updated {now:%H:%M}"
    if battery is not None:
        stamp += f" · kindle {battery}%"
    wind = cur.get("windspeedKmph", "0")
    if not metric:
        wind = str(round(int(wind or 0) * 0.621371))

    return PAGE.substitute(
        weekday=sl("weekday", now.strftime("%A")),
        longdate=sl("longdate", now.strftime("%-d %B %Y")),
        place=sl("place", html.escape(cache.get("location") or ""), "right"),
        stamp=sl("stamp", stamp, "right"),
        icon=icon_for(cur.get("weatherCode", ""), desc),
        temp=sl("temp", f"{cur.get(f'temp_{u}', '–')}°"),
        desc=sl("desc", html.escape(summary(desc)), "right"),
        feels=sl("feels", f"feels {cur.get(f'FeelsLike{u}', '–')}°", "right"),
        hilo=sl("hilo", f"↑ {t0.get(f'maxtemp{u}', '–')}°&nbsp;&nbsp;↓ {t0.get(f'mintemp{u}', '–')}°", "right"),
        humidity=sl("humidity", f"{cur.get('humidity', '–')}%"),
        wind=sl("wind", wind),
        windunit=sl("windunit", "km/h" if metric else "mph"),
        uv=sl("uv", cur.get("uvIndex", "–")),
        rain=sl("rain", f"{rain_now}%"),
        bars="".join(bars),
        sunrise=sl("sunrise", rise),
        sunset=sl("sunset", sets),
        daylight=sl("daylight", daylight),
        days="".join(cards),
        footer=footer,
        probe=PROBE if slots else "",
    )

def chrome():
    for name in CHROMES:
        path = shutil.which(name)
        if path:
            return path
    return None


def screenshot(page_html, width, height):
    from PIL import Image
    exe = chrome()
    if not exe:
        raise RuntimeError("no Chrome or Chromium found")
    with tempfile.TemporaryDirectory(prefix="nebula-kindle-") as tmp:
        page = Path(tmp) / "page.html"
        shot = Path(tmp) / "shot.png"
        page.write_text(page_html, encoding="utf-8")
        shoot(exe, page, shot, width, height, tmp)
        return Image.open(shot).convert("L").crop((0, 0, width, height))


def render(out, battery=None):
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    img = snap(screenshot(build_html(battery), WIDTH, HEIGHT))
    tmp_out = out.with_suffix(".tmp.png")
    img.save(tmp_out, optimize=True)
    tmp_out.replace(out)
    return out

ICONS = {"sun": SUN, "moon": MOON, "cloud": CLOUD, "partly": PARTLY, "rain": RAIN, "storm": STORM, "snow": SNOW, "fog": FOG}
KINDLE_DIR = Path(__file__).resolve().parents[2] / "config" / "kindle" / "nebula-dash"


def snap(img):
    return img.convert("L").point(lambda v: round(v / 17) * 17)


def shoot(exe, page, out, width, height, tmp):
    subprocess.run([exe, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--no-first-run",
                    "--no-default-browser-check", "--force-device-scale-factor=1",
                    f"--user-data-dir={tmp}/profile", f"--window-size={width},{height}",
                    "--virtual-time-budget=1500", f"--screenshot={out}", page.as_uri()],
                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)


def font_file(family, weight):
    if "Titan" in family:
        return "TitanOne-Regular"
    w = int(float(weight or 400))
    return "Rubik-Regular" if w < 500 else "Rubik-Medium" if w < 600 else "Rubik-SemiBold"


def hex_color(css):
    nums = [int(float(v)) for v in css[css.find("(") + 1:css.find(")")].split(",")[:3]] if "(" in css else [0, 0, 0]
    g = round(sum(nums) / 3 / 17) * 17
    return f"#{g:02X}{g:02X}{g:02X}"


def build_assets(out_dir):
    import re
    from PIL import Image
    exe = chrome()
    if not exe:
        raise RuntimeError("no Chrome or Chromium found")
    out_dir = Path(out_dir)
    (out_dir / "icons").mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="nebula-kindle-") as tmp:
        page = Path(tmp) / "slots.html"
        page.write_text(build_html(slots=True), encoding="utf-8")
        dom = subprocess.run([exe, "--headless=new", "--disable-gpu", "--no-first-run", "--no-default-browser-check",
                              f"--user-data-dir={tmp}/profile", f"--window-size={WIDTH},{HEIGHT}",
                              "--virtual-time-budget=1500", "--dump-dom", page.as_uri()],
                             check=True, capture_output=True, text=True, timeout=60).stdout
        rects = json.loads(html.unescape(re.search(r'<pre id="rects">(.*?)</pre>', dom, re.S).group(1)))
        shot = Path(tmp) / "template.png"
        shoot(exe, page, shot, WIDTH, HEIGHT, tmp)
        snap(Image.open(shot).crop((0, 0, WIDTH, HEIGHT))).save(out_dir / "template.png", optimize=True)

        icons = Path(tmp) / "icons.html"
        cells = "".join(f'<svg width="118" height="118" viewBox="0 0 48 48" fill="none" stroke="#000000" stroke-width="3" '
                        f'stroke-linecap="round" stroke-linejoin="round" style="display:block;float:left">{svg}</svg>'
                        for svg in ICONS.values())
        icons.write_text(f'<!doctype html><html><body style="margin:0;background:#FFFFFF">{cells}</body></html>', encoding="utf-8")
        ishot = Path(tmp) / "icons.png"
        shoot(exe, icons, ishot, 118 * len(ICONS), 118, tmp)
        strip = Image.open(ishot)
        for i, name in enumerate(ICONS):
            snap(strip.crop((i * 118, 0, i * 118 + 118, 118))).save(out_dir / "icons" / f"{name}.png", optimize=True)

    lines = []
    for r in rects:
        name = r["slot"]
        if name.startswith("col"):
            lines.append(f'C_{name[3:]}="{round(r["x"])} {round(r["y"])} {round(r["w"])}"')
            continue
        align = r.get("align", "left")
        if name == "icon" or align == "box":
            lines.append(f'S_{name}="{round(r["x"])} {round(r["y"])} {round(r["w"])} {round(r["h"])}"')
            continue
        x = r["right"] if align == "right" else r["x"] + r["w"] / 2 if align == "center" else r["x"]
        lines.append(f'S_{name}="{round(x)} {round(r["y"])} {round(r["h"])} {round(r["size"])} '
                     f'{font_file(r["family"], r["weight"])} {hex_color(r["color"])} {align}"')
    lines += ["BAR_BASE=14", "BAR_SPAN=70", "BAR_GAP=6"]
    from nebula import kindle_ac
    rotate = "ccw"
    try:
        for line in (out_dir / "config.sh").read_text().splitlines():
            if line.startswith("ROTATE="):
                rotate = line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    kindle_ac.build(out_dir / "ac", rotate)
    kindle_ac.build_sys(out_dir / "sys", rotate)
    from nebula import kindle_clock
    kindle_clock.build(out_dir / "clock", rotate, weather_data(load_settings()).get("location") or "")
    (out_dir / "layout.sh").write_text("\n".join(lines) + "\n")
    write_place(out_dir / "place.sh")
    return out_dir


def write_place(path):
    from nebula import holidays as h
    settings = load_settings()
    cache = weather_data(settings)
    cc = (settings.get("general", {}).get("holidayCountry") or h.detect_country() or "").upper()
    cid = h.ICS_ALT.get(cc) or f"en.{cc.lower()}"
    metric = settings.get("weather", {}).get("useMetric", True)
    place = (cache.get("location") or "").replace('"', "")
    path.write_text(
        f'PLACE="{place}"\n'
        f'LAT={cache.get("lat", 0)}\n'
        f'LON={cache.get("lon", 0)}\n'
        f'UNITS={"metric" if metric else "imperial"}\n'
        f'ICS="{h.ICS_URL.format(cid=cid)}"\n')

class Handler(BaseHTTPRequestHandler):
    lock = threading.Lock()
    out = OUT_DIR / "dashboard.png"

    def do_GET(self):
        url = urlparse(self.path)
        q = parse_qs(url.query)
        battery = None
        if q.get("battery", [""])[0].isdigit():
            battery = int(q["battery"][0])
        rotate = q.get("rotate", ["ccw"])[0]
        if rotate not in ("cw", "ccw", "none"):
            rotate = "ccw"
        if url.path == "/dashboard.png":
            try:
                with Handler.lock:
                    out = render(Handler.out, battery)
                body = out.read_bytes()
            except Exception as e:
                self.send_error(500, str(e))
                return
            self._send(body, "image/png")
        elif url.path == "/frame.png":
            self._frame(rotate)
        elif url.path == "/dashboard.html":
            self._send(build_html(battery).encode(), "text/html; charset=utf-8")
        else:
            self.send_error(404)

    def _frame(self, rotate):
        from email.utils import formatdate, parsedate_to_datetime
        from nebula import kindle_frame
        with Handler.lock:
            out = kindle_frame.rendered(rotate)
        if not out:
            self.send_error(404)
            return
        mtime = int(kindle_frame.SOURCE.stat().st_mtime)
        since = self.headers.get("If-Modified-Since")
        try:
            if since and parsedate_to_datetime(since).timestamp() >= mtime - 2:
                self.send_response(304)
                self.end_headers()
                return
        except (TypeError, ValueError):
            pass
        body = out.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "image/png")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Last-Modified", formatdate(mtime, usegmt=True))
        self.end_headers()
        self.wfile.write(body)

    def _send(self, body, ctype):
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"{datetime.now():%H:%M:%S} {self.client_address[0]} {fmt % args}\n")


def main():
    p = argparse.ArgumentParser(prog="nebula kindle", description="Kindle e-ink dashboard")
    sub = p.add_subparsers(dest="action", required=True)
    r = sub.add_parser("render", help="render the dashboard PNG once")
    r.add_argument("--out", default=str(OUT_DIR / "dashboard.png"))
    r.add_argument("--html", action="store_true", help="print the HTML instead")
    g = sub.add_parser("assets", help="build the on-device template, icons and layout")
    g.add_argument("--out", default=None)
    f = sub.add_parser("frame", help="set the still image shown while the Kindle rests")
    f.add_argument("image", nargs="?", help="any image file; omit to only change --fit")
    f.add_argument("--fit", choices=("cover", "contain"), default=None)
    f.add_argument("--clear", action="store_true")
    f.add_argument("--push", action="store_true", help="also copy it over USB if the Kindle is plugged in")
    sub.add_parser("push", help="copy the frame image to a USB-connected Kindle")
    sub.add_parser("status", help="print frame, USB and server state as JSON")
    w = sub.add_parser("wifi", help="run the frame server in the background (systemd user unit)")
    w.add_argument("state", choices=("on", "off"))
    s = sub.add_parser("serve", help="serve a freshly rendered PNG on every request")
    s.add_argument("--port", type=int, default=8777)
    s.add_argument("--bind", default="0.0.0.0")
    a = p.parse_args()

    if a.action == "assets":
        print(build_assets(a.out or KINDLE_DIR))
        return 0

    if a.action in ("frame", "push", "status", "wifi"):
        import json
        from nebula import kindle_frame as kf
        result = {}
        if a.action == "frame":
            if a.clear:
                kf.clear()
            elif a.image:
                kf.set_image(a.image, a.fit or "cover")
            elif a.fit:
                kf.set_fit(a.fit)
            else:
                p.error("frame needs an image, --fit or --clear")
        if a.action == "push" or (a.action == "frame" and a.push and not a.clear):
            ok, msg = kf.push()
            result = {"ok": ok, "message": msg}
        if a.action == "wifi":
            kf.wifi(a.state == "on")
        print(json.dumps({**kf.status(), **result}))
        return 0

    if a.action == "render":
        if a.html:
            sys.stdout.write(build_html())
            return 0
        print(render(a.out))
        return 0

    server = ThreadingHTTPServer((a.bind, a.port), Handler)
    print(f"serving http://{a.bind}:{a.port}/dashboard.png", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
