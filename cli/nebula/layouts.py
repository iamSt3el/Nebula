import json
import os
import re
import shutil
import sys
import tempfile
from datetime import datetime
from pathlib import Path

from nebula.paths import HOME, SETTINGS

DIR = Path(os.environ.get("XDG_CONFIG_HOME", HOME / ".config")) / "nebula" / "layouts"
PREVIOUS = DIR / ".previous.json"
ACTIVE = DIR / ".active"
FORMAT = 1

SECTIONS = ["bar", "widgets", "dashboard", "panels", "lockscreen"]
LABELS = {"bar": "Bar and dock", "widgets": "Desktop widgets", "dashboard": "Dashboard",
          "panels": "Panel styles", "lockscreen": "Lock screen"}

WIDGET_DATA = {"countdowns", "stickyNoteText"}
DOCK_KEYS = ["dock", "dockAutoHide", "dockMusicPlayer", "dockSdf"]
PANEL_PREFIXES = ("launcher", "notes")
PANEL_KEYS = ["clipboardStyle", "notifPopupStyle", "barWeatherPanel"]


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
    return out


def summary(sections: dict) -> dict:
    info = {}
    bar = (sections.get("bar") or {}).get("bar") or {}
    if bar:
        blocks = bar.get("blocks") or []
        if bar.get("edgeVersion") == 2:
            used = {b.get("edge", "top") for b in blocks if isinstance(b, dict) and b.get("items")}
        else:
            bar_side = bar.get("side", "top")
            dock_side = (bar.get("dock") or {}).get("side", "bottom")
            used = {bar_side if b.get("edge", "top") != "bottom" else dock_side
                    for b in blocks if isinstance(b, dict) and b.get("items")}
        info["barSide"] = " + ".join(s for s in ("top", "right", "bottom", "left") if s in used) or "top"
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


def _tracked(sections: dict) -> dict:
    return {k: v for k, v in sections.items() if k in SECTIONS}


def _differs(sections: dict, now=None) -> bool:
    sections = _tracked(sections)
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
    sections = capture(list(_tracked(doc["sections"]).keys()))
    if not sections:
        print("[nebula] nothing to save", file=sys.stderr)
        return 1
    _atomic_json(path, _doc(doc.get("name", path.stem), sections))
    _set_active(path.stem)
    print(str(path))
    return 0


def _patch(sections: dict, want: set) -> tuple:
    patch = {}
    general = {}
    applied = []
    if "bar" in want and "bar" in sections:
        if "bar" in sections["bar"]:
            patch["bar"] = sections["bar"]["bar"]
        general.update(sections["bar"].get("general") or {})
        applied.append("bar")
    if "widgets" in want and "widgets" in sections:
        patch["widgets"] = sections["widgets"]
        applied.append("widgets")
    for key in ("dashboard", "lockscreen"):
        if key in want and key in sections:
            patch[key] = sections[key]
            applied.append(key)
    if "panels" in want and "panels" in sections:
        general.update(sections["panels"])
        applied.append("panels")
    if general:
        patch["general"] = general
    return patch, applied


def apply_sections(sections: dict, only=None, emit=False) -> list:
    want = set(only or SECTIONS)
    patch, applied = _patch(sections, want)
    if emit:
        print(json.dumps({"apply": patch, "sections": applied}), flush=True)
    else:
        s = _read_settings()
        for key, value in patch.items():
            if key == "general":
                s.setdefault("general", {}).update(value)
            elif key == "widgets":
                cur = s.get("widgets") or {}
                s["widgets"] = {**value, **{k: v for k, v in cur.items() if k in WIDGET_DATA}}
            else:
                s[key] = value
        _write_settings(s)
    return applied


def load(ref: str, only=None, emit=False) -> int:
    path = _resolve(ref)
    if not path.is_file():
        print(f"[nebula] no layout '{ref}'", file=sys.stderr)
        return 1
    try:
        doc = _load_doc(path)
    except Exception as e:
        print(f"[nebula] {e}", file=sys.stderr)
        return 1
    touched = [k for k in _tracked(doc["sections"]) if not only or k in only]
    before = _doc("Before " + doc.get("name", path.stem), capture(touched))
    before["active"] = _get_active()
    _atomic_json(PREVIOUS, before)
    applied = apply_sections(doc["sections"], only, emit)
    _set_active(path.stem if path.parent == DIR else None)
    print(json.dumps({"loaded": doc.get("name", path.stem), "sections": applied}))
    return 0


def undo(emit=False) -> int:
    if not PREVIOUS.is_file():
        print("[nebula] nothing to undo", file=sys.stderr)
        return 1
    doc = _load_doc(PREVIOUS)
    applied = apply_sections(doc["sections"], emit=emit)
    PREVIOUS.unlink()
    _set_active(doc.get("active"))
    print(json.dumps({"restored": doc.get("name", ""), "sections": applied}))
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
                         "saved": doc.get("saved", ""), "sections": list(_tracked(doc["sections"]).keys()),
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
