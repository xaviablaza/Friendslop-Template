# Airport expansion: current playable rules

This supersedes the mechanics in the `0792ebf` gameplay baseline and its historical videos/reports. It describes the expanded `airport-baggage` branch. The primitive art, fictional inspection rules and local ENet transport remain prototype-grade.

## Play and controls

Launch `godot --path .`. Dismiss the splash, then choose solo, host or join. Settings apply master audio volume, mouse sensitivity and fullscreen, and persist locally. Controls and the previous sushi concept remain accessible. Solo explicitly uses Godot's offline multiplayer authority.

- WASD/mouse: move/look; Shift: sprint; Ctrl: crouch; Space: jump. Crouching changes the collision capsule and camera; an obstructed ceiling prevents standing. Sprint/jump consume authoritative stamina; injury slows movement.
- E: context use/pickup/catch. 1/2/3: hands/key/pliers. Equip the appropriate tool and use E on a locked bag.
- During a lock challenge, enter the displayed 1/2/3 sequence; Space also enters 1 rather than jumping. Approved-key challenges allow seven seconds and three inputs; pliers allow nine seconds and four inputs. Wrong input or timeout consumes the attempt. Foreign locks require pliers.
- O: open; C: close; R: relock using a seal. Opening marks the bag inspected; closing does not erase learned information.
- I: open/close the scrollable item browser. Select any available item, select another nearby open bag and repack it there. Both ends remain server-validated.
- G: throw a held bag/item, or give the dog a capped harmless cartoon hop. Q: gentle drop. Animal carriers and shared heavy bags cannot be thrown.
- H: join/leave a heavy carry; K: call the dog; P: cycle follow/patrol/stay; F: enlarge X-ray.
- TAB near development: upgrades; 1–6 buy in that menu. N: host starts the next shift after shift end. ESC closes menus/releases the cursor. The airport continues running while UI is open.

## Random truth, items and routing

Normal play generates seeded randomized bag appearances, locks, shell masses and contents. Suspect fictional training props can be genuine restricted goods or cleared legal lookalikes. Truth is sampled on the host; it is not resampled by opening, moving or repacking an item. Explicit deterministic fixtures exist only for opted-in tests/tours.

An unopened scan is a neutral clue, not a verdict. Before inspection, recipient snapshots omit hidden truth and RNG continuation, redact bag classification, and replace concealed item identities/labels/categories with unknowns. The host's UI follows the same inspection rule. After inspection, ordinary item information is shared; hidden RNG/truth metadata is still omitted.

Current catalogue classifications:
- Legal: clothing, socks, documents, electronics, books, snacks and legal adult personal props.
- Narcotics: fictional violet-dust and moon-tablet training packets.
- Organic: fictional fruit, vegetables and seeds.
- Weapons, explosives and dangerous: fictional weapon props, inert training blocks and glow-canister props.
- Wildlife: a protected fictional cloud-lizard carrier.
- Customs: fictional museum relics and glass-gem collections.
- Pet: cats and rabbits in ventilated carriers with visible animals.

The former adult silhouette is no longer generated or rendered. The internal `safeguarding` classification is retained only for legacy compatibility, not as a current catalogue entry.

Every bag must be scanned before routing. Restricted bags must have been inspected. Routing uses what is *currently inside*, so removing/repacking items changes both mass and required destination:
- Pets/wildlife → animal-care handoff (the existing `rescue` route identifier).
- Narcotics/weapons/explosives/dangerous/customs → security.
- Organics → biosecurity.
- Remaining legal bags → tagged flight, or oversize for large bags after terminal expansion.

Narcotics, organic and customs items can be secured as evidence. Only weapons/explosives/dangerous props use the specialist-disposal station. Disposal consumes the carried object once and awards $10; this is an abstract fictional action, not a real handling procedure. Legal belongings cannot be seized.

## Physical work and care

Bag mass equals shell mass plus each item whose location is still inside that bag. Taking, repacking, seizing or disposing of an item updates the appropriate mass and classification without duplicating it. Impacts damage bags; fast objects can cause non-graphic operator injury. Visit the first-aid station to restore health.

Host simulation resolves airborne travel, collisions, floor settling and bag-to-bag separation/stack support. These are simplified greybox physical piles, not soft-body luggage. Bags above 24 kg wait for a second nearby empty-handed operator in co-op. Helpers must stay within reach; leaving, separating or disconnecting safely releases both carriers. Solo has a slow drag fallback. Heavy/shared baggage cannot be thrown.

The tool station restocks key/pliers durability and three seals for $12. Lock attempts consume tool durability; resealing consumes a seal. The dog-care station provides carried food/water portions, capped at three of each. Supplies are consumed when used; collection is replenishable at the station.

Carrier animals have hunger/thirst and must be fed/watered before handoff when they need care. Open the carrier, collect food/water from the same dog-care area, then use the browser's pet-care button. One food and one water portion are consumed together. Animals are never injured, seized or thrown as loose items.

The detection dog has hunger/thirst, rest, XP and stay/follow/patrol modes. Feeding and watering consume portions; resting is available at its station. Scent has true/false positives and misses, influenced by care, training and kennel. An alert is a reason to inspect, not proof. Each completed harmless training scan awards XP once; the $35 kennel upgrade additionally requires at least one completed dog scan. Patrol/follow uses bounded room waypoints and collision sweeps.

## Economy and continuation

Correct routes earn shared funds/reputation; wrong routes penalize funds/reputation and leave the bag held. Once-only legal/organic/animal-care milestones add grants. Scanner, kennel, evidence, biosecurity, intake and terminal upgrades remain. Terminal expansion costs $120 and requires five handled cases/five reputation; it opens flight C and oversize. Shift continuation retains airport state in memory. There is no campaign save, Internet matchmaking guarantee or production anti-cheat; menu settings alone persist to disk.

## Repeatable checks

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/airport -gexit
godot --headless --script res://scripts/airport/airport_presentation_smoke.gd
godot --headless --script tools/check-airport-menu-controller.gd
python3 tools/test-airport-network.py
python3 tools/test-airport-expansion-throws.py
```

Focused scene checks use explicit fixtures/positioning and real key/button events; they are not human playtests or recorded gameplay. Model/ENet transport checks and actual rendered presentation are different evidence gates. Headless checks do not verify captured mouse movement or visible fullscreen behavior. No new expansion video is claimed.

Source: `airport_catalog.gd` (catalogue/truth), `airport_simulation.gd` (inspection, inventory, economy, snapshots), `airport_systems.gd` (care, physical work, stamina), `airport_game.gd` (authority/input), `airport_hud.gd` (browser/lock/station controls), `airport_room.gd` (geometry/props), `airport_chef.gd` (movement), and `scenes/menu/` (splash/settings).
