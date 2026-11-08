import os
import pwd
import shutil
import subprocess
from pathlib import Path

HOME = Path.home()
PACKAGE_DIR = Path(__file__).resolve().parent
SHELL_DIR = PACKAGE_DIR.parents[1]
SH_DIR = PACKAGE_DIR / "sh"
CACHE_DIR = HOME / ".cache" / "quickshell"
CONFIG_DIR = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "nebula"
STATE_DIR = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "nebula"
SETTINGS = CONFIG_DIR / "settings.json"
COLORS = CACHE_DIR / "colors.json"


def dropin_dirs() -> list[Path]:
    raw = os.environ.get("XDG_CONFIG_DIRS") or "/etc/xdg"
    return [Path(p.strip()) for p in raw.split(":") if p.strip()]


def dropin_files() -> list[Path]:
    files: list[Path] = []
    seen: set[Path] = set()

    for d in reversed(dropin_dirs()):
        nebula_dir = d / "nebula"
        if nebula_dir.is_dir():
            for p in sorted(nebula_dir.glob("*.json")):
                resolved = p.resolve()
                if resolved not in seen and p.is_file():
                    seen.add(resolved)
                    files.append(p)

    etc_nebula = Path("/etc/nebula")
    if etc_nebula.is_dir():
        for p in sorted(etc_nebula.glob("*.json")):
            resolved = p.resolve()
            if resolved not in seen and p.is_file():
                seen.add(resolved)
                files.append(p)
    elif Path("/etc/nebula/config.json").is_file():
        p = Path("/etc/nebula/config.json")
        resolved = p.resolve()
        if resolved not in seen:
            seen.add(resolved)
            files.append(p)

    user_dropins = CONFIG_DIR / "settings.d"
    if user_dropins.is_dir():
        for p in sorted(user_dropins.glob("*.json")):
            resolved = p.resolve()
            if resolved not in seen and p.is_file():
                seen.add(resolved)
                files.append(p)

    defaults_file = CONFIG_DIR / "defaults.json"
    if defaults_file.is_file():
        resolved = defaults_file.resolve()
        if resolved not in seen:
            seen.add(resolved)
            files.append(defaults_file)

    return files

MOVED = [
    (CACHE_DIR / "settings.json", SETTINGS),
    (CACHE_DIR / "notes.json", CONFIG_DIR / "notes.json"),
    (CACHE_DIR / "scenes.json", CONFIG_DIR / "scenes.json"),
    (SHELL_DIR / "favorites.json", CONFIG_DIR / "favorites.json"),
    (CACHE_DIR / "app-usage.json", STATE_DIR / "app-usage.json"),
    (CACHE_DIR / "theme-apps-written.json", STATE_DIR / "theme-apps-written.json"),
    (CACHE_DIR / "books" / "shelf.json", STATE_DIR / "books-shelf.json"),
    (CACHE_DIR / "screentime", STATE_DIR / "screentime"),
]


def _greeter_reads(path: Path) -> bool:
    if not shutil.which("getfacl"):
        return False
    try:
        pwd.getpwnam("greeter")
        r = subprocess.run(["getfacl", "-p", str(path)], capture_output=True, text=True, timeout=5)
    except (KeyError, OSError, subprocess.SubprocessError):
        return False
    return "user:greeter:" in r.stdout


def _share_with_greeter() -> None:
    for args in (["-m", "u:greeter:rx"], ["-d", "-m", "u:greeter:r"]):
        subprocess.run(["setfacl", *args, str(CONFIG_DIR)], capture_output=True, timeout=5)
    if SETTINGS.exists():
        subprocess.run(["setfacl", "-m", "u:greeter:r", str(SETTINGS)], capture_output=True, timeout=5)


def migrate() -> list[tuple[Path, Path]]:
    moved = []
    for d in (CONFIG_DIR, STATE_DIR):
        try:
            d.mkdir(parents=True, exist_ok=True)
        except OSError:
            pass
    for src, dst in MOVED:
        if not src.exists() or dst.exists():
            continue
        try:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(src), str(dst))
        except OSError:
            continue
        moved.append((src, dst))
    if any(dst == SETTINGS for _, dst in moved) and _greeter_reads(CACHE_DIR):
        try:
            _share_with_greeter()
        except (OSError, subprocess.SubprocessError):
            pass
    return moved
