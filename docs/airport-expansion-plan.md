# Airport expansion acceptance and integration contract

Target: existing `airport-baggage` branch. Preserve pre-existing WIP (README, HUD title cleanup, throw harness, gameplay reference). No video requested; no visual-QA loop. Verify import, focused model and normal-input/network smoke behavior.

## Ownership
- Core: airport_simulation.gd, new airport_catalog.gd, core feature tests.
- Systems: new airport_systems.gd and systems tests only.
- Presentation: airport_game.gd, airport_hud.gd, airport_room.gd, presentation tests only.
- Movement/menu: new airport_chef.gd, scenes/menu/main_menu.gd, new splash/menu helper scripts and menu tests. Do not change SushiChef or project.godot.

## Shared API
Core creates `var systems = preload("res://scripts/airport/airport_systems.gd").new()`; calls `systems.initialize(self)` in _init, `systems.ensure_player(player)` after add_player, `systems.ensure_bag(bag)` after physics normalization; before normal act dispatch calls `systems.act(self,peer_id,action,target_id,extra)` returning null if unhandled, String otherwise. Before tick held synchronization calls `systems.update(self,step)`; replace legacy _update_dog with systems.update_dog(self,delta). Core calls `systems.impact(self,bag,speed)` at contact, `systems.remove_player(self,peer_id)` before disconnect drop. Systems stores persistent state only in player/bag/dog dictionaries, not helper fields. Core snapshot accepts/validates extended state including airborne dog/items, preserves truth server-only in recipient snapshots via `snapshot_for(peer_id)` and per-bag redaction; `snapshot()` remains full internal/test state.

Actions:
- Core: existing plus `close`, `relock`, `lock_input` (extra int 0..2), `restock_tools`, `dispose_item`, `feed_pet`; `return_item` accepts any open bag. `unlock` starts timed lock challenge with player.lock_game dictionary (bag_id, remaining, sequence, progress); lock_input resolves; key_durability/pliers_durability, food/water inventories, seals. Items mass_kg; bags shell_mass_kg/damage/carrier/pet dictionary {species,hunger,thirst,fed}; bag.mass_kg is shell plus contents currently location=bag. All catalogue categories: legal,narcotics,organic,weapons,explosives,dangerous,wildlife,customs,pet (safeguarding may remain legacy-only). Routes security/bio/rescue reuse rescue as animal-care. `dispose_item` only weapons/explosives/dangerous. `feed_pet` consumes carried supplies; feeding hungry pet required before route. Core exposes catalog taxonomy in AirportCatalog and seedable RNG via set_seed(int).
- Systems: `throw_item`, `throw_dog` extra {origin,direction}; `first_aid`; `take_food`, `take_water`, `feed_dog`, `water_dog`, `rest_dog`; `dog_mode` extra String follow/patrol/stay; `join_carry`/`leave_carry` id; `movement` extra {sprinting:bool,crouching:bool,jump:bool,moving:bool}. Player fields health,stamina,sprinting,crouching,food,water,carry_partner; dog fields hunger,thirst,xp,mode,follow_peer,patrol_index,velocity,flight_age. Bag fields carry_helpers array,damage. Heavy threshold 24kg requires helper in co-op (solo can slowly drag); primary player must wait for helper before movement/carry; helper disconnect/drop releases both. Systems supplies `carry_multiplier(sim,peer_id)`; core carry_speed multiplies by it. Physical piles use collision/resting separation in host state. No animal injury; dog toss gentle capped arc. Dog scan awards training XP once per scan and kennel requires scan count as well as earned money.
- Presentation stations constants: FIRST_AID_POINT=(7.7,1,0), DOG_CARE_POINT=(-7.5,0.5,0.5), DISPOSAL_POINT=(6,1,0). Tool restock at TOOL_POINT. Browser I toggles scrollable real contents selection, arbitrary repack via return button; do not expose hidden item categories/labels before opening. Keys C close, R relock, E starts lock and SPACE/1/2/3 enter sequence as appropriate; UI must show timer/sequence. H helper join/leave; P cycles dog mode. Station menus/buttons expose supplies/feeding/restock/disposal/first-aid. G throw held kind; Q gentle drop. All actions allowed through host-owned proximity/ownership boundary. Snapshot sends snapshot_for(id), never full host truth. Host physical dog navigation must use collision_query or safe room waypoints.
- Movement controller `class_name AirportChef extends SushiChef`, used instead of SushiChef by airport_game. Fields stamina (float), health (float), sprinting/crouching (bool), requested_jump (bool); airport_game reports moving/sprint/crouch/jump through movement action at bounded cadence and applies authoritative stamina/health back. Shift sprint, Ctrl crouch, Space jump with actual capsule/camera clearance. Preserve automated navigate()/face(). Menu: splash then solo/host/join/settings/controls/quit; automation flags bypass splash.

## Acceptance checklist
- [ ] Randomized seeded loot, hidden probabilistic truth, complete explicit taxonomy, dangerous-object disposal.
- [ ] Additive item mass, bag damage, item/dog throwing, injury + first-aid, physical piles, two-person heavy carry.
- [ ] Consumables/tool durability, timed lock minigame, explicit close + relock.
- [ ] Stamina, sprint, crouch, jump through normal controls.
- [ ] Free selection browser + arbitrary cross-bag repacking.
- [ ] Remove adult_silhouette from current runtime; pet carriers with actual visible animals and hunger/food/water care.
- [ ] Dog hunger, XP, patrol/follow, probabilistic scent, scan-gated kennel upgrade.
- [ ] Splash and usable menu system.
- [ ] Source and independent scope review, headless import and focused runtime/model checks.
- [ ] Same branch committed/pushed, exact remote SHA read back.
