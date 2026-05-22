#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
overlay_root="$repo_root/.testbed/addons/aerobeat-tool-camera-tracking"
overlay_src="$overlay_root/src"
source_root="$repo_root/src"

if [ -L "$overlay_root" ]; then
  rm "$overlay_root"
fi

mkdir -p "$overlay_src"
find "$overlay_src" -maxdepth 1 -type f -name '*.gd' -delete

for source_file in "$source_root"/*.gd; do
  [ -f "$source_file" ] || continue
  name="$(basename "$source_file")"
  cat > "$overlay_src/$name" <<EOF
extends "res://src/$name"
EOF
done

echo "Prepared local testbed overlay shims in $overlay_src"
ls -1 "$overlay_src"
