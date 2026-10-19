# Airport baggage — verification evidence

Foundation: `9ccf880b0af02e3c212950b62091c7c35a0d305e` (`revolving-sushi`). Separate `airport-baggage` worktree/branch; the prior branch is preserved.

## Actual execution

- Godot **4.4.1**, GUT **9.4.0**; editor import completed without parse/import errors.
- **120/120 tests passed, 592 assertions**. Airport-specific coverage is **29 tests / 283 assertions**; the inherited sushi/template tests remain green.
- **124 checks passed** in the actual rendered, input-driven walkthrough. It handled **6 bags**, seized narcotics, recovered organics, completed an adult safeguarding rescue, carried the dog through the fictional training scanner and used the live dog scan display.
- The player earned **$259**, bought terminal/scanner/dog-training upgrades for **$200**, then ended with **$59** and **airport level 2**. No currency or progression was seeded into the walkthrough. The newly unlocked flight-C arrival was actually inspected and routed through the new bay.
- Real two-process airport ENet gameplay: **14 passed checks**. Server-owned range rejection, key/open/carry ownership, shared routing rewards and dog release on client departure were exercised.
- Real airport host-loss regression: **10 passed checks**, including a carried bag, actions during disconnect fade, main-menu return and peer cleanup. Both airport network runs had no runtime/script errors.
- The foundation's separate sushi co-op and host-loss regression runners were rerun and passed.
- Shell syntax, Python syntax and `git diff --check` passed.

## Video

`artifacts/airport-baggage.mp4` is actual Godot Movie Maker output with automated movement and normal key events—not a mocked animation or a human playtest. It includes the procedural dog bark.

- H.264 video + AAC audio; **1280 × 720**, **24 fps**.
- **3,407 frames**, **141.958333 seconds**, **27,228,695 bytes**.
- SHA-256: `d9e95533c9eecc8d981012f1ce33cf1205bed549b1499e4befbc752c8bcbf838`.
- Full MP4 decode succeeded; the audio track has non-silent dog barks (peak **−17.6 dB**).
- Inspected the encoded video contact sheet plus actual overview, X-ray, legal-item, narcotics, organic, safeguarding, dog-scan, upgrade and expanded-airport frames. The final dog shot visibly shows both the physical dog on the belt and its live training silhouette.
- No engine errors in the rendered run. Xvfb reports its unsupported V-Sync-mode change, which does not prevent capture.

## Requested-mechanic coverage

- Automatic straight-belt arrivals, real scanner queue, pause/resume console, flight-tag routing.
- Bag color, type and size differences in state and meshes; actual oversize arrivals generated after terminal expansion.
- Approved-key and foreign-lock/pliers behavior; opening lids and inspectable contents.
- Bag/item pickup, floor placement, source-bag return and secure evidence deposits.
- Legal non-graphic dildo/vibrator props are not seized as contraband.
- Narcotics seizures; distinct fruit, vegetable and seed props with biosecurity rewards.
- Non-graphic adult trafficking/safeguarding case with a dedicated rescue outcome; people are not collectible inventory items.
- Dog alerts, procedural barking, calling/carrying/dropping, safe conveyor traversal and a fictional non-ionizing training scan.
- Functional scanner, dog, evidence, bio-lab, intake and terminal upgrades; once-only milestone grants; genuine unlocked routes/contracts, retained between shifts.

## Reproduce

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-airport-network.py
bash tools/record-airport.sh
```

Reports, screenshots and large recordings are ignored under `artifacts/`; the video is delivered separately. Normal co-op uses **7000/UDP**, airport test pairs use **17117/17118**.

## Limits

Greybox graphics and game-specific fictional inspection rules; no disk saves, Steam matchmaking, production anti-cheat or real customs/legal advice. Two local peers were verified, not larger groups or Internet/NAT behavior. All upgrades are unit-tested, while the video purchases and demonstrates terminal, scanner and dog training. Inherited GUT negative network tests/shutdown warnings remain as documented in the foundation's `docs/verification.md`; new gameplay/network logs are checked independently.
