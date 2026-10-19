# Checked Chaos — airport baggage greybox

Branch from the verified revolving-sushi foundation, preserving its Godot 4.4.1 runtime, first-person controller, template lobby/readiness and disconnect guards. The sushi concept remains available on its own branch and as an explicit scene.

## Required playable loop
- Bags automatically arrive on a straight conveyor, pass an actual scanner tunnel and queue for inspection without falling off-screen.
- Different bag colors, sizes and types; readable flight tags and routing rules. Scan -> inspect -> carry -> route to the right flight/security/biosecurity/safeguarding destination.
- Pick up/drop bags and individual contents; open bags. Approved locks use the key; non-approved locks require large pliers. All interactions have server-owned range/ownership validation.
- Narcotics seizures; bonus catches for fruit, vegetables and seeds; legal joke items (dildo/vibrator props) are not treated as contraband.
- Human-trafficking encounters are non-graphic adult safeguarding/rescue cases. Escalate to a rescue team; never treat people as collectible contraband or a joke.
- A dog follows/can be called, barks near suspicious baggage, and can be carried and placed on the conveyor. A fictional harmless training scanner produces a 'VERY GOOD BOY' scan. No animal injury.

## Endgame depth
Airport funds and reputation come from correct sorting and seizures, not seeded demo money. Milestone contracts award once-only grants. Buy scanner clarity/speed, dog training, evidence handling, a biosecurity lab, intake capacity and a terminal expansion. Terminal expansion requires successful inspections plus funds and unlocks a real third flight/oversize contract, visibly changing the room and incoming manifests. Maintain these benefits across shifts.

## Geometry/input
A straight belt runs X=-8..8, Z=-2, Y=1.1; scanner around X=-1.2; manual inspection desk in front; tools, evidence, upgrades and routing bays around the operator floor. Primitive meshes only. WASD/mouse first-person controls; context E, 1/2/3 hands/key/pliers, O open, I take/return contents, G throw bag / gently place items or dog, Q gently drop bag, K call dog, TAB airport upgrades, N next shift, ESC cursor/menu. The HUD presents contents/X-ray only when legitimately scanned/opened.

## Delivery gates
1. Deterministic model tests for every named mechanic and progression prerequisite.
2. Actual first-person input-driven playtest demonstrating arrival, X-ray, approved/foreign lock tools, carrying and opening, legal adult props, narcotics, organics, rescue, dog alert/pickup/scanner, earned-money upgrades and a newly unlocked route.
3. Real ENet co-op plus disconnect checks; no runtime errors hidden by passing process exit codes.
4. Record actual Godot frames, inspect decisive screenshots, decode/probe the MP4 and deliver it. Identify automation and greybox limitations.
5. Independent review, commit/push `airport-baggage`, verify exact remote SHA. Keep engines/caches/large intermediate recordings out of Git.
