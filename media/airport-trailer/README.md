# Checked Chaos: expanded airport trailer

The delivered **2:24, 1080×1920, 24 fps** feature trailer is [production/airport-baggage-expanded-trailer-vertical.mp4](production/airport-baggage-expanded-trailer-vertical.mp4). Video and review sheets use the repository's existing Git LFS rules. Run `git lfs pull` after checkout.

Recorded gameplay revision: `663cb3a2fc8f61a664f3b1075cfd86485ad9cf37`.

Final MP4 SHA-256:
```
610f9f831067f9546af17ce83d47a0fb028f093f635af3553275daf684955284
```

## What is included

- Exact capture drivers, compositor, original synth-score code and final frame-quantized storyboard.
- Five normalized editorial-input MP4s plus the delivered final MP4, so the edit can be rebuilt without re-recording the game.
- Capture assertions, catalogue-fixture disclosures, source hashes, feature-to-timecode mapping and final encoded review sheets.
- Two real ENet perspectives for the 32 kg shared carry and two-way 8 kg airborne relay, not duplicated actors. Capture ran at equal 0.5 simulation speed and was normalized to normal gameplay speed; the recorded session and a separate normal-speed execution passed.
- The co-op capture driver's isolated-worktree startup patch and source copies. This patch is archived here, **not applied to ordinary gameplay**.

The 41-shot edit maps all 37 requested expansion features to footage. Titles and player labels use external canvas; gameplay detail insets use the same live frame. Automated inputs and scripted scenarios are visibly disclosed. Rare catalogue items and positions/masses were staged; money, handoff rewards, XP, healing, tool consumption, physics and catch outcomes came from actual gameplay.

Raw AVI files, raw half-speed desktop captures, caches, generated per-shot encodes and temporary image probes remain ignored locally. They are not required to rebuild the final edit from the included normalized inputs.

## Verify and rebuild the edit

Dependencies: Python 3.9+ with Pillow, FFmpeg/ffprobe, and DejaVu Sans at the font paths used by the compositor. Capture itself used official Godot 4.4.1, Xvfb and Mesa software OpenGL. No music model or externally licensed song was used; the score is original deterministic synthesis.

From the checkout root:

```sh
python3 tools/prepare-airport-trailer.py --verify-only
python3 tools/prepare-airport-trailer.py
python3 artifacts/airport-trailer-rebuild/production/make_storyboard.py
python3 artifacts/airport-trailer-rebuild/production/build_trailer.py \
  artifacts/airport-trailer-rebuild/production/storyboard.json
python3 artifacts/airport-trailer-rebuild/production/verify_trailer.py
```

The preparation command verifies each archived file against `manifest.json`, copies to a **new ignored directory**, and adapts workstation-specific paths only in those disposable copies. It refuses to overwrite an existing workspace; use a new `--output artifacts/<name>` for another rebuild. Original archived scripts/evidence are preserved byte-for-byte, including their historical absolute paths.

The verification script checks complete decode, video/audio format, expected frame count, audible non-clipping PCM, feature coverage, and extracts every scene at an exact final-file timestamp. Visual review still requires inspecting those images and decisive action/outcome frames; a successful render alone is not visual evidence.

## Capture source notes

- `inspection/`: random arrival, hidden truth, locks/durability/seals, browser/repacking, taxonomy/disposal, restock, piles/damage, item throwing and injury/first aid. `capture.gd` and `supplement.gd` are independent scripted takes combined by `verify.py`.
- `care/`: visible cats/rabbits, shared food/water, dog rest/follow/patrol/scent/harmless toss/scanner XP, earned kennel/scanner/terminal upgrades and flight-C handoff.
- `movement/`: first-entry splash, actual menus/settings, normal sprint/crouch/jump and authoritative stamina. Preferences used an isolated capture config.
- `coop/provenance/`: scripts intended for installation into an isolated checkout at the recorded revision. Place `airport_coop_capture.gd` in `scripts/airport/`, the two Python files in `tools/`, apply the archived startup patch, import, and run the capture/normal-speed commands recorded in `provenance.json`. Do not apply the capture hook to the normal branch merely to re-edit existing footage. The archived frame selections are tied to the original take; a new recording needs new event/frame alignment.
- `production/`: editable narrative, original audio composition, 37-feature coverage plan, final storyboard, encoded review sheets and verification evidence.

The historical `tools/test-airport-throws.py` formatting change is retained separately. Its legacy validator expects 28 kg; current expansion acceptance uses `tools/test-airport-expansion-throws.py`, and this trailer's new shared-carry/relay capture uses the archived dedicated co-op driver.
