#!/usr/bin/env python3
import json
import os
import sys

from nebula import scheme as g


def main() -> None:
    if len(sys.argv) < 5:
        print(f"Usage: {sys.argv[0]} <original> <thumb> <variant> <mode>", file=sys.stderr)
        sys.exit(1)

    original, thumb = sys.argv[1], sys.argv[2]
    variant = sys.argv[3].removeprefix("scheme-").replace("-", "")
    mode = sys.argv[4].lower()

    primary = None
    if os.path.isfile(original):
        img_hash = g._image_hash(original)
        idx = g._chosen_seed(img_hash)
        name = f"{variant}_{mode}_s{idx}.json" if idx else f"{variant}_{mode}.json"
        cached = g.CACHE_DIR / "color_cache" / img_hash / name
        if cached.exists():
            print(json.dumps(json.loads(cached.read_text())))
            return
        primary = g.seed_primary(original, img_hash, idx)

    if primary is None:
        source = thumb if os.path.isfile(thumb) else original
        primary = g._quantize_and_score(source)
    print(json.dumps(g._build_scheme(primary, variant, mode != "light")))


if __name__ == "__main__":
    main()
