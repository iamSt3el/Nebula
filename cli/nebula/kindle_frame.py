import json
import shutil
import subprocess
from pathlib import Path

from nebula.kindle import KINDLE_DIR, OUT_DIR, snap

SOURCE = OUT_DIR / "frame-src"
PREVIEW = OUT_DIR / "frame-preview.png"
NAME = OUT_DIR / "frame-name"
FIT = OUT_DIR / "frame-fit"
UNIT = "nebula-kindle"
LEVELS = [v * 17 for v in range(16)]


def config_rotate():
    try:
        for line in (KINDLE_DIR / "config.sh").read_text().splitlines():
            if line.startswith("ROTATE="):
                return line.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "ccw"


def convert(src, rotate="ccw", fit="cover"):
    from PIL import Image, ImageOps
    img = ImageOps.exif_transpose(Image.open(src)).convert("L")
    size = (600, 800) if rotate == "none" else (800, 600)
    if fit == "contain":
        edge = sorted(list(img.crop((0, 0, img.width, 4)).getdata()) + list(img.crop((0, img.height - 4, img.width, img.height)).getdata())
                      + list(img.crop((0, 0, 4, img.height)).getdata()) + list(img.crop((img.width - 4, 0, img.width, img.height)).getdata()))
        bg = edge[len(edge) // 2]
        if bg > 150 and edge[len(edge) * 9 // 10] - edge[len(edge) // 10] < 40:
            cut = max(1, edge[len(edge) // 20] - 6)
            img = img.point(lambda v: 255 if v >= cut else round(v * 255 / cut))
            bg = 255
        img = ImageOps.pad(img, size, Image.Resampling.LANCZOS, color=bg)
    else:
        img = ImageOps.fit(img, size, Image.Resampling.LANCZOS)
    img = ImageOps.autocontrast(img, cutoff=0.5)
    pal = Image.new("P", (1, 1))
    pal.putpalette([c for v in LEVELS for c in (v, v, v)] + [0, 0, 0] * 240)
    img = img.convert("RGB").quantize(palette=pal, dither=Image.Dither.FLOYDSTEINBERG).convert("L")
    if rotate == "ccw":
        img = img.rotate(-90, expand=True)
    elif rotate == "cw":
        img = img.rotate(90, expand=True)
    return snap(img)


def source():
    return (SOURCE if SOURCE.exists() else None), (FIT.read_text().strip() if FIT.exists() else "cover")


def rendered(rotate):
    src, fit = source()
    if not src:
        return None
    out = OUT_DIR / f"frame-{rotate}.png"
    if not out.exists() or out.stat().st_mtime < src.stat().st_mtime:
        convert(src, rotate, fit).save(out, optimize=True)
    return out


def write_local(fit):
    rotate = config_rotate()
    img = convert(SOURCE, rotate, fit)
    local = KINDLE_DIR / "frame.png"
    img.save(local, optimize=True)
    back = {"ccw": 90, "cw": -90}.get(rotate, 0)
    (img.rotate(back, expand=True) if back else img).save(PREVIEW, optimize=True)
    for old in OUT_DIR.glob("frame-c*w.png"):
        old.unlink()
    (OUT_DIR / "frame-none.png").unlink(missing_ok=True)
    return local


def set_image(path, fit="cover"):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, SOURCE)
    NAME.write_text(Path(path).name)
    FIT.write_text(fit)
    return write_local(fit)


def set_fit(fit):
    if not SOURCE.exists():
        return None
    FIT.write_text(fit)
    SOURCE.touch()
    return write_local(fit)


def clear():
    for old in [SOURCE, FIT, NAME, PREVIEW, KINDLE_DIR / "frame.png", *OUT_DIR.glob("frame-*.png")]:
        old.unlink(missing_ok=True)


def kindle_device():
    try:
        out = subprocess.run(["lsblk", "-J", "-o", "PATH,LABEL,MOUNTPOINT"], capture_output=True, text=True, timeout=5).stdout
        devs = json.loads(out).get("blockdevices", [])
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None, None

    def walk(items):
        for d in items:
            yield d
            yield from walk(d.get("children") or [])
    for d in walk(devs):
        if (d.get("label") or "") == "Kindle":
            return d.get("path"), d.get("mountpoint")
    return None, None


def serving():
    return subprocess.run(["systemctl", "--user", "is-active", "--quiet", UNIT]).returncode == 0


def wifi(on):
    if on:
        if not serving():
            subprocess.run(["systemctl", "--user", "reset-failed", UNIT], capture_output=True)
            cli = Path(__file__).resolve().parents[2] / "bin" / "nebula"
            subprocess.run(["systemd-run", "--user", f"--unit={UNIT}", "--description=Nebula Kindle server",
                            str(cli), "kindle", "serve"], capture_output=True)
    else:
        subprocess.run(["systemctl", "--user", "stop", UNIT], capture_output=True)


def push():
    local = KINDLE_DIR / "frame.png"
    if not local.exists():
        return False, "No image chosen yet"
    dev, mount = kindle_device()
    if not dev:
        return False, "Kindle isn't plugged in"
    if not mount:
        r = subprocess.run(["udisksctl", "mount", "-b", dev], capture_output=True, text=True, timeout=30)
        dev, mount = kindle_device()
        if not mount:
            return False, (r.stderr.strip() or "Couldn't mount the Kindle").splitlines()[-1]
    target = Path(mount) / "nebula-dash"
    if not target.is_dir():
        return False, "Nebula dashboard isn't installed on this Kindle"
    shutil.copyfile(local, target / "frame.png")
    subprocess.run(["sync"])
    return True, "Copied to the Kindle"


def status():
    dev, mount = kindle_device()
    local = KINDLE_DIR / "frame.png"
    on_kindle = False
    if mount and local.exists():
        remote = Path(mount) / "nebula-dash" / "frame.png"
        try:
            on_kindle = remote.read_bytes() == local.read_bytes()
        except OSError:
            pass
    src, fit = source()
    return {
        "usb": "mounted" if mount else "present" if dev else "none",
        "mount": mount or "",
        "hasFrame": local.exists(),
        "name": NAME.read_text().strip() if NAME.exists() else "",
        "fit": fit,
        "preview": str(PREVIEW) if PREVIEW.exists() else "",
        "updated": int(SOURCE.stat().st_mtime) if src else 0,
        "onKindle": on_kindle,
        "serving": serving(),
        "rotate": config_rotate(),
    }
