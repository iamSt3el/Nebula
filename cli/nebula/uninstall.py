import os
import re
import shutil
import sys
from pathlib import Path

from nebula import hypr
from nebula.paths import CONFIG_DIR, HOME, SHELL_DIR, STATE_DIR

CACHE_DIR = Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache") / "quickshell"
VENV_DIR = Path(os.environ.get("XDG_STATE_HOME") or HOME / ".local" / "state") / "quickshell" / ".venv"
PLUGINS = [HOME / ".local/lib/qt6/qml/Nebula", HOME / ".local/lib/qt6/qml/WfRecorder"]
LOCAL_BIN = HOME / ".local/bin/nebula"
SYSTEM_BIN = Path("/usr/local/bin/nebula")
RC_FILES = [HOME / ".bashrc", HOME / ".zshrc", HOME / ".profile",
            Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config") / "fish" / "config.fish"]

REQUIRE = re.compile(r"""^\s*require\s*\(?\s*["']nebula\.[\w.]+["']\s*\)?\s*$""")
BLOCK = re.compile(r"-- >>> Nebula: (\w+) >>>")
RC_BODY = {
    "# Nebula shell": ("export NEBULA_VENV", "export QML_IMPORT_PATH", "set -gx NEBULA_VENV", "set -gx QML_IMPORT_PATH"),
    "# Nebula greeter": ("nebula-fetch",),
}


def _short(p) -> str:
    s = str(p)
    return "~" + s[len(str(HOME)):] if s.startswith(str(HOME)) else s


def _hypr_edits() -> list:
    out = []
    if not hypr.HYPR.is_dir():
        return out
    for path in sorted(hypr.HYPR.rglob("*.lua")):
        if (hypr.HYPR / "nebula") in path.parents:
            continue
        try:
            text = path.read_text()
        except OSError:
            continue
        new = "\n".join(line for line in text.split("\n") if not REQUIRE.match(line))
        for area in set(BLOCK.findall(new)):
            new = hypr.splice(new, area, "")
        if new != text:
            out.append((path, new))
    return out


def _strip_rc(text: str) -> str:
    lines = text.split("\n")
    out = []
    i = 0
    while i < len(lines):
        body = RC_BODY.get(lines[i].strip())
        if body is None:
            out.append(lines[i])
            i += 1
            continue
        i += 1
        while i < len(lines) and any(lines[i].lstrip().startswith(b) or b in lines[i] for b in body):
            i += 1
        if out and out[-1].strip() == "":
            out.pop()
    return "\n".join(out)


def _rc_edits() -> list:
    out = []
    for rc in RC_FILES:
        try:
            text = rc.read_text()
        except OSError:
            continue
        new = _strip_rc(text)
        if new != text:
            out.append((rc, new))
    return out


def _restores() -> list:
    from nebula import apps
    out = []
    for written in apps.load_manifest():
        path = Path(written)
        bak = path.with_name(path.name + ".bak")
        if bak.is_file():
            out.append((bak, path))
    return out


def _greetd_uses_us() -> bool:
    try:
        for f in Path("/etc/greetd").rglob("*"):
            if f.is_file() and str(SHELL_DIR) in f.read_text(errors="ignore"):
                return True
    except OSError:
        pass
    return False


def _has_local_changes(path: Path) -> bool:
    import subprocess
    if not (path / ".git").exists():
        return False
    r = subprocess.run(["git", "-C", str(path), "status", "--porcelain"], capture_output=True, text=True)
    return r.returncode != 0 or r.stdout.strip() != ""


def _confirm(assume_yes: bool) -> bool:
    if assume_yes:
        return True
    if not sys.stdin.isatty():
        print("nebula: run with --yes to uninstall without a terminal.", file=sys.stderr)
        return False
    return input("\nContinue? [y/N] ").strip().lower() == "y"


def run(purge: bool = False, assume_yes: bool = False) -> int:
    hypr_edits = _hypr_edits()
    rc_edits = _rc_edits()
    restores = _restores()
    plugins = [p for p in PLUGINS if p.exists()]
    local_bin = LOCAL_BIN.is_symlink() and str(SHELL_DIR) in os.path.realpath(LOCAL_BIN)
    purge_dirs = [d for d in (CONFIG_DIR, STATE_DIR, CACHE_DIR, VENV_DIR, hypr.HYPR / "nebula", SHELL_DIR)
                  if d.exists()] if purge else []
    keep_code = purge and _has_local_changes(SHELL_DIR)
    if keep_code:
        purge_dirs.remove(SHELL_DIR)

    print("This removes Nebula from your session:\n")
    print("  · stop the shell")
    for path, _ in hypr_edits:
        print(f"  · take Nebula's require lines and blocks out of {_short(path)} (a .nebula-uninstall.bak copy is kept)")
    for rc, _ in rc_edits:
        print(f"  · remove the Nebula lines from {_short(rc)}")
    for bak, path in restores:
        print(f"  · put back your own {_short(path)} from {bak.name}")
    for p in plugins:
        print(f"  · delete {_short(p)}")
    if local_bin:
        print(f"  · delete {_short(LOCAL_BIN)}")
    for d in purge_dirs:
        print(f"  · delete {_short(d)}")
    if keep_code:
        print(f"\n  Kept {_short(SHELL_DIR)}: it has changes that aren't committed. Delete it yourself once they're saved.")
    if not purge:
        print(f"\n  Kept: settings in {_short(CONFIG_DIR)}, history in {_short(STATE_DIR)}, the code in {_short(SHELL_DIR)}"
              f"\n  and {_short(hypr.HYPR / 'nebula')}. Run `nebula uninstall --purge` to delete those too.")

    if not _confirm(assume_yes):
        print("Nothing changed.")
        return 1

    from nebula import cli
    qs = cli._qs_bin()
    if qs and cli._instance_pids(qs):
        cli.cmd_stop(None)

    for path, new in hypr_edits:
        shutil.copy2(path, path.with_name(path.name + ".nebula-uninstall.bak"))
        hypr.write_atomic(path, new)
    for rc, new in rc_edits:
        rc.write_text(new)
    for bak, path in restores:
        os.replace(bak, path)
    for p in plugins:
        shutil.rmtree(p, ignore_errors=True)
    if local_bin:
        LOCAL_BIN.unlink()
    for d in purge_dirs:
        shutil.rmtree(d, ignore_errors=True)

    print("\nNebula is uninstalled.")
    notes = []
    if SYSTEM_BIN.exists():
        notes.append(f"Remove the command with: sudo rm {SYSTEM_BIN}")
    if _greetd_uses_us():
        notes.append("Your greetd config still starts Nebula's greeter. Point /etc/greetd/config.toml at another greeter.")
    baks = sorted(HOME.joinpath(".config").glob("hypr.bak.*"))
    if baks:
        notes.append(f"Your Hyprland folder from before Nebula is in {_short(baks[0])}.")
    kitty_baks = sorted(HOME.joinpath(".config").glob("kitty.bak.*"))
    if kitty_baks:
        notes.append(f"Your kitty config from before Nebula is in {_short(kitty_baks[0])}.")
    notes.append("Packages the installer added are still installed. Remove any you don't want with pacman or your AUR helper.")
    for n in notes:
        print("  · " + n)
    return 0
