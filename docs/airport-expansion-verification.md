# Airport expansion verification

Runtime: Godot 4.4.1 stable official, Linux headless. Branch: `airport-baggage`. This records the expanded source, not the historical videos. No new video or visual-QA loop was requested or produced.

## Executed acceptance

- Headless editor import: passed; no script/import errors.
- Airport GUT: **90/90 passing**, **2,360 assertions**, no failures, risky tests or runtime errors.
- Full project GUT config: **181/181 passing**, **2,669 assertions**, no assertion failures or script errors. See inherited diagnostics below; this is not a claim that full-suite stderr is empty.
- Actual scene/input presentation check: **45 passing checks**. Covers key/tool/lock inputs, browser exact-item selection and cross-bag repacking, close/relock, disposal/first aid/tool restock/animal-care station buttons, harmless dog/item throws, co-carry gating/release, hidden truth on host/recipient, visible carrier animals, and aisle clearance.
- Menu/controller: **36 checks, zero failures**. Covers splash, settings persistence, solo/host transitions, original sushi controller, normal sprint/crouch/jump, standing clearance, and authoritative stamina integration. Captured mouse movement and visible fullscreen are explicitly unverified on the headless display.
- `tools/test-airport-network.py`: actual host/client gameplay pair plus host-loss pair passed without runtime errors. Includes timed numeric-key locks, countdown, close/relock, recipient privacy, cross-bag repacking, earned shared funds, shared heavy carry and safe dog/drop/disconnect behavior.
- `tools/test-airport-expansion-throws.py`: normal-speed actual ENet peers, **133 host / 39 client checks**, six mid-air catches split across both peers and additive 8/16/23 kg fixtures. Measured ground travel decreases as mass increases. Objects above 24 kg intentionally require shared co-op carry and are not throwable.
- Updated automated airport tour: 145 checks, six resolved bags, earned upgrades and pet care; test-driver run at `--time-scale 3`, not a human playtest or video. Final post-review model/input/network checks above run independently of that accelerated tour.
- `git diff --check`: passed.

## Independent review regressions

Specification and final independent quality reviews approved the integrated implementation after both boundary fixes. All requested mechanics were found modeled and reachable through ordinary input/server action boundaries. Quality review found two important boundary defects; both were fixed with model and real-scene regressions:

1. Ending a shift mid-lock now clears active challenges without refunding tool use, so the lock modal disappears and normal **N** continues the session.
2. Physical piles now consider the real room collision sweep when settling support; bags remain on desks rather than sinking through them, while unsupported bag stacks still fall when their supporting bag is removed.

## Inherited full-suite diagnostics

The full project config emits five peer-manager/provider negative-test errors, an ObjectDB leak warning, and `19 resources still in use at exit`. The same signatures and resource count were reproduced in an isolated worktree at the unmodified baseline `0792ebfdf2cb925c104e6b02073ff39d0830923d`, whose **139/139 tests passed**. They are retained as existing template test/cleanup debt, not hidden or misreported as clean stderr. Airport-only and actual gameplay/ENet runs do not emit these diagnostics.

## Boundaries

Simplified rigid pile/contact handling, fictional categories/disposal and non-graphic injury; no animal harm. Two local ENet peers tested, not Internet/NAT support or production anti-cheat. Session progress remains in memory; menu preferences persist locally. Historical throw recording code and its uncommitted formatting work remain separate from expansion acceptance.

Commands and current rules: [airport-expansion.md](airport-expansion.md). Full suite: `godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit`.
