import json
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from nebula.paths import COLORS, HOME, SETTINGS

DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "nebula" / "layouts"
PREVIOUS = DIR / ".previous.json"
ACTIVE = DIR / ".active"
FORMAT = 1

SECTIONS = ["bar", "widgets", "dashboard", "panels", "lockscreen", "look"]
LABELS = {"bar": "Bar and dock", "widgets": "Desktop widgets", "dashboard": "Dashboard",
          "panels": "Panel styles", "lockscreen": "Lock screen", "look": "Wallpaper and colours"}

WIDGET_DATA = {"habits", "countdowns", "moods", "stickyNoteText", "notebookVault"}
DOCK_KEYS = ["dock", "dockAutoHide", "dockMusicPlayer", "dockSdf"]
PANEL_PREFIXES = ("launcher", "notes")
PANEL_KEYS = ["clipboardStyle", "notifPopupStyle", "wallpaperStyle", "barWeatherPanel"]


def slug(name: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", name.strip().lower()).strip("-")
    return s or "layout"


def _read_settings() -> dict:
    try:
        return json.loads(SETTINGS.read_text())
    except Exception:
        return {}


def _write_settings(data: dict) -> None:
    text = json.dumps(data, indent=4)
    SETTINGS.parent.mkdir(parents=True, exist_ok=True)
    mode = "r+" if SETTINGS.exists() else "w"
    with open(SETTINGS, mode) as f:
        f.seek(0)
        f.write(text)
        f.truncate()


def _panel_keys(general: dict) -> dict:
    return {k: v for k, v in general.items() if k.startswith(PANEL_PREFIXES) or k in PANEL_KEYS}


def capture(only=None) -> dict:
    s = _read_settings()
    g = s.get("general") or {}
    want = set(only or SECTIONS)
    out = {}
    if "bar" in want and "bar" in s:
        out["bar"] = {"bar": s["bar"], "general": {k: g[k] for k in DOCK_KEYS if k in g}}
    if "widgets" in want and "widgets" in s:
        out["widgets"] = {k: v for k, v in s["widgets"].items() if k not in WIDGET_DATA}
    if "dashboard" in want and "dashboard" in s:
        out["dashboard"] = s["dashboard"]
    if "panels" in want:
        out["panels"] = _panel_keys(g)
    if "lockscreen" in want and "lockscreen" in s:
        out["lockscreen"] = s["lockscreen"]
    if "look" in want:
        try:
            colors = json.loads(COLORS.read_text())
        except Exception:
            colors = {}
        t = s.get("theme") or {}
        wp = colors.get("sourceWallpaper") or colors.get("wallpaper") or ""
        if wp:
            out["look"] = {"wallpaper": wp,
                           "scheme": t.get("matugenScheme", "scheme-content"),
                           "mode": t.get("matugenTheme", "dark")}
    return out


def summary(sections: dict) -> dict:
    info = {}
    bar = (sections.get("bar") or {}).get("bar") or {}
    if bar:
        blocks = bar.get("blocks") or []
        info["barSide"] = bar.get("side", "top")
        info["barItems"] = sum(len(b.get("items") or []) for b in blocks if isinstance(b, dict))
    w = sections.get("widgets")
    if w is not None:
        info["widgets"] = sum(1 for k, v in w.items() if k.startswith("show") and k != "showWidgets" and v is True)
    d = sections.get("dashboard")
    if d is not None:
        info["dashboardItems"] = len(d.get("items") or [])
    p = sections.get("panels")
    if p is not None:
        info["launcherStyle"] = p.get("launcherStyle", "")
        info["clipboardStyle"] = p.get("clipboardStyle", "")
        info["notifStyle"] = p.get("notifPopupStyle", "")
    ls = sections.get("lockscreen")
    if ls is not None:
        info["lockLayout"] = ls.get("layout", "")
    look = sections.get("look")
    if look:
        info["wallpaper"] = look.get("wallpaper", "")
        info["mode"] = look.get("mode", "")
    return info


def _doc(name: str, sections: dict) -> dict:
    return {"nebulaLayout": FORMAT, "name": name, "saved": datetime.now().isoformat(timespec="seconds"),
            "sections": sections}


def _atomic_json(path: Path, obj: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix=".tmp")
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, indent=2)
    os.replace(tmp, path)


def _resolve(ref: str) -> Path:
    p = Path(ref).expanduser()
    if p.suffix == ".json" and p.is_file():
        return p
    return DIR / f"{slug(ref)}.json"


def _load_doc(path: Path) -> dict:
    doc = json.loads(path.read_text())
    if not isinstance(doc, dict) or not isinstance(doc.get("sections"), dict):
        raise ValueError(f"{path.name} is not a Nebula layout")
    if int(doc.get("nebulaLayout", 0)) > FORMAT:
        raise ValueError(f"{path.name} was made by a newer Nebula")
    return doc


def _get_active():
    try:
        ref = ACTIVE.read_text().strip()
    except Exception:
        return None
    return ref if ref and (DIR / f"{ref}.json").is_file() else None


def _set_active(ref) -> None:
    if ref:
        DIR.mkdir(parents=True, exist_ok=True)
        ACTIVE.write_text(ref)
    elif ACTIVE.exists():
        ACTIVE.unlink()


def _covers(now, saved) -> bool:
    if isinstance(saved, dict):
        return isinstance(now, dict) and all(k in now and _covers(now[k], v) for k, v in saved.items())
    return now == saved


def _differs(sections: dict, now=None) -> bool:
    now = now if now is not None else capture(list(sections.keys()))
    return any(not _covers(now.get(k), v) for k, v in sections.items())


def save(name: str, only=None) -> int:
    sections = capture(only)
    if not sections:
        print("[nebula] nothing to save", file=sys.stderr)
        return 1
    path = DIR / f"{slug(name)}.json"
    _atomic_json(path, _doc(name.strip() or "Layout", sections))
    _set_active(path.stem)
    print(str(path))
    return 0


def update(ref: str) -> int:
    path = _resolve(ref)
    if path.parent != DIR or not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    try:
        doc = _load_doc(path)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    sections = capture(list(doc["sections"].keys()))
    if not sections:
        print("[nebula] nothing to save", file=sys.stderr)
        return 1
    _atomic_json(path, _doc(doc.get("name", path.stem), sections))
    _set_active(path.stem)
    print(str(path))
    return 0


def apply_sections(sections: dict, only=None) -> list:
    want = set(only or SECTIONS)
    s = _read_settings()
    applied = []
    if "bar" in want and "bar" in sections:
        s["bar"] = sections["bar"].get("bar", s.get("bar"))
        s.setdefault("general", {}).update(sections["bar"].get("general") or {})
        applied.append("bar")
    if "widgets" in want and "widgets" in sections:
        cur = s.get("widgets") or {}
        keep = {k: v for k, v in cur.items() if k in WIDGET_DATA}
        s["widgets"] = {**sections["widgets"], **keep}
        applied.append("widgets")
    if "dashboard" in want and "dashboard" in sections:
        s["dashboard"] = sections["dashboard"]
        applied.append("dashboard")
    if "panels" in want and "panels" in sections:
        s.setdefault("general", {}).update(sections["panels"])
        applied.append("panels")
    if "lockscreen" in want and "lockscreen" in sections:
        s["lockscreen"] = sections["lockscreen"]
        applied.append("lockscreen")
    _write_settings(s)
    look = sections.get("look")
    if "look" in want and look and os.path.isfile(look.get("wallpaper", "")):
        from nebula import wallpaper
        wallpaper.apply(look["wallpaper"], look.get("scheme", "scheme-content"), look.get("mode", "dark"))
        applied.append("look")
    return applied


def load(ref: str, only=None) -> int:
    path = _resolve(ref)
    if not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    try:
        doc = _load_doc(path)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    touched = [k for k in doc["sections"] if not only or k in only]
    before = _doc("Before " + doc.get("name", path.stem), capture(touched))
    before["active"] = _get_active()
    _atomic_json(PREVIOUS, before)
    applied = apply_sections(doc["sections"], only)
    _set_active(path.stem if path.parent == DIR else None)
    print(json.dumps({"loaded": doc.get("name", path.stem), "sections": applied}))
    return 0


def undo() -> int:
    if not PREVIOUS.is_file():
        print("[nebula] nothing to undo", file=sys.stderr)
        return 1
    doc = _load_doc(PREVIOUS)
    apply_sections(doc["sections"])
    PREVIOUS.unlink()
    _set_active(doc.get("active"))
    print(json.dumps({"restored": doc.get("name", "")}))
    return 0


def delete(ref: str) -> int:
    path = _resolve(ref)
    if path.parent != DIR or not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    path.unlink()
    if _get_active() is None:
        _set_active(None)
    return 0


def import_file(src: str, name=None) -> int:
    p = Path(src).expanduser()
    try:
        doc = _load_doc(p)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    if name:
        doc["name"] = name
    dest = DIR / f"{slug(doc.get('name') or p.stem)}.json"
    _atomic_json(dest, doc)
    print(str(dest))
    return 0


def export(ref: str, dest: str) -> int:
    path = _resolve(ref)
    if not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    out = Path(dest).expanduser()
    if out.is_dir():
        out = out / path.name
    shutil.copyfile(path, out)
    print(str(out))
    return 0


def entries() -> list:
    rows = []
    active = _get_active()
    now = capture()
    docs = {}
    if DIR.is_dir():
        for p in sorted(DIR.glob("*.json")):
            if p.name.startswith("."):
                continue
            try:
                doc = _load_doc(p)
            except Exception:
                continue
            docs[p.stem] = doc
            rows.append({"id": p.stem, "name": doc.get("name", p.stem), "file": str(p),
                         "saved": doc.get("saved", ""), "sections": list(doc["sections"].keys()),
                         "current": p.stem == active,
                         "modified": p.stem == active and _differs(doc["sections"], now),
                         **summary(doc["sections"])})
    rows.sort(key=lambda r: r["saved"], reverse=True)
    if active is None:
        for r in rows:
            if not _differs(docs[r["id"]]["sections"], now):
                r["current"] = True
                break
    return rows


def print_list(as_json: bool) -> int:
    rows = entries()
    if as_json:
        current = next((r["id"] for r in rows if r["current"]), "")
        print(json.dumps({"dir": str(DIR), "canUndo": PREVIOUS.is_file(), "active": current, "layouts": rows}))
        return 0
    if not rows:
        print(f"No layouts yet. Save one with `nebula layout save <name>` ({DIR})")
        return 0
    for r in rows:
        parts = [LABELS[s] for s in r["sections"] if s in LABELS]
        mark = "*" if r["current"] else " "
        print(f"{mark} {r['name']:<24} {r['saved'][:16].replace('T', ' ')}   {', '.join(parts)}")
    return 0
