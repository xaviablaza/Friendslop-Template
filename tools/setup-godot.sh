#!/usr/bin/env bash
set -euo pipefail
# Engine is installed per-user, not committed. Requires curl/unzip/git-lfs.
version=4.4.1
root="$(cd "$(dirname "$0")/.." && pwd)"
engine_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot/$version"
cache="${TMPDIR:-$HOME/.cache}/friendslop-setup"
mkdir -p "$engine_dir" "$cache" "$HOME/.local/bin"
command -v git-lfs >/dev/null || { printf 'Install git-lfs first (Ubuntu: sudo apt-get install git-lfs).\n' >&2; exit 1; }
archive="$cache/Godot_v${version}-stable_linux.x86_64.zip"
if [ ! -f "$engine_dir/Godot_v${version}-stable_linux.x86_64" ]; then
  curl -fL --retry 2 -o "$archive" "https://github.com/godotengine/godot/releases/download/${version}-stable/Godot_v${version}-stable_linux.x86_64.zip"
  printf '%s  %s\n' d6e382fb531019f85630c1f485a561a0d20c4a2344b6c3847735cfee7da812aa "$archive" | sha256sum --check
  unzip -o "$archive" -d "$engine_dir"
fi
ln -sfn "$engine_dir/Godot_v${version}-stable_linux.x86_64" "$HOME/.local/bin/godot"
git -C "$root" lfs install --local
git -C "$root" lfs pull
"$engine_dir/Godot_v${version}-stable_linux.x86_64" --headless --path "$root" --editor --import --quit
printf 'Ready. Run: %s --path %s\n' "$HOME/.local/bin/godot" "$root"
