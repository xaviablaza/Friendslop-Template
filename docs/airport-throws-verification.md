# Weighted baggage throws — execution evidence

Base: `9bc9b819dfcc461c951100bcf702a2417d625763`, branch `airport-baggage`. This extends, rather than replaces, the earlier airport walkthrough.

## Executed

- Godot 4.4.1 / GUT 9.4.0: **139/139 tests, 834 assertions**. New throwing coverage: **19 tests, 242 assertions**. Existing 120 tests remain green.
- Full two-process **normal-speed headless** throwing test passed: **133 host checks, 39 client checks**, three ground throws and six airborne catches.
- Full simultaneous two-window **rendered** test passed: **133 host checks, 39 client checks**, no runtime/script errors. Real ENet peer IDs were **1** and **615272257**. Every 8/16/28 kg bag was caught once by each player, with server-recorded bag-base heights from **0.917 m to 1.789 m** above the floor. No floor pickups were counted as catches.
- Matched-aim throws settled at horizontal player-origin distances of approximately **14.81 m / 7.34 m / 3.63 m**, respectively. These are final resting distances including slides/bounces and room bounds, not launch-to-first-impact ballistic ranges. The model separately records first-impact distance.
- Actual controls supplied naturally arriving bags; no bag spawns, position teleports, seeded currency, altered catch radius or manufactured network results were used. Camera aiming and collision-aware character movement were automated.
- The existing airport solo tour still passed **124 checks** with six handled bags and its earned-money upgrade loop.
- Existing airport two-peer ownership/routing/dog-release and host-loss checks passed. Existing sushi co-op and host-loss checks also passed; all four network regression sessions had no runtime errors.
- Full GUT still emits its documented inherited peer-manager negative-path diagnostics and shutdown resource warnings. These are not present in the new gameplay session logs; suite result is 139 passed, exit 0.

## Visible implementation

- **G**: weight-dependent throw. **Q**: gentle placement. **E**: catch/pickup. G never throws the dog or individual contents.
- 8/16/28 kg loads; heavier loads fly more slowly/less far and slow walking. Shared gravity, rotation, impact/bounce, friction and settling are host-owned.
- Empty-hand/range/airborne checks and atomic ownership; serialized flight/catch state and safe disconnect release.
- Real yellow silhouette hulls while off the conveyor, including held, airborne and grounded bags; original bag colors remain visible. Returning to the belt removes the outline.
- Centered first-person bags supported by both visible gloved hands/forearms; distinct remote worker avatars and two-handed carry poses.

## Recording

`artifacts/airport-bag-throws.mp4` is a silent **1920 × 540, 24 fps H.264** simultaneous capture of both actual game windows. Automated input is labeled in-game. **84.583333 seconds**, **28,470,664 bytes**. SHA-256:

`3146b0598f21fb627d5fd369f8239c146c8d948848a2b454c05fb7bc0f5cf59d`

The software-rendered two-window capture uses `--time-scale 0.5` for both processes to avoid CPU-rendering stalls consuming short catch windows. The delivered MP4 is normalized back to normal gameplay speed, without motion interpolation or reconstructed animation; original half-speed capture remains `artifacts/airport-bag-throws-capture.mp4`. The independent headless full test ran at ordinary simulation speed. Normal-speed rendered trials exposed timing sensitivity under CPU capture load; this is not an Internet-latency or performance certification.

Full MP4 decode and ffprobe succeeded. Encoded contact-sheet frames and the recorded hand/outline/catch states were inspected. Footage, source captures and both JSON reports are ignored under `artifacts/` and delivered separately rather than committed.

## Reproduce

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-airport-throws.py
python3 tools/test-airport-throws.py --record --time-scale 0.5
python3 tools/test-airport-network.py
python3 tools/test-sushi-network.py
```

`--quick` is a focused light-bag regression only, not the full three-weight acceptance sequence. Test transport uses **17127/UDP**; ordinary co-op remains **7000/UDP**. Requires Xvfb and ffmpeg for recording. This is local two-player greybox evidence, not production anti-cheat, Steam, larger-group or Internet/NAT validation.
