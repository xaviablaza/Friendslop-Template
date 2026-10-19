# Revolving-sushi graybox — execution evidence

Engine: Godot **4.4.1.stable.official.49a5bc7b6**, bundled GUT **9.4.0**. Linux rendering uses Compatibility/OpenGL and Mesa llvmpipe on an isolated Xvfb display. No proprietary art assets or additional Godot plugins were added.

## Results

- Pinned-engine bootstrap and editor import: exit **0**, no import/parse errors.
- Full GUT suite: **91/91 tests**, **309 assertions**, exit **0**. Includes **30 new simulation tests / 147 assertions**.
- Actual rendered automated playtest: **54 passed checks**, **8 customer purchases**, **$42 remaining** after buying the **$24 three-plate tray**, washing returns and advancing to **shift 2**. No seeded money.
- Real two-process ENet gameplay check: **9 passed checks** across host/client. Includes template lobby and scene readiness, remote station-range rejection, preparation/loading, shared earnings/dirty returns and client-disconnect cleanup.
- Real two-process host-loss regression: **10 passed checks**. Client actions arriving during the disconnect fade are ignored, gameplay networking stops, and both peers return cleanly to the main menu. Both network runs have **no runtime errors**.
- `git diff --check`, shell syntax checks and Python syntax check passed.

## Video

`artifacts/revolving-sushi.mp4` — actual Godot Movie Maker gameplay, automated inputs, silent. Delivered separately; generated recordings remain ignored rather than adding large video objects to source history.

- H.264 / 1280 × 720 / 24 fps
- 3,018 frames / 125.75 seconds / 15,246,399 bytes
- SHA-256: `3eb8a4044aef902350269823ff7ec261571cc3a6bc3378b2c9c06eec06046aa4`
- MP4 fully decoded successfully with ffmpeg. Rendered overview, carrying, purchasing, washing and shift-result screenshots were inspected.
- The final rendered run emitted no engine errors; its only engine warning was Xvfb's unsupported V-Sync-mode change.

## Reproduce

```sh
bash tools/setup-godot.sh
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-sushi-network.py
bash tools/record-sushi.sh
```

The network verification runner is Linux-specific (`/proc/net/udp*`) and uses private ports **17107/UDP** and **17108/UDP**. Normal play retains **7000/UDP**. Machine-readable reports and full logs are in ignored `artifacts/`.

## Known boundaries

- Graybox, not final art/audio; no saved progression, Steam matchmaking, production anti-cheat or Internet/NAT testing. Verified co-op is two local ENet processes; the template supports additional peers but larger groups were not exercised.
- The inherited GUT negative network tests print engine diagnostics and shutdown resource warnings despite passing. A separate clean worktree at baseline `96fc4b9` reproduced those diagnostics with **61/61 tests / 162 assertions**. They are not hidden as a clean runtime result; the new standalone/co-op gameplay recordings and regression logs are checked separately.
- The $80 shift target is advisory. The recorded shift intentionally demonstrates the loop and upgrades, not a perfect score.
