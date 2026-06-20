#!/bin/bash
wallpaper="$1"
scheme="$2"
theme="${3,,}"
transition="${4:-fade}"

awww img "$wallpaper" --transition-type "$transition" --transition-duration 4

# Generate colors using matugen (replaces the old Python gen_colors.py)
# Matugen renders all templates from config.toml, including quickshell_wallpaper
# which outputs to ~/.cache/quickshell/colors.json
echo "[wallpaper] Generating colors with matugen..." >&2
if ! matugen image "$wallpaper" -t "$scheme" -m "$theme" --prefer=darkness --source-color-index=0; then
    echo "[wallpaper] WARNING: matugen color generation failed. Wallpaper was set but colors may not update." >&2
fi

# Append the wallpaper path to colors.json for WallpaperTheme
OUTPUT="$HOME/.cache/quickshell/colors.json"
if [ -f "$OUTPUT" ]; then
    if command -v jq &>/dev/null; then
        jq --arg wp "$wallpaper" '. + {wallpaper: $wp}' "$OUTPUT" > "${OUTPUT}.tmp" && mv "${OUTPUT}.tmp" "$OUTPUT"
    elif command -v python3 &>/dev/null; then
        python3 -c "import json; d=json.load(open('$OUTPUT')); d['wallpaper']='$wallpaper'; json.dump(d, open('$OUTPUT','w'), indent=2)"
    fi
fi
