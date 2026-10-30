#!/usr/bin/env python3
import json
import os
import shutil
import subprocess
import sys
import time

PRESET = "Nebula"
OUT_DIR = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")), "easyeffects", "output")

BANDS = [
    ("Lo-shelf", 80.0, 0.7),
    ("Bell", 250.0, 0.9),
    ("Bell", 1000.0, 0.9),
    ("Bell", 3000.0, 1.0),
    ("Bell", 6000.0, 1.0),
    ("Hi-shelf", 10000.0, 0.7),
]

STYLES = {
    "flat": {"eq": [0, 0, 0, 0, 0, 0], "enhance": (0.0, 0.0), "night": False},
    "boost": {"eq": [6, 1, 0, 0, 0, 1], "enhance": (8.0, 3.0), "night": False},
    "warm": {"eq": [3, 2, 0, -1, -2, -1.5], "enhance": (3.0, 1.0), "night": False},
    "clear": {"eq": [-1, -2, 1, 3, 2, 2], "enhance": (0.0, 0.0), "night": False},
    "night": {"eq": [2, 0, 1, 2, 0, 0], "enhance": (2.0, 0.0), "night": True},
}


def env():
    e = dict(os.environ)
    e.pop("LD_PRELOAD", None)
    return e


def detect():
    try:
        out = subprocess.run(["pactl", "--format=json", "list", "sinks"], capture_output=True, text=True, timeout=5, env=env()).stdout
        sinks = json.loads(out or "[]")
    except Exception:
        return "speakers"
    for s in sinks:
        props = s.get("properties", {})
        if props.get("device.bus") == "bluetooth" or str(s.get("name", "")).startswith("bluez_"):
            return "headphones"
    for s in sinks:
        port = str(s.get("active_port") or "").lower()
        if "headphone" in port or "headset" in port:
            return "headphones"
    return "speakers"


def band(kind, freq, q, gain):
    return {"type": kind, "mode": "RLC (BT)", "slope": "x1", "solo": False, "mute": False,
            "gain": round(gain, 2), "frequency": freq, "q": q, "width": 4.0}


def preset(style, bass, treble, target):
    s = STYLES.get(style, STYLES["boost"])
    gains = list(s["eq"])
    gains[0] += bass
    gains[5] += treble
    if target == "speakers":
        gains[0] = min(gains[0], 3.0) + max(0.0, gains[0] - 3.0) * 0.25
    channel = {f"band{i}": band(k, f, q, gains[i]) for i, (k, f, q) in enumerate(BANDS)}
    headroom = -round(max(0.0, max(gains)) * 0.6, 2)

    speak, phones = s["enhance"]
    amount = speak if target == "speakers" else phones
    if target == "speakers":
        amount += max(0.0, bass) * 0.6
    else:
        amount += max(0.0, bass) * 0.15
    amount = round(min(amount, 14.0), 2)

    order = ["equalizer#0"]
    out = {
        "blocklist": [],
        "equalizer#0": {
            "bypass": False, "input-gain": headroom, "output-gain": 0.0, "mode": "IIR", "decramp": "Off",
            "split-channels": False, "balance": 0.0, "pitch-left": 0.0, "pitch-right": 0.0,
            "num-bands": len(BANDS), "left": channel, "right": json.loads(json.dumps(channel)),
        },
    }
    if amount > 0.05:
        order.append("bass_enhancer#0")
        out["bass_enhancer#0"] = {
            "bypass": False, "input-gain": 0.0, "output-gain": 0.0, "amount": amount,
            "harmonics": 8.5 if target == "speakers" else 6.0, "scope": 120.0 if target == "speakers" else 90.0,
            "floor": 20.0, "blend": 0.0, "floor-active": False,
        }
    order.append("limiter#0")
    out["limiter#0"] = {
        "bypass": False, "mode": "Herm Thin", "oversampling": "None", "dithering": "None", "sidechain-type": "Internal",
        "input-gain": 10.0 if s["night"] else 0.0, "output-gain": 0.0,
        "lookahead": 5.0, "attack": 5.0, "release": 40.0 if s["night"] else 20.0,
        "threshold": -14.0 if s["night"] else -1.0, "gain-boost": False, "stereo-link": 100.0,
    }
    out["plugins_order"] = order
    return {"output": out}


def running():
    return subprocess.run(["pgrep", "-x", "easyeffects"], capture_output=True).returncode == 0


def apply(style, bass, treble, target):
    if shutil.which("easyeffects") is None:
        print(json.dumps({"ok": False, "error": "missing"}))
        return 1
    if target not in ("speakers", "headphones"):
        target = detect()
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, PRESET + ".json")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(preset(style, bass, treble, target), f, indent=4)
    os.replace(tmp, path)
    if not running():
        subprocess.Popen(["easyeffects", "--service-mode", "-w"], env=env(), start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        for _ in range(40):
            time.sleep(0.25)
            if running():
                break
        time.sleep(1.5)
    subprocess.run(["easyeffects", "-b", "2"], env=env(), capture_output=True, timeout=10)
    subprocess.run(["easyeffects", "-l", PRESET], env=env(), capture_output=True, timeout=10)
    print(json.dumps({"ok": True, "target": target}))
    return 0


def off():
    if running():
        subprocess.run(["easyeffects", "-q"], env=env(), capture_output=True, timeout=10)
    print(json.dumps({"ok": True, "off": True}))
    return 0


def main(argv):
    if len(argv) >= 2 and argv[1] == "detect":
        print(detect())
        return 0
    if len(argv) >= 2 and argv[1] == "off":
        return off()
    if len(argv) >= 6 and argv[1] == "apply":
        try:
            bass = float(argv[3])
            treble = float(argv[4])
        except ValueError:
            bass = treble = 0.0
        return apply(argv[2], max(-6.0, min(12.0, bass)), max(-6.0, min(9.0, treble)), argv[5])
    print("usage: soundfx.py detect | off | apply STYLE BASS TREBLE TARGET", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
