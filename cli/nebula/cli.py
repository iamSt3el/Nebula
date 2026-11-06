import argparse
import importlib
import json
import os
import shutil
import subprocess
import sys

from nebula import __version__
from nebula.paths import COLORS, HOME, SH_DIR, SHELL_DIR, migrate

PASSTHROUGH = {
    "weather":       ("nebula.weather",       "<place>", "weather for a place, wttr j1 JSON"),
    "holidays":      ("nebula.holidays",      "<year> <country>", "public holidays as JSON"),
    "events":        ("nebula.events",        "<ical-url>...", "calendar events from iCal feeds"),
    "stats":         ("nebula.personal",      "", "personal stats for the desk widgets"),
    "claude-usage":  ("nebula.claude_usage",  "[--days N] [--rescan]", "Claude Code token usage"),
    "claude-limits": ("nebula.claude_limits", "[--ttl S]", "Claude plan limits"),
    "art-palette":   ("nebula.art",           "<art-url>", "colours from album art"),
    "gowall":        ("nebula.gowall",        "<image> <theme> | --palette <theme>", "recolour an image with gowall"),
    "gowall-icons":  ("nebula.gowall_icons",  "<theme> [--apply|--preview|--restore]", "recolour the icon theme"),
    "phone-thumbs":  ("nebula.phonethumbs",   "<file>...", "cached thumbnails for files on the phone"),
    "kindle":        ("nebula.kindle",        "render|serve|assets|frame IMG", "Kindle e-ink dashboard PNG (port 8777)"),
    "books":         ("nebula.books",         "popular|search Q|asura|asura-search Q|local|open SRC ID", "books for reading mode, JSON"),
    "wiz":           ("nebula.wiz",           "serve|scan|state|set JSON [--ip IP]", "WiZ smart bulb on the local network"),
    "grub":          ("nebula.grub",          "build|preview|install [--dry-run]", "M3 GRUB theme from the current palette"),
    "hypr":          ("nebula.hypr",          "write|remove|status|retire-legacy", "Hyprland files the settings pages write"),
}

SHELL_TOOLS = {
    "storage":      ("storage_children.sh", "<dir>", "sizes of a folder's children, streamed"),
    "about":        ("about_info.sh", "[shell-dir]", "versions for the About page, JSON"),
    "music-colors": ("music_colors.sh", "<art> [scheme] [mode]", "music palette via matugen"),
}

HELP = """\
nebula {version} — the command line for the Nebula shell

Colours and wallpaper
  nebula wallpaper set <image>     set a wallpaper; scheme, mode and gowall come from settings
  nebula wallpaper random          pick one from your wallpaper folder
  nebula wallpaper current         print the current wallpaper
  nebula scheme set [--mode M] [--variant V]   change light/dark or scheme and recolour
  nebula scheme show               print the current palette
  nebula scheme seeds [image]      list a wallpaper's candidate seed colours
  nebula scheme seed <image> <n>   use candidate n for that wallpaper (0 = auto)
  nebula scheme apply              re-write app colour files from the current palette
  nebula apps                      list apps Nebula can theme and which are picked
  nebula apps enable|disable <id>...   choose which apps follow the palette
  nebula apps reset                go back to theming every detected app

Shell
  nebula start [--foreground]      start the shell (plus the clipboard watcher)
  nebula stop | restart            stop or restart the shell
  nebula setup [--close]           open the setup window (wallpaper, colours, apps, shortcuts)
  nebula settings-source [<key>]   origin (user/drop-in/default) and lock status of settings
  nebula doctor                    check packages Nebula needs
  nebula migrate                   move settings from ~/.cache/quickshell to ~/.config/nebula
  nebula uninstall [--purge]       remove Nebula from your session (--purge also deletes settings and code)
  nebula ipc <target> <function> [args]   call the running shell (qs ipc call)

Layouts (~/.config/nebula/layouts/*.json)
  nebula layout                    list saved layouts
  nebula layout save <name> [--only bar,widgets,...]   save the current layout
  nebula layout load <name|file.json> [--only ...]     apply one (the current layout is kept for undo)
  nebula layout update <name>      save the current settings into an existing layout
  nebula layout undo               go back to the layout before the last load
  nebula layout delete <name>      remove a saved layout
  nebula layout import <file.json> [--rename N]        add someone else's layout
  nebula layout export <name> [dir|file]               copy a layout out to share it

Data (used by the shell, JSON to stdout)
{data}

Run `nebula <command> --help` for the options of wallpaper, scheme, apps and doctor.
"""


def _print_help() -> None:
    rows = []
    for name, (_, args, desc) in {**PASSTHROUGH, **SHELL_TOOLS}.items():
        usage = f"nebula {name} {args}".rstrip()
        rows.append(f"  {usage:<48} {desc}")
    print(HELP.format(version=__version__, data="\n".join(rows)))


def _passthrough(name: str, rest: list) -> None:
    module = importlib.import_module(PASSTHROUGH[name][0])
    sys.argv = [f"nebula {name}", *rest]
    rc = module.main()
    sys.exit(rc if isinstance(rc, int) else 0)


def _shell_tool(name: str, rest: list) -> None:
    script = SH_DIR / SHELL_TOOLS[name][0]
    os.execvp("bash", ["bash", str(script), *rest])


def _run_scheme(argv: list) -> int:
    from nebula import scheme
    sys.argv = ["nebula scheme", *argv]
    try:
        scheme.main()
    except SystemExit as e:
        return e.code if isinstance(e.code, int) else 1
    return 0


def cmd_wallpaper(a) -> int:
    from nebula import wallpaper as wp
    if a.action == "current":
        path = wp.current()
        print(path)
        return 0 if path else 1
    if a.action == "preview":
        from nebula import palette_preview
        sys.argv = ["nebula wallpaper preview", a.image, a.thumb, a.scheme, a.mode]
        palette_preview.main()
        return 0
    if a.action == "screen":
        from nebula import screen
        sys.argv = ["nebula wallpaper screen", a.src, a.out, str(a.width), str(a.height),
                    *(["--grey"] if a.grey else []), *(["--eink"] if a.eink else [])]
        screen.main()
        return 0

    d = wp.defaults()
    if a.action == "random":
        image = wp.pick_random(wp.wallpaper_dir() if not a.dir else wp.Path(os.path.expanduser(a.dir)))
        if not image:
            print("nebula: no images found in the wallpaper folder", file=sys.stderr)
            return 1
        print(image)
    else:
        image = os.path.abspath(os.path.expanduser(a.image))
    return wp.apply(image,
                    a.scheme or d["scheme"], a.mode or d["mode"],
                    a.gowall or d["gowall"],
                    a.gowall_icons or d["icons"], a.invert or d["invert"], a.gowall_shell or d["shell"])


def cmd_scheme(a) -> int:
    if a.action == "generate":
        argv = [a.image, a.variant, a.mode]
        for flag, val in (("--source", a.source), ("--display", a.display),
                          ("--palette-file", a.palette_file), ("--apps", a.apps)):
            if val is not None:
                argv += [flag, val]
        if a.keep_icon_theme:
            argv.append("--keep-icon-theme")
        return _run_scheme(argv)

    if a.action == "apply":
        argv = ["--apps-only"]
        if a.apps is not None:
            argv += ["--apps", a.apps]
        argv += ["--mode", a.mode or _settings_mode()]
        if a.keep_icon_theme:
            argv.append("--keep-icon-theme")
        return _run_scheme(argv)

    if a.action == "show":
        return _show_palette(a.json)

    if a.action in ("seeds", "seed"):
        import json
        import os
        from nebula import scheme, wallpaper as wp
        image = a.image or wp.current()
        if not image or not os.path.isfile(image):
            print(f"nebula: no such image: {image}", file=sys.stderr)
            return 1
        if a.action == "seed":
            scheme.set_seed(image, a.index)
            return 0
        d = wp.defaults()
        print(json.dumps(scheme.seeds_report(image, a.variant or d["scheme"], a.mode or d["mode"])))
        return 0

    if a.action == "set":
        from nebula import settings, wallpaper as wp
        patch = {}
        if a.mode:
            patch["matugenTheme"] = a.mode
        if a.variant:
            patch["matugenScheme"] = a.variant if a.variant.startswith("scheme-") else "scheme-" + a.variant
        if not patch:
            print("nebula: give --mode and/or --variant", file=sys.stderr)
            return 2
        settings.update("theme", patch)
        image = wp.current()
        if not image:
            print("nebula: saved; no wallpaper to recolour yet", file=sys.stderr)
            return 0
        d = wp.defaults()
        return wp.apply(image, d["scheme"], d["mode"], d["gowall"],
                        d["icons"], d["invert"], d["shell"])
    return 2


def _settings_mode() -> str:
    from nebula import settings
    return settings.section("theme").get("matugenTheme", "dark")


def _show_palette(as_json: bool) -> int:
    try:
        colors = json.loads(COLORS.read_text())
    except Exception as e:
        print(f"nebula: cannot read {COLORS}: {e}", file=sys.stderr)
        return 1
    if as_json:
        print(json.dumps(colors, indent=2))
        return 0
    roles = ["primary", "primaryContainer", "secondary", "secondaryContainer",
             "tertiary", "tertiaryContainer", "error", "surface",
             "surfaceContainer", "surfaceContainerHighest", "surfaceText", "outline"]
    tty = sys.stdout.isatty()
    print(f"wallpaper  {colors.get('sourceWallpaper') or colors.get('wallpaper', '')}")
    for r in roles:
        hx = colors.get(r, "")
        swatch = ""
        if tty and len(hx) == 7:
            rr, gg, bb = int(hx[1:3], 16), int(hx[3:5], 16), int(hx[5:7], 16)
            swatch = f"\033[48;2;{rr};{gg};{bb}m      \033[0m "
        print(f"{swatch}{r:<26}{hx}")
    return 0


def cmd_apps(a) -> int:
    from nebula import apps
    action = a.action or "list"
    if action == "detect":
        print(json.dumps(apps.detect()))
        return 0
    if action == "list":
        return apps.print_list(getattr(a, "json", False))
    if action in ("enable", "disable"):
        return apps.set_picked(a.ids, action == "enable", a.apply)
    if action == "reset":
        return apps.reset(a.apply)
    return 2


def cmd_layout(a) -> int:
    from nebula import layouts
    only = [x for x in (a.only or "").split(",") if x] or None
    act = a.action or "list"
    if act == "list":
        return layouts.print_list(a.json)
    if act == "save":
        return layouts.save(a.name, only)
    if act == "load":
        return layouts.load(a.name, only, a.emit)
    if act == "update":
        return layouts.update(a.name)
    if act == "undo":
        return layouts.undo(a.emit)
    if act == "delete":
        return layouts.delete(a.name)
    if act == "import":
        return layouts.import_file(a.name, a.rename)
    if act == "export":
        return layouts.export(a.name, a.dest)
    return 2


def cmd_doctor(a) -> int:
    from nebula import doctor
    return doctor.run(a.json)


def _qs_ipc(args: list, quiet: bool = False) -> int:
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        print("nebula: quickshell is not installed", file=sys.stderr)
        return 1
    r = subprocess.run([qs, "ipc", "--path", str(SHELL_DIR), *args],
                       capture_output=quiet, text=True)
    if r.returncode != 0 and quiet:
        print("nebula: the shell isn't running. Start it with `quickshell`.", file=sys.stderr)
    return r.returncode


def cmd_ipc(a) -> int:
    return _qs_ipc(["show"] if not a.args else ["call", *a.args])


def cmd_setup(a) -> int:
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        print("nebula: quickshell is not installed", file=sys.stderr)
        return 1
    config = str(SHELL_DIR / "setup.qml")
    if a.close:
        return subprocess.run([qs, "kill", "-p", config], capture_output=True).returncode
    return subprocess.run([qs, "-n", "-d", "-p", config],
                          stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                          stderr=subprocess.DEVNULL).returncode


def _qs_bin():
    qs = shutil.which("qs") or shutil.which("quickshell")
    if not qs:
        print("nebula: quickshell is not installed", file=sys.stderr)
    return qs


def _running(pattern: str) -> bool:
    return subprocess.run(["pgrep", "-u", str(os.getuid()), "-f", pattern],
                          stdout=subprocess.DEVNULL).returncode == 0


def _spawn(argv: list, env=None) -> None:
    subprocess.Popen(argv, env=env, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                     stderr=subprocess.DEVNULL, start_new_session=True)


MESA_EGL = "/usr/share/glvnd/egl_vendor.d/50_mesa.json"
TCMALLOC = "/usr/lib/libtcmalloc_minimal.so.4"


def _display_drivers() -> set:
    from pathlib import Path
    drivers = set()
    for status in Path("/sys/class/drm").glob("card*-*/status"):
        try:
            if status.read_text().strip() != "connected":
                continue
            card = status.parent.name.split("-")[0]
            drivers.add(Path(f"/sys/class/drm/{card}/device/driver").resolve().name)
        except OSError:
            continue
    return drivers


def _shell_env() -> dict:
    env = dict(os.environ)
    env.setdefault("QSG_RENDER_LOOP", "threaded")
    qml = str(HOME / ".local/lib/qt6/qml")
    paths = [p for p in env.get("QML_IMPORT_PATH", "").split(":") if p]
    if qml not in paths:
        env["QML_IMPORT_PATH"] = ":".join([qml, *paths])
    drivers = _display_drivers()
    if ("__EGL_VENDOR_LIBRARY_FILENAMES" not in env and os.path.exists(MESA_EGL)
            and drivers and "nvidia" not in drivers):
        env["__EGL_VENDOR_LIBRARY_FILENAMES"] = MESA_EGL
    preload = [p for p in env.get("LD_PRELOAD", "").split() if p]
    if os.path.exists(TCMALLOC) and not any("tcmalloc" in p for p in preload):
        env["LD_PRELOAD"] = " ".join([TCMALLOC, *preload])
    if any("tcmalloc" in p for p in env.get("LD_PRELOAD", "").split()):
        env.setdefault("TCMALLOC_AGGRESSIVE_DECOMMIT", "t")
    venv = HOME / ".local/state/quickshell/.venv"
    if "NEBULA_VENV" not in env and (venv / "bin/python").exists():
        has_lib = subprocess.run(["python3", "-c", "import materialyoucolor"],
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        if not has_lib:
            env["NEBULA_VENV"] = str(venv)
    return env


NOTIF_NAME = "org.freedesktop.Notifications"


def _block_notif_activation() -> None:
    from pathlib import Path
    user_dir = HOME / ".local/share/dbus-1/services"
    wrote = False
    for f in Path("/usr/share/dbus-1/services").glob("*.service"):
        try:
            if f"Name={NOTIF_NAME}" not in f.read_text().split():
                continue
        except OSError:
            continue
        target = user_dir / f.name
        if target.exists():
            continue
        user_dir.mkdir(parents=True, exist_ok=True)
        target.write_text(f"[D-BUS Service]\nName={NOTIF_NAME}\nExec=/bin/false\n")
        wrote = True
    if wrote and shutil.which("busctl"):
        subprocess.run(["busctl", "--user", "call", "org.freedesktop.DBus", "/org/freedesktop/DBus",
                        "org.freedesktop.DBus", "ReloadConfig"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def _free_notif_name() -> None:
    import signal
    if not shutil.which("busctl"):
        return
    r = subprocess.run(["busctl", "--user", "status", NOTIF_NAME], capture_output=True, text=True)
    info = dict(line.split("=", 1) for line in r.stdout.splitlines() if "=" in line)
    comm = info.get("Comm", "")
    if not info.get("PID", "").isdigit() or comm in ("qs", "quickshell", ".quickshell-wra"):
        return
    try:
        os.kill(int(info["PID"]), signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass


def cmd_settings_source(a) -> int:
    from nebula import settings
    if a.key:
        info = settings.get_source(a.key)
        if a.json:
            print(json.dumps(info, indent=2))
            return 0
        status = "yes" if info["locked"] else "no"
        print(f"key:        {info['key']}")
        print(f"value:      {info['value']}")
        print(f"source:     {info['source']} ({info['sourceType']})")
        print(f"locked:     {status}")
        return 0

    all_data = settings.get_all_sources()
    if a.json:
        print(json.dumps(all_data, indent=2))
        return 0

    dropins = all_data["dropinFiles"]
    locks = all_data["locked"]
    print("Drop-in files:")
    if dropins:
        for f in dropins:
            print(f"  {f}")
    else:
        print("  none found")

    print("\nAdmin locks:")
    if locks:
        for k in locks:
            print(f"  {k}")
    else:
        print("  none")

    print("\nSettings:")
    if all_data["settings"]:
        print(f"  {'KEY':<32} {'VALUE':<20} {'LOCKED':<8} {'SOURCE'}")
        for s in all_data["settings"]:
            val_str = str(s["value"])
            if len(val_str) > 18:
                val_str = val_str[:15] + "..."
            lock_str = "yes" if s["locked"] else "no"
            print(f"  {s['key']:<32} {val_str:<20} {lock_str:<8} {s['source']}")
    else:
        print("  none")
    return 0


def cmd_migrate(a) -> int:
    moved = migrate()
    for src, dst in moved:
        print(f"{str(src).replace(str(HOME), '~', 1)} → {str(dst).replace(str(HOME), '~', 1)}")
    if not moved and not a.quiet:
        print("Nothing to move.")
    return 0


def _starter_wallpaper() -> str:
    from pathlib import Path
    from nebula import settings
    from nebula.wallpaper import IMAGE_EXTS
    folder = Path(os.path.expanduser(settings.section("general").get("wallpaperDir") or str(HOME / "wallpaper")))
    starter = folder / "nebula-default.jpg"
    if starter.is_file():
        return str(starter)
    try:
        images = sorted(p for p in folder.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTS)
    except OSError:
        images = []
    return str(images[0]) if images else str(SHELL_DIR / "assets" / "wallpapers" / "nebula-default.jpg")


def _first_colors() -> bool:
    if COLORS.exists():
        return False
    from nebula import wallpaper as wp
    d = wp.defaults()
    _run_scheme([_starter_wallpaper(), d["scheme"], d["mode"], "--apps", ""])
    return True


def _welcome_notice() -> None:
    if not shutil.which("notify-send"):
        return
    script = ('sleep 8; a=$(notify-send -a Nebula -A "setup=Open setup" "Welcome to Nebula" '
              '"Pick a wallpaper, colours and the features you want. It takes about a minute."); '
              '[ "$a" = setup ] && exec "$0" setup')
    _spawn(["sh", "-c", script, str(SHELL_DIR / "bin" / "nebula")])


def cmd_start(a) -> int:
    qs = _qs_bin()
    if not qs:
        return 1
    env = _shell_env()
    splash = getattr(a, "splash", False) and not _shell_up(qs)
    if splash:
        _spawn([qs, "-n", "-p", str(SHELL_DIR / "splash.qml")], env)
        env["NEBULA_SPLASH"] = "1"
    migrate()
    first_run = not _shell_up(qs) and _first_colors()
    if first_run:
        _welcome_notice()
    from nebula import settings
    clipboard_on = settings.section("features").get("clipboard", True)
    if clipboard_on and shutil.which("wl-paste") and shutil.which("cliphist") and not _running("wl-paste --watch cliphist"):
        _spawn(["wl-paste", "--watch", "cliphist", "store"])
    _block_notif_activation()
    _free_notif_name()
    config = str(SHELL_DIR / "shell.qml")
    if a.foreground:
        os.execvpe(qs, [qs, "-n", "-p", config], env)
    code = subprocess.run([qs, "-n", "-d", "-p", config], env=env, stdin=subprocess.DEVNULL,
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    if code != 0 or not sys.stderr.isatty():
        return code
    return _check_load(qs)


def _check_load(qs: str, wait: float = 20.0) -> int:
    import re
    import time
    ansi = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
    deadline = time.time() + wait
    seen = False
    while time.time() < deadline:
        time.sleep(0.3)
        pids = _instance_pids(qs)
        if not pids:
            if seen:
                break
            continue
        seen = True
        r = subprocess.run([qs, "log", "--pid", str(pids[-1])], capture_output=True, text=True)
        lines = ansi.sub("", r.stdout + r.stderr).splitlines()
        fail = [i for i, line in enumerate(lines) if "Failed to load configuration" in line]
        loaded = [i for i, line in enumerate(lines) if "Configuration Loaded" in line]
        if fail and (not loaded or fail[-1] > loaded[-1]):
            print("nebula: the shell couldn't load its config:", file=sys.stderr)
            for line in lines[fail[-1] + 1:]:
                if "ERROR" not in line:
                    break
                print("  " + line.split("ERROR", 1)[1].lstrip(" :"), file=sys.stderr)
            print("nebula: it keeps running and reloads as soon as the file is fixed.", file=sys.stderr)
            return 1
        if loaded:
            return 0
    if not seen or not _instance_pids(qs):
        print("nebula: the shell exited while starting. Run `nebula start --foreground` to see why.",
              file=sys.stderr)
        return 1
    print("nebula: the shell is still loading.", file=sys.stderr)
    return 0


def _instance_pids(qs: str) -> list:
    r = subprocess.run([qs, "list", "-j", "-p", str(SHELL_DIR / "shell.qml")],
                       capture_output=True, text=True)
    try:
        return [int(i["pid"]) for i in json.loads(r.stdout or "[]")]
    except Exception:
        return []


def _descendants(roots: list) -> set:
    from pathlib import Path
    children = {}
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            fields = stat.read_text().rsplit(")", 1)[1].split()
            children.setdefault(int(fields[1]), []).append(int(stat.parent.name))
        except (OSError, IndexError, ValueError):
            continue
    found = set()
    todo = list(roots)
    while todo:
        pid = todo.pop()
        if pid in found:
            continue
        found.add(pid)
        todo.extend(children.get(pid, []))
    return found


def cmd_uninstall(a) -> int:
    from nebula import uninstall
    return uninstall.run(purge=a.purge, assume_yes=a.yes)


def cmd_stop(a) -> int:
    import signal
    qs = _qs_bin()
    if not qs:
        return 1
    roots = _instance_pids(qs)
    if not roots:
        print("nebula: the shell isn't running", file=sys.stderr)
        return 1
    procs = _descendants(roots)
    for sig in (signal.SIGSTOP, signal.SIGKILL):
        for pid in procs:
            try:
                os.kill(pid, sig)
            except (ProcessLookupError, PermissionError):
                pass
    return 0


def _shell_up(qs: str) -> bool:
    r = subprocess.run([qs, "list", "-j", "-p", str(SHELL_DIR / "shell.qml")],
                       capture_output=True, text=True)
    try:
        return len(json.loads(r.stdout or "[]")) > 0
    except Exception:
        return "Instance" in r.stdout


def cmd_restart(a) -> int:
    import time
    qs = _qs_bin()
    if not qs:
        return 1
    cmd_stop(a)
    for _ in range(50):
        if not _shell_up(qs):
            break
        time.sleep(0.1)
    a.foreground = False
    return cmd_start(a)


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="nebula", add_help=False)
    sub = p.add_subparsers(dest="command")

    w = sub.add_parser("wallpaper", help="set or inspect the wallpaper")
    ws = w.add_subparsers(dest="action", required=True)
    for name in ("set", "random"):
        s = ws.add_parser(name)
        if name == "set":
            s.add_argument("image")
        else:
            s.add_argument("--dir")
        s.add_argument("--scheme")
        s.add_argument("--mode", choices=["dark", "light"])
        s.add_argument("--gowall")
        s.add_argument("--gowall-icons", choices=["on", "off"])
        s.add_argument("--invert", choices=["on", "off"])
        s.add_argument("--gowall-shell", choices=["on", "off"])
    ws.add_parser("current")
    pv = ws.add_parser("preview", help="palette JSON for a wallpaper, without applying it")
    pv.add_argument("image")
    pv.add_argument("thumb")
    pv.add_argument("scheme")
    pv.add_argument("mode")
    sc = ws.add_parser("screen", help="scaled copy for the lock and greeter")
    sc.add_argument("src")
    sc.add_argument("out")
    sc.add_argument("width", type=int)
    sc.add_argument("height", type=int)
    sc.add_argument("--grey", action="store_true", help="greyscale copy (Kindle mode)")
    sc.add_argument("--eink", action="store_true", help="16-grey e-ink copy through gowall (Kindle mode)")

    s = sub.add_parser("scheme", help="colour scheme")
    ss = s.add_subparsers(dest="action", required=True)
    g = ss.add_parser("generate", help="build colours from an image (the shell's pipeline step)")
    g.add_argument("image")
    g.add_argument("variant")
    g.add_argument("mode")
    g.add_argument("--source")
    g.add_argument("--display")
    g.add_argument("--palette-file")
    g.add_argument("--apps")
    g.add_argument("--keep-icon-theme", action="store_true")
    ap = ss.add_parser("apply", help="re-write app colour files from the current palette")
    ap.add_argument("--apps", help="comma-separated ids; default: your saved choice")
    ap.add_argument("--mode", choices=["dark", "light"])
    ap.add_argument("--keep-icon-theme", action="store_true")
    sh = ss.add_parser("show")
    sh.add_argument("--json", action="store_true")
    sd = ss.add_parser("seeds", help="candidate seed colours for a wallpaper, as JSON")
    sd.add_argument("image", nargs="?")
    sd.add_argument("--variant")
    sd.add_argument("--mode", choices=["dark", "light"])
    sp = ss.add_parser("seed", help="remember which seed colour a wallpaper uses (0 = auto)")
    sp.add_argument("image")
    sp.add_argument("index", type=int)
    st = ss.add_parser("set")
    st.add_argument("--mode", choices=["dark", "light"])
    st.add_argument("--variant", help="content, tonalspot, vibrant, expressive, fidelity, fruitsalad, rainbow, neutral, monochrome, kindle")

    a = sub.add_parser("apps", help="which apps follow the palette")
    as_ = a.add_subparsers(dest="action")
    l = as_.add_parser("list")
    l.add_argument("--json", action="store_true")
    as_.add_parser("detect")
    for name in ("enable", "disable"):
        e = as_.add_parser(name)
        e.add_argument("ids", nargs="+")
        e.add_argument("--apply", action="store_true", help="re-write colour files now")
    r = as_.add_parser("reset")
    r.add_argument("--apply", action="store_true")

    d = sub.add_parser("doctor", help="check dependencies")
    d.add_argument("--json", action="store_true")

    st = sub.add_parser("start", help="start the shell")
    st.add_argument("--foreground", action="store_true", help="stay attached and print the log")
    st.add_argument("--splash", action="store_true", help="play the login splash while the shell loads")
    sub.add_parser("stop", help="stop the shell")
    sub.add_parser("restart", help="restart the shell")
    mg = sub.add_parser("migrate", help="move settings out of ~/.cache/quickshell")
    mg.add_argument("--quiet", action="store_true")

    un = sub.add_parser("uninstall", help="remove Nebula from your session")
    un.add_argument("--purge", action="store_true", help="also delete settings, history, caches and the code")
    un.add_argument("--yes", action="store_true", help="don't ask first")

    su = sub.add_parser("setup", help="open the setup window")
    su.add_argument("--close", action="store_true")

    lo = sub.add_parser("layout", help="save and load whole-shell layouts")
    lo.add_argument("action", nargs="?", choices=["list", "save", "load", "update", "undo", "delete", "import", "export"])
    lo.add_argument("name", nargs="?", default="")
    lo.add_argument("dest", nargs="?", default=".")
    lo.add_argument("--only", help="comma-separated: bar,widgets,dashboard,panels,lockscreen")
    lo.add_argument("--rename")
    lo.add_argument("--json", action="store_true")
    lo.add_argument("--emit", action="store_true", help=argparse.SUPPRESS)

    src = sub.add_parser("settings-source", help="show setting source (user/drop-in) and lock status")
    src.add_argument("key", nargs="?", help="dotted key, e.g. general.palette")
    src.add_argument("--json", action="store_true", help="output as JSON")

    i = sub.add_parser("ipc", help="call the running shell")
    i.add_argument("args", nargs=argparse.REMAINDER)
    return p


def main(argv=None) -> None:
    argv = list(sys.argv[1:] if argv is None else argv)
    if not argv or argv[0] in ("-h", "--help", "help"):
        _print_help()
        sys.exit(0)
    if argv[0] in ("-V", "--version", "version"):
        print(__version__)
        sys.exit(0)
    if argv[0] in PASSTHROUGH:
        _passthrough(argv[0], argv[1:])
    if argv[0] in SHELL_TOOLS:
        _shell_tool(argv[0], argv[1:])

    parser = build_parser()
    if argv[0] not in ("wallpaper", "scheme", "apps", "doctor", "ipc", "setup", "start", "stop", "restart", "layout", "migrate", "uninstall", "settings-source"):
        print(f"nebula: unknown command '{argv[0]}'. Run `nebula help`.", file=sys.stderr)
        sys.exit(2)
    a = parser.parse_args(argv)
    handler = {"wallpaper": cmd_wallpaper, "scheme": cmd_scheme, "apps": cmd_apps,
               "doctor": cmd_doctor, "ipc": cmd_ipc, "setup": cmd_setup,
               "start": cmd_start, "stop": cmd_stop, "restart": cmd_restart, "layout": cmd_layout,
               "migrate": cmd_migrate, "uninstall": cmd_uninstall, "settings-source": cmd_settings_source}[a.command]
    sys.exit(handler(a) or 0)
