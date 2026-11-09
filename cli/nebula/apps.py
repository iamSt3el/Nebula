#!/usr/bin/env python3
import hashlib
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from nebula.paths import SETTINGS, STATE_DIR

HOME = Path.home()
TEMPLATES = HOME / ".config" / "matugen" / "templates"
MANIFEST = STATE_DIR / "theme-apps-written.json"

TMUX_HOOK = (
    'L="$HOME/.tmux.conf.local"; C="$HOME/.config/tmux/colors.conf"; '
    '{ sed "/^# >>> m3 palette >>>$/q" "$L"; cat "$C"; '
    r'sed -n "/^# <<< m3 palette <<<$/,\$p" "$L"; } > "$L.new" '
    '&& cat "$L.new" > "$L" && rm -f "$L.new"; '
    'for s in "${TMUX_TMPDIR:-/tmp}"/tmux-$(id -u)/*; do '
    '[ -S "$s" ] && tmux -S "$s" source-file "$HOME/.tmux.conf"; '
    'done'
)

GTK3_HOOK = ('gsettings set org.gnome.desktop.interface gtk-theme "" && '
             'gsettings set org.gnome.desktop.interface gtk-theme '
             '"adw-gtk3$([ "${NEBULA_MODE:-dark}" = dark ] && echo -dark)"')

HYPR_HOOK = (
    'F="$HOME/.config/hypr/lua/colors.lua"; '
    r"""a=$(sed -n 's/^M\.active_border *= *"\(.*\)".*/\1/p' "$F"); """
    r"""i=$(sed -n 's/^M\.inactive_border *= *"\(.*\)".*/\1/p' "$F"); """
    '[ -n "$a" ] && [ -n "$i" ] && hyprctl eval '
    r'''"hl.config({ general = { col = { active_border = \"$a\", inactive_border = \"$i\" } } })"'''
)

PAPIRUS_DIRS = [
    Path("/usr/share/icons/Papirus"),
    Path("/usr/share/icons/Papirus-Dark"),
    Path("/usr/share/icons/Papirus-Light"),
    HOME / ".local/share/icons/Papirus",
    HOME / ".icons/Papirus",
]

LIB_DIRS = [Path("/usr/lib"), Path("/usr/lib64"), Path("/usr/lib/x86_64-linux-gnu")]

APPS = [
    {"id": "kitty", "name": "kitty", "group": "terminal", "bins": ["kitty"],
     "files": [{"input": "kitty-colors.conf", "output": ".config/kitty/colors.conf"}]},
    {"id": "tmux", "name": "tmux", "group": "terminal", "bins": ["tmux"],
     "files": [{"input": "tmux-colors.conf", "output": ".config/tmux/colors.conf"}],
     "hook": TMUX_HOOK, "note": "~/.tmux.conf.local palette block"},
    {"id": "starship", "name": "Starship", "group": "terminal", "bins": ["starship"], "whole": True,
     "files": [{"input": "starship.toml", "output": ".config/starship.toml"}]},
    {"id": "btop", "name": "btop", "group": "terminal", "bins": ["btop"],
     "files": [{"input": "btop.theme", "output": ".config/btop/themes/matugen.theme"}]},
    {"id": "hyprland", "name": "Hyprland borders", "group": "desktop", "bins": ["hyprctl", "Hyprland"],
     "files": [{"input": "hyprland-colors.conf", "output": ".config/hypr/colors.conf"},
               {"input": "hyprland-colors.lua", "output": ".config/hypr/lua/colors.lua", "needs": ".config/hypr/lua"}],
     "hook": HYPR_HOOK},
    {"id": "gtk3", "name": "GTK 3", "group": "desktop", "libs": ["libgtk-3.so.0"], "whole": True,
     "files": [{"input": "gtk-colors.css", "output": ".config/gtk-3.0/gtk.css"}], "hook": GTK3_HOOK},
    {"id": "gtk4", "name": "GTK 4", "group": "desktop", "libs": ["libgtk-4.so.1"], "whole": True,
     "files": [{"input": "gtk4-colors.css", "output": ".config/gtk-4.0/gtk.css"}]},
    {"id": "qt", "name": "Qt5ct and Qt6ct", "group": "desktop", "bins": ["qt6ct", "qt5ct"],
     "files": [{"input": "qt-colors.conf", "output": ".config/qt6ct/colors/matugen.conf", "bins": ["qt6ct"]},
               {"input": "qt-colors.conf", "output": ".config/qt5ct/colors/matugen.conf", "bins": ["qt5ct"]}]},
    {"id": "papirus", "name": "Papirus folders", "group": "desktop", "bins": ["papirus-folders"],
     "papirus": True, "note": "folder colour nearest to primary"},
    {"id": "firefox", "name": "Firefox and Zen", "group": "apps", "bins": ["pywalfox"],
     "browsers": ["firefox", "zen-browser", "zen", "librewolf", "floorp"],
     "files": [{"input": "pywalfox-colors.json", "output": ".cache/wal/colors.json"}],
     "hook": 'pywalfox update && pywalfox "${NEBULA_MODE:-dark}"', "note": "through the Pywalfox add-on"},
    {"id": "obsidian", "name": "Obsidian", "group": "apps", "bins": ["obsidian"], "vaults": True,
     "files": [{"input": "obsidian.css", "output": ".obsidian/themes/Matugen/theme.css"}]},
    {"id": "waybar", "name": "Waybar", "group": "apps", "bins": ["waybar"],
     "files": [{"input": "colors.css", "output": ".config/waybar/colors.css"}]},
    {"id": "nwgdock", "name": "nwg-dock", "group": "apps", "bins": ["nwg-dock-hyprland"],
     "files": [{"input": "colors.css", "output": ".config/nwg-dock-hyprland/colors.css"}]},
]

BY_ID = {a["id"]: a for a in APPS}


def pretty(path) -> str:
    s = str(path)
    h = str(HOME)
    return "~" + s[len(h):] if s.startswith(h + "/") else s


def which(names):
    for n in names or []:
        p = shutil.which(n)
        if p:
            return p
    return ""


def find_lib(names):
    for n in names or []:
        for d in LIB_DIRS:
            if (d / n).exists():
                return str(d / n)
    return ""


def obsidian_vaults():
    cfg = HOME / ".config" / "obsidian" / "obsidian.json"
    try:
        vaults = json.loads(cfg.read_text()).get("vaults", {})
    except Exception:
        return []
    out = []
    for v in vaults.values():
        p = Path(v.get("path", ""))
        if p.is_dir() and (p / ".obsidian").is_dir():
            out.append(p)
    return out


def targets(app):
    out = []
    for f in app.get("files", []):
        if f.get("bins") and not which(f["bins"]):
            continue
        if f.get("needs") and not (HOME / f["needs"]).is_dir():
            continue
        if app.get("vaults"):
            for v in obsidian_vaults():
                out.append((TEMPLATES / f["input"], v / f["output"]))
        else:
            out.append((TEMPLATES / f["input"], HOME / f["output"]))
    return out


def enabled_ids():
    try:
        theme = json.loads(SETTINGS.read_text()).get("theme", {})
    except Exception:
        return None
    ids = theme.get("themeApps")
    return set(ids) if isinstance(ids, list) else None


def parse_ids(arg: str):
    return {s for s in arg.split(",") if s} if arg is not None else None


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_manifest() -> dict:
    try:
        return json.loads(MANIFEST.read_text())
    except Exception:
        return {}


def save_manifest(m: dict) -> None:
    try:
        MANIFEST.parent.mkdir(parents=True, exist_ok=True)
        tmp = MANIFEST.with_suffix(".tmp")
        tmp.write_text(json.dumps(m, indent=1))
        os.replace(tmp, MANIFEST)
    except Exception as e:
        print(f"[theme_apps] manifest ERROR: {e}", file=sys.stderr)


def is_nix_managed(path: Path) -> bool:
    prefixes = ["/nix/store"]
    env_prefix = os.environ.get("NEBULA_STORE_PREFIX")
    if env_prefix:
        prefixes.append(env_prefix.rstrip("/"))

    def _matches(p_str: str) -> bool:
        return any(p_str == pref or p_str.startswith(pref + "/") for pref in prefixes)

    p_str = os.fspath(path)
    if _matches(p_str):
        return True

    try:
        if _matches(os.path.realpath(p_str)):
            return True
    except OSError:
        pass

    try:
        if os.path.islink(p_str) and _matches(os.readlink(p_str)):
            return True
    except OSError:
        pass

    try:
        parent = path.parent
        if _matches(os.fspath(parent)) or _matches(os.path.realpath(os.fspath(parent))):
            return True
    except OSError:
        pass

    return False


def target_state(path: Path | str) -> str:
    path = Path(path)
    if is_nix_managed(path):
        return "nix-managed"

    p_str = os.fspath(path)
    if os.path.islink(p_str):
        return "symlink"

    parent = path.parent
    if not parent.exists() or not os.access(parent, os.W_OK):
        return "missing-parent"

    if os.path.lexists(p_str):
        if not os.access(p_str, os.W_OK):
            return "readonly"

    return "ok"


def atomic_write(path: Path, content: str) -> None:
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


def is_user_file(path: Path, manifest: dict) -> bool:
    if target_state(path) != "ok":
        return False
    if path.is_symlink():
        return True
    if not path.is_file():
        return False
    try:
        return manifest.get(str(path)) != _sha(path.read_bytes())
    except Exception:
        return True


def _free_backup(path: Path) -> Path:
    bak = path.with_name(path.name + ".bak")
    n = 1
    while bak.exists() or bak.is_symlink():
        bak = path.with_name(f"{path.name}.bak.{n}")
        n += 1
    return bak


def backup_if_user_file(app, path: Path, manifest: dict) -> bool:
    if not app.get("whole") or target_state(path) != "ok" or not is_user_file(path, manifest):
        return False
    shutil.copy2(path, _free_backup(path), follow_symlinks=True)
    return True


def render(app, output_path: Path, content: str, manifest):
    state = target_state(output_path)
    if state != "ok":
        return {"status": "skipped", "reason": state}
    backed_up = bool(backup_if_user_file(app, output_path, manifest))
    atomic_write(output_path, content)
    record(output_path, content, manifest)
    return {"status": "ok", "backed_up": backed_up}


def record(path: Path, content: str, manifest: dict) -> None:
    manifest[str(path)] = _sha(content.encode())


def locate(app) -> str:
    return find_lib(app.get("libs")) if app.get("libs") else which(app.get("bins"))


def is_installed(app) -> bool:
    if not locate(app):
        return False
    if app.get("papirus"):
        return any(p.exists() for p in PAPIRUS_DIRS)
    if app.get("vaults"):
        return bool(obsidian_vaults())
    return True


def detect_one(app, manifest):
    found = locate(app)
    hint = ""
    installed = bool(found)
    if app.get("papirus"):
        installed = installed and any(p.exists() for p in PAPIRUS_DIRS)
        if not found and any(p.exists() for p in PAPIRUS_DIRS):
            hint = "Install papirus-folders"
    if app["id"] == "firefox" and not installed and which(app["browsers"]):
        hint = "Install python-pywalfox and its browser add-on"
    tg = targets(app) if installed else []
    if app.get("vaults") and installed and not tg:
        installed = False
        hint = "No Obsidian vault found"
    paths = [t[1] for t in tg]
    note = app.get("note") or (pretty(paths[0]) if len(paths) == 1 else
                               f"{len(paths)} vaults" if app.get("vaults") and paths else
                               ", ".join(pretty(p) for p in paths))
    skipped = [f"{p.name}: {target_state(p)}, skipped" for p in paths if target_state(p) != "ok"]
    return {
        "id": app["id"],
        "name": app["name"],
        "group": app["group"],
        "installed": installed,
        "found": found,
        "hint": hint,
        "note": note,
        "targets": [pretty(p) for p in paths],
        "skipped": skipped,
        "replacesFile": bool(app.get("whole")) and any(is_user_file(p, manifest) and target_state(p) == "ok" for p in paths),
    }


def detect():
    manifest = load_manifest()
    return [detect_one(a, manifest) for a in APPS]


def picked_ids(detected=None):
    saved = enabled_ids()
    if saved is not None:
        return saved
    detected = detected if detected is not None else detect()
    return {a["id"] for a in detected if a["installed"]}


def _save(ids) -> None:
    from nebula import settings
    order = [a["id"] for a in APPS]
    settings.update("theme", {"themeApps": sorted(ids, key=lambda i: order.index(i) if i in order else 99)})


def _apply_now() -> int:
    import subprocess
    return subprocess.run([sys.executable, "-m", "nebula", "scheme", "apply"]).returncode


def print_list(as_json: bool) -> int:
    detected = detect()
    picked = picked_ids(detected)
    if as_json:
        print(json.dumps([dict(a, picked=a["id"] in picked) for a in detected]))
        return 0
    auto = enabled_ids() is None
    tty = sys.stdout.isatty()
    on = "\033[32m●\033[0m" if tty else "on "
    off = "\033[2m○\033[0m" if tty else "off"
    groups = {"terminal": "Terminal and shell", "desktop": "Desktop", "apps": "Apps"}
    for g, title in groups.items():
        print(title)
        for a in detected:
            if a["group"] != g:
                continue
            mark = (on if a["id"] in picked else off) if a["installed"] else " - "
            extra = str(a["note"] if a["installed"] else (a["hint"] or "not installed"))
            skipped = a.get("skipped")
            if a["installed"] and isinstance(skipped, list) and skipped:
                extra += f"  ({', '.join(skipped)})"
            elif a["installed"] and a.get("replacesFile"):
                extra += "  (replaces your file, keeps a .bak)"
            print(f"  {mark} {a['id']:<10} {a['name']:<18} {extra}")
    targets_list = [a.get("targets") for a in detected if a["installed"]]
    skipped_list = [a.get("skipped") for a in detected if a["installed"]]
    total_targets = sum(len(t) for t in targets_list if isinstance(t, list))
    total_skipped = sum(len(s) for s in skipped_list if isinstance(s, list))
    if total_targets > 0 and total_skipped == total_targets:
        print(f"\n{total_skipped} file{'s' if total_skipped != 1 else ''} managed by your system config, port palette values there manually.")
    elif auto:
        print("\nNo choice saved yet: every detected app is themed. `nebula apps disable <id>` to opt out.")
    return 0


def set_picked(ids, on: bool, apply_now: bool) -> int:
    unknown = [i for i in ids if i not in BY_ID]
    if unknown:
        print(f"nebula: unknown app id: {', '.join(unknown)}. See `nebula apps`.", file=sys.stderr)
        return 2
    picked = set(picked_ids())
    picked = picked | set(ids) if on else picked - set(ids)
    _save(picked)
    print(("Enabled " if on else "Disabled ") + ", ".join(BY_ID[i]["name"] for i in ids))
    return _apply_now() if apply_now else 0


def reset(apply_now: bool) -> int:
    from nebula import settings
    settings.update("theme", {"themeApps": None})
    print("Every detected app follows the palette again.")
    return _apply_now() if apply_now else 0


def main():
    print(json.dumps(detect()))
    return 0
