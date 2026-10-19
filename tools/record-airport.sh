#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
engine="${GODOT:-godot}"
mkdir -p "$root/artifacts"
args=(--path "$root" --audio-driver Dummy --rendering-method gl_compatibility --resolution 1280x720 --fixed-fps 24 --write-movie "$root/artifacts/airport-baggage.avi" -- --airport-tour)
if [ -n "${DISPLAY:-}" ]; then
  "$engine" "${args[@]}" 2>&1 | tee "$root/artifacts/recording.log"
else
  LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s '-screen 0 1280x720x24' "$engine" "${args[@]}" 2>&1 | tee "$root/artifacts/recording.log"
fi
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["passed"],d' "$root/artifacts/airport-playtest.json"
ffmpeg -hide_banner -loglevel warning -y -i "$root/artifacts/airport-baggage.avi" -c:v libx264 -preset fast -crf 22 -pix_fmt yuv420p -c:a aac -b:a 96k -movflags +faststart "$root/artifacts/airport-baggage.mp4"
ffmpeg -hide_banner -loglevel error -i "$root/artifacts/airport-baggage.mp4" -f null -
printf 'Actual engine recording: %s/artifacts/airport-baggage.mp4\n' "$root"
