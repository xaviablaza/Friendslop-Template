# Belt Behaviour — revolving-sushi graybox

## Scope
A playable first-person Godot 4.4 graybox built on Friendslop Template. Preserve the existing ENet/lobby/scene-management systems. Use primitive geometry, color-coded sushi, signs and a readable HUD rather than production assets.

## Loop
1. Prepare salmon, tuna or cucumber sushi at the matching station.
2. Carry a limited tray to the circular conveyor and load plates.
3. Customers automatically take matching plates as they pass; wrong dishes continue around.
4. Earn money, collect the dirty return at the washer, and replenish clean plate stock.
5. Remove stale plates, purchase real handling/preparation upgrades, and advance shifts.

## Implementation order
- Install pinned Godot 4.4.1 plus existing bundled GUT; import and run the template.
- Add a deterministic server-owned simulation, focused GUT coverage, 3D graybox room, first-person controls, conveyor and HUD.
- Connect solo and co-op through the template; retain the original 2D demo as an explicit scene.
- Exercise the actual game, record a real rendered gameplay walkthrough, and save repeatable verification commands/results.
- Review the diff, commit to `revolving-sushi`, and verify the published branch.

## Acceptance
- Launchable from the repository main scene; documented solo/host/join controls.
- Sushi preparation, carrying, belt travel, correct-customer purchases, washing and upgrades work.
- Tests and runtime log establish the exercised behavior; recording is actual engine output, not a mockup.
- No engine binaries, dependency caches or secrets committed.

## Boundaries
Graybox only: no final art/audio, Steam integration, persistence or production anti-cheat. Co-op verification and automated recording inputs must be reported explicitly rather than implied to be human play.
