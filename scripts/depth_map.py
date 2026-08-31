#!/usr/bin/env python3
"""
Depth map for a wallpaper, for the parallax shader.

Model: onnx-community/depth-anything-v2-small (int8 ONNX export, ~27 MB).
Downloaded once into the cache dir with curl; no torch, no huggingface_hub.

Depth-Anything emits *inverse* depth, so the normalized output is
white = nearest, which is what shaders/parallax.frag expects for `depthMap`.

Usage: depth_map.py <image> [--force]
Prints "depth=<path>".
"""

import hashlib
import os
import re
import subprocess
import sys

import numpy as np
from PIL import Image

MODEL_URL = ("https://huggingface.co/onnx-community/depth-anything-v2-small/"
             "resolve/main/onnx/model_quantized.onnx")
MODEL_NAME = "depth-anything-v2-small-int8.onnx"

MAX_CACHED_MAPS = 60
MAP_NAME = re.compile(r"[0-9a-f]{40}\.png\Z")

INPUT_SIZE = 518
MULTIPLE_OF = 14
IMAGE_MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
IMAGE_STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    d = os.path.join(base, "quickshell", "depth")
    os.makedirs(d, exist_ok=True)
    return d


def _key(image_path, *extra):
    st = os.stat(image_path)
    parts = [os.path.realpath(image_path), str(st.st_size), str(int(st.st_mtime))]
    parts += [str(e) for e in extra]
    return hashlib.sha1(":".join(parts).encode()).hexdigest()


def depth_path(image_path):
    return os.path.join(cache_dir(), _key(image_path) + ".png")


def ensure_model():
    path = os.path.join(cache_dir(), MODEL_NAME)
    if os.path.exists(path) and os.path.getsize(path) > 1_000_000:
        return path
    tmp = path + ".part"
    subprocess.run(["curl", "-fsSL", "-o", tmp, MODEL_URL], check=True)
    os.replace(tmp, path)
    return path


def target_size(w, h):
    """DPT resize: shorter side to 518, aspect kept, both dims multiples of 14."""
    scale = INPUT_SIZE / min(w, h)
    tw = max(MULTIPLE_OF, round(w * scale / MULTIPLE_OF) * MULTIPLE_OF)
    th = max(MULTIPLE_OF, round(h * scale / MULTIPLE_OF) * MULTIPLE_OF)
    return tw, th


def _save(img, path):
    tmp = path + ".part"
    img.save(tmp, format="PNG")
    os.replace(tmp, path)


def run_model(image):
    import onnxruntime as ort

    tw, th = target_size(*image.size)
    arr = np.asarray(image.resize((tw, th), Image.BICUBIC), dtype=np.float32) / 255.0
    arr = (arr - IMAGE_MEAN) / IMAGE_STD
    tensor = np.transpose(arr, (2, 0, 1))[None, ...].astype(np.float32)

    sess = ort.InferenceSession(ensure_model(), providers=["CPUExecutionProvider"])
    depth = np.squeeze(sess.run(None, {sess.get_inputs()[0].name: tensor})[0])

    lo, hi = float(depth.min()), float(depth.max())
    depth = (depth - lo) / (hi - lo) if hi > lo else np.zeros_like(depth)
    return (Image.fromarray((depth * 255.0).astype(np.uint8), "L")
                 .resize(image.size, Image.BICUBIC))


def prune(keep=MAX_CACHED_MAPS):
    """Drop the least recently used depth maps; they regenerate on demand."""
    d = cache_dir()
    maps = []
    for name in os.listdir(d):
        if not MAP_NAME.match(name):
            continue
        path = os.path.join(d, name)
        try:
            maps.append((os.stat(path).st_mtime, path))
        except OSError:
            pass
    maps.sort(reverse=True)
    for _, path in maps[keep:]:
        try:
            os.remove(path)
        except OSError:
            pass


def generate(image_path, force=False):
    d_out = depth_path(image_path)
    if os.path.exists(d_out) and not force:
        os.utime(d_out, None)
        return d_out
    _save(run_model(Image.open(image_path).convert("RGB")), d_out)
    prune()
    return d_out


if __name__ == "__main__":
    argv = sys.argv[1:]
    args = [a for a in argv if not a.startswith("--")]

    if not args:
        print("usage: depth_map.py <image> [--force]", file=sys.stderr)
        sys.exit(2)
    try:
        print(f"depth={generate(args[0], force='--force' in argv)}")
    except ImportError:
        print("depth_map: onnxruntime missing — install python-onnxruntime-cpu",
              file=sys.stderr)
        sys.exit(3)
    except Exception as exc:
        print(f"depth_map: {exc}", file=sys.stderr)
        sys.exit(1)
