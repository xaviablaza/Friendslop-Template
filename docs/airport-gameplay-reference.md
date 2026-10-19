# Airport Baggage
## Complete gameplay rules, actions, items and systems reference

> **Historical baseline reference:** the audit below is retained for `0792ebf` and its then-uncommitted presentation work. The expanded branch changes random generation, item weights, locks, repacking, animal care, movement and menus. Use [airport-expansion.md](airport-expansion.md) for current rules; do not treat the historical counts or restrictions below as current behavior.

**Status:** As-implemented greybox reference, not a speculative design pitch.<br>
**Audited:** 19 October 2026, UTC.<br>
**Branch:** `airport-baggage`<br>
**Gameplay baseline:** `0792ebfdf2cb925c104e6b02073ff39d0830923d`<br>
**Source scope:** Current local working tree. The README, recording tool and HUD have subsequent uncommitted presentation changes; the gameplay model/catalog/controller audited here are the current implementation. This document does not commit, deploy or change the game.

> The trailer is an edited showcase. This reference describes the actual rules—including shortcuts, limitations and edge cases that the trailer does not explain. Money amounts are fictional in-game dollars. Inspection classifications are fictional game rules, not customs, legal or animal-handling guidance.

[TOC]

## 1. What the game actually is

A first-person, shared-workspace airport baggage inspection and routing game. Luggage arrives automatically, queues on a straight conveyor, passes a training/X-ray scanner and waits for operators to resolve it. Players inspect, unlock, open, carry and route bags; optionally remove prohibited contents for evidence bonuses; use a detection dog; pass weighted bags between operators; and spend shared earnings on airport improvements.

The implemented units of play are:

- **One shared airport simulation**, usable solo or through the template's host/client lobby.
- **A four-minute simulated shift**, followed by a host-triggered continuation.
- **One carry slot per operator:** a bag, an individual item, or the dog—not all at once.
- **Four bag classifications:** legal, narcotics, organic and safeguarding.
- **Seven route bays:** five initially usable, two unlocked by expansion.
- **Six one-time upgrades**, three one-time milestone grants and two airport levels.
- **Three generated baggage weights:** 8 kg, 16 kg and 28 kg.

The current endgame is a more capable version of the same work loop, not a separate campaign or new map. There is no shipping release date, persistent campaign save, combat system or passenger simulation implied by this implementation.

**Sources:** S1 fields, `act`, `_buy_upgrade`, `next_shift`; S2 startup/interaction; S3 room construction.

## 2. The moment-to-moment and progression loops

### 2.1 Standard baggage loop

1. **Receive:** Let intake create a bag. Read its color, type, size and flight tag.
2. **Scan:** Keep the belt running until the bag completes its automatic scan.
3. **Control the queue:** Pause/resume intake as needed. Pausing intake does not pause the shift.
4. **Inspect:** Read the X-ray and dog clues. Use a key or pliers when the bag is locked. Open restricted baggage.
5. **Handle contents if useful:** Put the bag down, remove a restricted item, and deposit it at evidence for an additional reward. This is optional for routing; see §10.
6. **Carry or relay:** Move the bag yourself, or throw it to an empty-handed teammate. Weight affects travel speed and throw behavior.
7. **Resolve:** While holding the bag, aim at its correct route bay and press **E**. Dropping a bag into a bay is not enough.
8. **Earn:** Correct routing grants shared money and reputation. Newly satisfied milestones may grant extra money.
9. **Improve:** Buy upgrades at the development terminal. Expansion opens flight C and oversize routing.
10. **Continue:** When time expires, the host presses **N**. Existing baggage and progress remain.

### 2.2 Legal bags versus restricted cases

- Every routed bag must have been **scanned**.
- A **legal** bag may be routed while still closed and locked. Opening every legal bag is not mandatory.
- **Narcotics, organic and safeguarding** bags must also be **opened** before routing.
- A dog alert is not a routing verdict. A legal snack-containing bag can trigger an untrained dog.
- Seizing contents does not change the source bag's classification or destination.

### 2.3 Natural co-op roles

There are no enforced classes or role locks. Operators can divide work into intake/scanning, tool-assisted inspection, evidence transport, routing and bag relays. Everyone can use the same tools and shared dog. Successful ownership changes prevent two operators from carrying the same entity simultaneously.

**Sources:** S1 `act:219–233`, `_finish_bag:468–495`; S2 `interact:227–252`.

## 3. Starting state, shifts and pressure

### 3.1 New airport session

| Field | Initial value |
|---|---|
| Shared money / reputation | $0 / 0 |
| Airport level / day | Level 1 / day 1 |
| Shift time | 240 simulated seconds |
| Intake | Running |
| Arrival interval | 10 seconds while intake runs |
| Upgrades | All unpurchased |
| Milestone grants | All unclaimed |
| Counters | Zero handled, correct, mistakes, seizures, rescues, throws, catches, etc. |
| Operator equipment | Hands selected; carry slot empty |
| Dog | One dog on the floor, initially at `(0, 0.3, 0)` |

The first arrival is due immediately when the model updates. Subsequent IDs are allocated only when an arrival is actually admitted. A blocked arrival does not consume a bag ID.

### 3.2 What keeps running when intake is paused

**Stops:** belt baggage travel, bag scan progress, new arrivals and their countdown, dog belt travel and its training scan.

**Continues:** shift time, character movement, airborne bag physics, held-object synchronization, the floor dog's movement, alert checks and bark countdown.

The upgrade menu and released cursor are also **not simulation pauses**.

### 3.3 At shift end

At zero time, the model marks the shift finished, stops normal model updates and rejects all 23 model action verbs. It does not automatically start another shift, pay wages, remove clutter or fine the team for unfinished baggage.

The first-person controller/camera can still run; held-object positions are synchronized separately. An airborne bag can therefore remain suspended until the next shift resumes. Only the host can start that next shift with **N**.

### 3.4 Exactly what the next shift resets

`next_shift()` changes only: **day +1, time back to 240, finished flag to false, and the reopening message**.

It preserves money, reputation, upgrades, airport level, all counters, milestone flags, bag/item IDs, sorted and unsorted bags, loose/evidence items, carry ownership, tools, dog state, queue positions, partial scans, the arrival countdown, pending expansion arrival, belt pause state and throw/catch history. There is no automatic daily difficulty increase or regeneration of the first six cases.

**Persistence means within this running scene/session.** Leaving/recreating the game scene or restarting the process is not a supported disk-save/load workflow.

**Sources:** S1 fields:6–53, `update:581–608`, `next_shift:670–677`; S2 `_physics_process`.

## 4. Every normal player control

| Input | Exact normal-game behavior |
|---|---|
| **W / A / S / D** | Move relative to the character's horizontal facing. |
| **Mouse** | Look while the cursor is captured. |
| **Arrow keys** | Keyboard yaw/pitch look through the configured look actions. |
| **E** | Context interaction: pickup/catch, unlock, station use, routing, evidence deposit or shop. See §5. |
| **1** | Select hands when the shop is closed. |
| **2** | Select approved-lock key when the shop is closed. |
| **3** | Select large pliers when the shop is closed. |
| **O** | Open the selected, accessible, unlocked bag. It is not an open/close toggle. |
| **I** | Take the first eligible remaining content item, or return a held item to its selected open source bag. |
| **G** | Throw a carried bag; gently place a held item or dog instead. |
| **Q** | Gently place the held bag, item or dog near the player. |
| **K** | Call the floor dog to the player's present position. Not a persistent follow command. |
| **F** | Toggle enlarged HUD X-ray, globally; no console proximity requirement. |
| **Tab** | Open/close airport development when near its terminal. |
| **1–6 with shop open** | Purchase the corresponding upgrade, rather than selecting a hand tool. |
| **Escape** | Close the shop; otherwise release/recapture the cursor and disable/re-enable ordinary character input. |
| **N** | Host only: start the next shift once the current one has ended. |
| **Return-to-menu button** | Leave through the cursor panel or the template's scene/menu flow. |

Tool selection can be changed while carrying something, although the tool model is hidden while the carry slot is occupied. **1/2/3 do not require a visit to the physical tool rack.** Keys 4–6 do nothing as tool selections outside the shop.

Movement/look axes also have gamepad-stick bindings, but the airport's context actions are physical-key handlers. Do not treat this as a complete gamepad control scheme.

There is **no implemented jump, sprint, crouch, charged throw, stamina or player damage/health mechanic** in this controller. Space and Shift are not additional airport abilities.

**Sources:** S2 `_unhandled_input:174–219`; S4 controller; S6 HUD shop order; S7 input bindings.

## 5. Exactly what E does

E reevaluates the current aim target on the key event, rather than trusting the previous rendered-frame target.

| Aimed target | Result |
|---|---|
| Available non-airborne bag; hands selected | Try to pick it up. Requires empty carry slot. |
| Available bag; key or pliers selected | Try to unlock it with the selected tool. Even an already-unlocked bag is not picked up until hands are selected. |
| Airborne bag | Try to catch it, irrespective of selected tool; carry slot must be empty. |
| Loose floor item | Try to pick up that item. |
| Floor/belt dog | Try to pick up the dog. |
| Inspection desk | Place a carried bag on the desk. No automatic opening or sorting. |
| Scanner/belt target | Put a carried bag or dog on the belt. |
| Intake console while carrying bag/dog | Put that entity on the belt, rather than toggling intake. |
| Intake console otherwise | Toggle intake. Holding an individual item does not stop this toggle. |
| Tool rack | Cycle hands → key → pliers → hands. |
| Evidence station | Deposit an eligible carried restricted item. |
| Development terminal | Open the shop. |
| Route bay | Resolve the carried bag through that route, subject to scan/open/category rules. |

### 5.1 Aim and proximity

Normal aim candidates must be within **3.15 world units of the camera** and beat an alignment score of **0.76**. Bags, individual items and the dog get a **+0.035** score preference. Selection is by aim alignment, not necessarily the nearest object.

The server separately checks most actions within **3.2 units** of the authoritative player's feet plus `(0,1,0)`. Throwing, catching and nearby drops have additional rules. This targeting code does not raycast for occlusion; proximity/aim are not production-grade line-of-sight validation.

### 5.2 Which bag O and I select

Priority is: the bag you carry; otherwise an aimed bag; otherwise the remembered selected bag ID. Looking at bags updates that remembered ID. When no selection exists, the game can choose the first scanned unresolved bag. The selection and X-ray can therefore stay on a previously inspected bag after you look away.

Held bags are not ordinary aim candidates, but **O** can open your own held bag through this selection logic. To manipulate its contents, put it down first.

**Sources:** S2 `interaction_target`, `selected_bag`, `interact`, `handle_contents`, `_perform_action`.

## 6. Complete luggage catalog and generation

### 6.1 Shapes, sizes and palette

Four bag kinds exist: **0 cabin/suitcase, 1 duffel, 2 backpack, 3 trunk**.

| Size index | HUD name | Visual scale factor | Default mass |
|---|---|---:|---:|
| 0 | Small | 0.82 | 8 kg |
| 1 | Medium | 1.00 | 16 kg |
| 2 | Large | 1.30 | 28 kg |

The base case dimensions are `(0.68, 0.55, 0.45)` before size/kind factors. Duffels multiply width/height by `1.25/0.72`; backpacks by `0.75/1.16`; trunks multiply width/depth by `1.20/1.18`. These visual factors do not independently calculate mass.

| Palette index | HUD name | Actual color | Normally spawned? |
|---|---|---|---|
| 0 | Red | `#ab6264` | Yes |
| 1 | Blue | `#6284ab` | Yes |
| 2 | Green | `#6f957c` | Yes |
| 3 | Yellow | `#c5aa63` | Yes |
| 4 | Purple | `#977da9` | Yes |
| 5 | Teal | `#67a3a3` | No current arrival template uses it |

### 6.2 The first six bags, absent an expansion override

| Bag ID | Appearance | Flight tag | Initial lock | Classification | Mass |
|---:|---|---|---|---|---:|
| 1 | Red small cabin case | A / NW101 | Approved | Legal | 8 kg |
| 2 | Blue medium duffel | B / SE202 | Foreign | Narcotics | 16 kg |
| 3 | Green small backpack | A / NW101 | None; starts unlocked | Organic | 8 kg |
| 4 | Yellow large trunk | B / SE202 | Foreign | Safeguarding | 28 kg; **cannot be thrown** |
| 5 | Purple small cabin case | B / SE202 | Approved | Legal | **28 kg: electronics exception** |
| 6 | Green small backpack | A / NW101 | Approved | Organic | 8 kg |

Exact initial contents order:

1. **Bag 1:** Clothes → Adult personal item (dildo).
2. **Bag 2:** Suspected narcotics → Socks.
3. **Bag 3:** Fruit → Vegetable → Seeds.
4. **Bag 4:** Adult safeguarding silhouette — seek rescue → Travel documents.
5. **Bag 5:** Adult personal item (vibrator) → Electronics.
6. **Bag 6:** Seeds only.

All start closed and unscanned on the belt. Only `lock == none` starts unlocked. There is no random loot roll here.

### 6.3 After bag 6

The normal repeating sequence is **legal template 0 → organic template 2 → narcotics template 1**. It is not a repeating six-case sequence. IDs 7, 8, 9 use those three templates; 10, 11, 12 repeat them, subject to expansion overrides.

Later ordinary legal bags gain a third item: **Packaged snacks**, after Clothes and the dildo. That can produce the untrained dog's false positive. The initial safeguarding case, dense electronics case and seeds-only case do not normally repeat later in the session.

### 6.4 Expansion-generated bags

Buying terminal expansion sets a pending flag. The **next successful admitted arrival**, not an immediate extra spawn, becomes a red small legal cabin case, approved lock, flight **C / INT303**, with Clothes and the dildo, **8 kg**, intended for Gate C. It has no snack addition.

After that flag is consumed, level-2 arrivals with **ID > 6 and ID divisible by 4** become oversize contracts: red large legal trunks, foreign lock, flight C tag, Clothes and dildo, **28 kg**, intended for **Oversize**, not Gate C. This is ID cadence—not every fourth handled bag or every fourth bag after purchase. A pending forced international arrival takes priority over an oversize slot.

**Sources:** S1 `_try_arrive:532–579`, `ensure_bag_physics:257–267`; S3 bag geometry/palette; S6 manifest labels.

## 7. Every actual content kind

There are **12 generated contents kinds**, including one noncarryable safeguarding depiction. That means **11 carryable individual content kinds**, not 12 collectible objects.

| Kind identifier | Exact player-facing label | Classification | Handling |
|---|---|---|---|
| `clothes` | Clothes | Legal | Take, gently drop, pick up, return; cannot seize |
| `dildo` | Adult personal item (dildo) | Legal | Same legal handling; not contraband |
| `narcotics` | Suspected narcotics | Narcotics | Carry and deposit in evidence |
| `socks` | Socks | Legal | Normal legal handling |
| `fruit` | Fruit | Organic | Carry and deposit in evidence |
| `vegetable` | Vegetable | Organic | Carry and deposit in evidence |
| `seeds` | Seeds | Organic | Carry and deposit in evidence |
| `adult_silhouette` | Adult safeguarding silhouette — seek rescue | Safeguarding | **Never individually picked up; route whole bag gently to rescue** |
| `documents` | Travel documents | Legal | Normal legal handling; no separate document-verification minigame |
| `vibrator` | Adult personal item (vibrator) | Legal | Not contraband |
| `electronics` | Electronics | Legal | Establishes the bag's dense 28 kg mass at initialization |
| `snacks` | Packaged snacks | Legal | Later ordinary legal bags; untrained-dog false-positive trigger |

Items have IDs, a source bag, classification, location, position, owner and deposited flag. They **do not have individual mass fields** or their own ballistic/RigidBody simulation. Tools and the dog are not content kinds in this table.

### 7.1 Item-selection and conservation rules

- **I** takes the first eligible entry still located in the open selected bag, skipping safeguarding. There is no normal UI that selects an arbitrary item index.
- Returning that first item and pressing I again takes it again. To reach later entries, leave earlier ones on the floor or deposit eligible ones in evidence.
- A return must target the **same open, accessible source bag**. You cannot pack an item into a different bag.
- Dropped items are gently placed near the player; they do not tumble, bounce or get thrown by G.
- Seized items become evidence and cannot be retrieved through an implemented action.
- Taking, dropping and seizing retain the item's record in its original bag array. This matters for X-rays and classification (§9 and §17).
- Sorting a source bag with loose or held items is allowed. Those items can remain available, but returning them becomes impossible once their source is sorted/inaccessible.

### 7.2 Render aliases are not additional inventory

The renderer also accepts these **18 unused alias names**: `adult_at_risk`, `apple`, `carrot`, `clothing`, `document`, `drugs`, `laptop`, `orange`, `passport`, `person`, `person_at_risk`, `phone`, `safeguarding`, `sealed_brick`, `seed`, `shirt`, `sock`, `vegetables`.

They are not 18 additional spawnable item types. For example, the generated item is `electronics`, not separate laptop and phone loot. `snacks` is a real generated kind but uses the generic box mesh.

**Sources:** S1 `_try_arrive`, `act:167–218`, `get_item`; S2 `handle_contents`; S3 `item_mesh:366–434`.

## 8. Conveyor, scanning and capacity rules

### 8.1 Travel and scanning

A bag's normalized belt position is `t`; its model position is:

```text
x = -8 + 16*t
y = 1.14
z = -2
```

Belt speed is **0.065 t/second**, equivalent to **1.04 world units/second** along X. An unscanned bag reaches **t = 0.45** and spends **1.0 second** scanning; Scanner II changes newly started scan dwell to **0.3 seconds**. After scanning, bags advance until stopped by the queue or **t = 0.72**, approximately `x = 3.52`.

An unobstructed new bag takes about **6.923 seconds** to reach the scan threshold; about **12.077 seconds** to reach the queue end including base dwell, or **11.377 seconds** with Scanner II. These are derived ideal times, not guaranteed timings with a queue or paused belt.

There is no manual scan verb, charge or scan fee. An already scanned bag stays scanned after pickup, throw, opening, item removal and replacement. Partial scan progress survives pauses and handling. A scan already in progress is not instantly shortened when an upgrade is bought.

### 8.2 Queue limits

- Initial belt capacity: **6 bags**.
- Upgraded belt capacity: **10 bags**.
- Maximum active unsorted bags anywhere: **10**, unchanged by the upgrade.
- Active includes belt, held, table, floor and airborne bags; sorted bags do not count.
- Minimum belt separation: approximately **0.075 t**, or **1.2 world units**.
- Bags queue instead of falling off, disappearing or automatically sorting themselves.
- Failed arrivals stay due and retry when space is freed. No IDs are consumed while blocked.
- The dog does not count toward belt bag capacity/spacing.

A floor stockpile can therefore block future arrivals even when the belt itself is clear. Clearing/handling a bag is not the same as resolving it.

### 8.3 Three different scanner coordinates

Do not confuse these implementation points:

- Visual scanner/belt interaction marker: `(-1.2, 1.1, -2)`.
- Ordinary E replacement uses **t = 0.35**, giving model position `(-2.4, 1.14, -2)`.
- Automatic scan threshold **t = 0.45** corresponds to `x = -0.8`.

The desk has a similar distinction: interaction anchor `(2,1.1,0)`; resting bag support origin `(2,1.15,0)`.

**Sources:** S1 `_belt_space`, `_try_arrive`, `update`, `_move_bags`; S2 placement normalization; S3 station constants.

## 9. X-ray and inspection information

### 9.1 What the scanner reveals

The HUD uses a grid with simplified content silhouettes. Legal entries are cyan; other categories use amber. The basic scanner already exposes this category-color grouping—it is not a completely opaque mystery until an upgrade.

- Fruit: circular icon.
- Vegetable: triangle.
- Seeds: small dots.
- Adult personal items: abstract capsule-like icons.
- Safeguarding: non-graphic stick-person silhouette.
- Other contents: generic outlined rectangles.

Once a bag is scanned, short item labels are enabled if it is **opened OR Scanner II is purchased**. Labels are truncated to the first 15 characters in the small scan view. Opening a bag also exposes the full ordered contents list, with `[REMOVED]` beside entries no longer inside. Safeguarding adds an explicit response warning.

The physical 3D monitor draws miniature pale-cyan item meshes. Its view is a representation, not an actual penetrating physics/radiation simulation. Scanner II does not change those world-monitor meshes into detailed biological imagery.

### 9.2 Important stale-information behavior

Both X-ray presentations iterate the bag's complete retained item array, including removed/seized entries. Removing an item therefore **does not remove its X-ray silhouette**. The opened physical bag omits removed item meshes, and the inspected list can mark them removed.

The monitor also follows the remembered selected bag, rather than scanning whatever your camera happens to see. While the dog is on the belt, its training display takes precedence over the selected bag.

**Sources:** S2 `_update_xray:490–516`; S6 `XrayCanvas`, `refresh_airport:179–207`; S3 `item_mesh`/bag contents rendering.

## 10. Locks, opening and evidence

### 10.1 Lock states

- `none`: starts unlocked.
- `approved`: key or pliers can unlock it.
- `foreign`: needs pliers; the approved key fails.
- `cut`: result of using pliers; the bag stays unlocked.

Unlocking and opening are separate actions. The key preserves the lock type; pliers set it to cut. Tools are unlimited selection states: no durability, consumable count, acquisition cost or damage/fine for cutting an approved lock.

**O only sets opened to true.** Repeated O does not close the bag. Throwing a bag closes it automatically but preserves its unlocked and scanned flags. A restricted bag caught after a throw may need O again before routing.

### 10.2 Evidence deposits

Carry an individual **narcotics or organic** item to the evidence station and press E. Each deposit grants **$8**, or **$16** after the evidence upgrade, increments `items_seized`, marks the item deposited and frees your hands.

Legal items are rejected without being confiscated or fined; they stay in your carry slot. Seizure grants no reputation, handled-bag credit or organic/narcotics routed-bag credit by itself.

You do **not** have to remove every prohibited item to route a restricted bag. Routing checks scanned/opened and the bag's persistent classification, not search completeness. A narcotics bag stays a security case even after its narcotics item is secured.

**Sources:** S1 `act:149–233`; S2 `interact`, `handle_contents`; S1 `_throw_bag`.

## 11. Routing, success and mistakes

### 11.1 Route decision priority

1. Safeguarding → **Safeguarding response**.
2. Narcotics → **Security hold**.
3. Organic → **Biosecurity**.
4. Legal **size-index 2** bag, airport level 2 → **Oversize**.
5. Other legal bag → its tagged flight A, B or C.

The large safeguarding trunk is therefore a rescue case, not oversize. The legal oversize contract has a C tag but still belongs in Oversize. Weight alone does not select oversize: the small 28 kg electronics case remains a normal flight-B legal bag.

### 11.2 Destinations

| Route ID | Player-facing destination | Available at |
|---|---|---|
| `gate_a` | Flight A / NW101 | Level 1 |
| `gate_b` | Flight B / SE202 | Level 1 |
| `security` | Security hold | Level 1 |
| `bio` | Biosecurity | Level 1 |
| `rescue` | Safeguarding response | Level 1 |
| `gate_c` | Flight C / INT303 | Level 2 |
| `oversize` | Oversize / special handling | Level 2 |

### 11.3 Successful and failed routes

A success marks the bag sorted and hides it, clears ownership and carry slot, increments handled/correct/reputation by one, increments its category's resolved-case counter and pays the relevant reward/milestones. Its data and source-item records remain in the model.

A valid but wrong destination costs **$10**, money clamped at zero, and **−1 reputation / +1 mistake**. The bag remains in your hands so you can correct it. Repeated wrong attempts continue reducing reputation and adding mistakes, even at $0.

Missing scan/open/carry prerequisites or a locked level-2 destination are rejections, not wrong-route fines. No amount of physically tossing luggage into a colored bay resolves it: **hold it and press E on that bay**.

**Sources:** S1 `act:219–233`, `expected_route:497–508`, `_finish_bag:468–495`; S2 route gateway; S3 bays.

## 12. Carry weight, throws and catches

### 12.1 Exact masses and walking speeds

Mass is initialized from size, except any generated bag containing `electronics` is initialized at **28 kg**. It is not additive per item and is not recalculated as contents are removed. Individual items and the dog have no implemented carried mass penalty.

```text
carry_multiplier = clamp(1 - mass_kg/70, 0.55, 0.92)
loaded_walk_speed = 3.4 * carry_multiplier
```

| Load | Movement multiplier | Walking speed | HUD carry percentage |
|---|---:|---:|---:|
| Empty hands / item / dog | 1.0000 | 3.4000 units/s | No bag percentage |
| 8 kg bag | 0.885714 | 3.0114 units/s | 88% (truncated) |
| 16 kg bag | 0.771429 | 2.6229 units/s | 77% (truncated) |
| 28 kg bag | 0.600000 | 2.0400 units/s | 60% |

### 12.2 What G actually launches

A bag must be your own currently held bag. Safeguarding-category bags cannot be thrown. Aim comes from the camera; the host chooses origin and launch strength. There is no charge meter or client-chosen velocity.

```text
origin = player_feet + UP*1.25 + aim*0.55
velocity = aim*min(90/mass_kg, 9) + UP*(35/mass_kg)
angular_velocity = (2.4, 1.1, -1.7) * (8/mass_kg)
```

| Bag mass | Aim-direction speed term | Extra upward velocity |
|---|---:|---:|
| 8 kg | 9.0000 units/s | 4.3750 units/s |
| 16 kg | 5.6250 units/s | 2.1875 units/s |
| 28 kg | 3.2143 units/s | 1.2500 units/s |

The light-bag cap means the formula is not a perfectly uncapped constant horizontal impulse. Aiming up/down changes the launch vector; the table's upward column is the added boost, not necessarily total vertical speed.

Throwing closes the lid, releases the carry slot, marks the bag airborne/off-belt, resets flight age and records its thrower. Lock/unlocked/scanned/content state remain. G with a dog or individual item calls gentle placement, not ballistics.

### 12.3 Flight, impact and settling

- Shared gravity: **9.81 units/s²**; maximum flight substep **1/120 second**.
- Rotating, host-owned flight with room-boundary collision and scene edge-ray sweeps.
- Rebound coefficient: **0.2**.
- Floor/support contacts reduce lateral velocity toward zero at **7 units/s²**, and angular velocity toward zero at **12 radians/s²**.
- Small vertical rebounds below **0.45 units/s** are suppressed.
- It settles when squared total speed is below **0.0036** on a supporting contact.
- Minimum bag-root floor height: **0.04**. Model bounds: X −10 to 10; Z −4.9 to 6.
- Scene sweep radii by size: **0.23 / 0.30 / 0.39**.

This is a custom bag simulation, not a complete general-purpose rigidbody system. There is no modeled bag-to-bag collision pile, bag damage or player impact damage. Rendered held objects do not create a two-person joint-carry physics constraint.

The first ground impact records a landing event and horizontal launch-to-impact distance. Final resting position includes subsequent sliding/bouncing; it is a different measurement. Throw distance is not a fixed per-weight constant. Previously recorded matched throws settled roughly 14.81 / 7.34 / 3.63 units from the operator origin, but those are scenario measurements, not guaranteed ranges.

### 12.4 Exact catch requirements

Press E on a currently airborne bag with an empty carry slot. The bag must have:

- Root height **greater than 0.12**.
- Flight age **at least 0.08 seconds**.
- If catching your own throw, age **at least 0.35 seconds**.
- Passed both server-gateway and model reach tests.

The gateway checks at most **1.7 units** from player feet + `(0,1,0)` to bag root + `(0,0.2,0)`. The model then checks at most **1.65 units** using its stored player position + `(0,0.8,0)`. That stored position is feet + `(0,0.3,0)`, so its effective chest reference is feet + `(0,1.1,0)`. Both checks matter.

A successful catch atomically grants one owner, stops motion and increments the catch counter. It grants no money or reputation. Two operators cannot both own that bag; the demonstrated co-op mechanic is a **relay**, not a shared two-player carry.

Current airborne/height state is what matters: the code does not require that the bag has never landed, so an eligible rebound can also be caught. Low floor slides fail the height test. A ground pickup is not a catch.

### 12.5 Yellow outline

Yellow means **off the conveyor**, not suspicious, selected, opened or scanned. It appears on a removed/held/thrown/grounded bag, persists through handling and clears when the bag is put back on the belt. Sorted bags are hidden. Contents and text are excluded from the outline hull.

**Sources:** S1 `ensure_bag_physics`, `carry_speed`, `_throw_bag`, `_catch_bag`, `_flight_step`, `_record_landing`; S2 throw/catch gateway and collision sweeps; S5 outlines.

## 13. Player body, hands and presentation

The first-person character uses a **1.7-unit capsule**, radius **0.23**, centered **0.85 above its root**. Eye height is **1.62**, camera FOV **80°**, near clip **0.05**. Base movement speed is 3.4; character gravity is **18**, distinct from bag gravity.

Mouse sensitivity is **0.0025 radians/pixel**. Pitch clamps to **−1.15 to +1.15 radians**. Keyboard look speed is **1.7 radians/second**.

A held bag is centered at camera-local `(0, −0.56, −1.12)` with scale **0.90**, supported by two visible gloved hands, sleeves and hi-vis cuffs. Grip width follows bag kind/size. Mass adds a small visual bob; it is not stamina or a balance minigame.

The two-hand bag rig is not used for individual items or the dog; those use the generic side carry offset `(0.35, −0.42, −1.0)`.

Remote operators have primitive worker bodies, reflective vests, caps, hearing protection, gloves and a different two-arm carrying pose. Heavier carried bags produce a small torso dip. They are visual representations of peer positions, not passenger NPCs or additional collectible actors.

**Sources:** S4; S5 `make_hands`, `update_hands`, `make_crew`, `update_crew`; S2 `_held_transform`, `_update_avatars`.

## 14. The detection dog and scanner gimmick

### 14.1 Calling and carrying

There is one shared dog. K sets a **fixed goal at the player's present position**, and the floor dog moves toward it at **1.8 units/second**. It does not continually follow a moving player, navigate obstacles with a pathfinder or teleport to you.

E can pick up an available floor/belt dog with empty hands. G/Q gently place it nearby. E on the scanner/console while holding it puts it on the belt. It cannot be placed on the inspection table through normal rules.

There is no dog mass penalty, hunger, fatigue, health, injury or dog-throw action.

### 14.2 Alerts and false positives

The dog checks unresolved bags within **3 units**, or **6 after kennel training**. Narcotics, organic and safeguarding classifications are suspicious. Before training, legal snacks also make a bag suspicious.

These are deterministic checks—not a probabilistic success percentage or a random false-negative system. Bag position and proximity matter; held and airborne bags can qualify. A held dog can still alert.

Each bag alerts **once**, sets its alert flag, increments the dog's alert count, records the bag ID, posts a clue-not-conviction message and sets a **1.5-second** bark indicator. Multiple bags can alert in one update; the final qualifying bag becomes the displayed last alert. The client plays a short synthesized bark when its observed alert count increases.

Training suppresses future snack false positives and doubles radius, but does not clear old alert flags. The snack test sees retained item records, even if snacks have already been removed. Neither alerts nor scanner gags change a bag's legal classification.

### 14.3 Putting the dog through the scanner

The scanner is explicitly **fictional, harmless and non-ionizing**.

- Belt placement starts at t 0.35 in ordinary play.
- Dog motion uses the same 0.065 t/second belt speed, without bag queue spacing.
- At t ≥ 0.45 it gets a training scan **without the bag scan dwell**.
- The scan sets its scanned flag, increments `dog_scan_count` and displays **VERY GOOD BOY**.
- The HUD shows a stylized dog silhouette and the 3D monitor shows a training dog mesh. While the dog is on the belt, it overrides the selected bag's display.
- At t > 0.75 it automatically returns safely to the floor at `(4,0.3,−1)`.
- Placing it again resets its scanned flag, so the gag is repeatable.

With uninterrupted belt movement, placement-to-scan is about **1.538 seconds** and placement-to-exit boundary about **6.154 seconds**. There is no payment, reputation or kennel progression awarded for scans. Buying dog training is separate.

**Sources:** S1 `call_dog`, `pickup_dog`, `place_dog`, `_update_dog:639–668`; S2 dog rendering/X-ray/audio; S6 animal X-ray.

## 15. Money, reputation and milestone grants

### 15.1 Shared rewards

| Outcome | Money | Other progression |
|---|---:|---|
| Correct legal bag | $18 | +1 reputation; +1 handled/correct/legal |
| Correct narcotics bag | $32 | +1 reputation; +1 handled/correct/narcotics |
| Correct organic bag | $40; $60 with bio lab | +1 reputation; +1 handled/correct/organic |
| Correct safeguarding rescue | $50 | +1 reputation; +1 handled/correct/rescue |
| Restricted individual item secured | $8; $16 with evidence upgrade | +1 item-seized counter; no reputation/handled credit |
| Wrong valid route attempt | −$10, floor $0 | −1 reputation; +1 mistake; bag retained |
| Ordinary throw / catch / dog scan | $0 | Throw/catch/dog-scan counters only |

Examples excluding milestone grants:

- Narcotics bag plus its one evidence deposit: **$40**, or **$48** with evidence upgrade.
- Fruit/vegetable/seed bag plus all three deposits: **$64** at base rates; **$108** with both bio-lab and evidence upgrades.

There is no separate personal wallet. All operators share the economy and purchases.

### 15.2 Once-only contracts

| Grant | Trigger | Bonus |
|---|---|---:|
| Legal-handling milestone | 3 correctly routed legal bags | $30 |
| Biosecurity milestone | 2 correctly routed organic bags | $35 |
| Rescue milestone | 1 safeguarding rescue | $45 |

These grants are checked after correct routing, not after item deposit or shift end. Claimed flags survive later shifts; these are not daily repeatable contracts. The first rescue therefore normally pays **$95 including its grant**. There is no narcotics milestone.

No other implemented fine applies merely for cutting a lock, attempting to seize a legal item, doing a dog scan, throwing ordinary luggage, cluttering the floor or leaving baggage unresolved at shift end. Those may be design opportunities, not existing rules.

**Sources:** S1 `seize_item`, `route`, `_finish_bag:468–495`.

## 16. Every airport upgrade

Purchases require an active unfinished shift, enough shared money, the development-terminal gateway range and an unpurchased upgrade flag. Each is a single permanent session purchase; there are no repeat tiers, refunds or ongoing costs. Total cost of all six is **$355**.

| Shop key | Upgrade / model key | Cost | Exact implemented effect |
|---:|---|---:|---|
| 1 | Scanner II / `scanner` | $45 | New bag-scan dwell 1.0 → 0.3 seconds; short scanned-item HUD labels without opening |
| 2 | Dog training / `kennel` | $35 | Alert radius 3 → 6; suppress future legal-snack false positives |
| 3 | Evidence bench / `evidence` | $30 | Subsequent eligible deposits $8 → $16 per item |
| 4 | Biosecurity lab / `bio_lab` | $70 | Subsequent organic bag route reward $40 → $60 |
| 5 | Intake upgrade / `belt` | $55 | Arrival interval 10 → 7.5 seconds; belt capacity 6 → 10; shorten remaining arrival countdown to at most 7.5 |
| 6 | Terminal expansion / `terminal` | $120 | Airport level 2; Gate C and Oversize enabled; one forced C arrival and later eligible oversize contracts |

Terminal expansion additionally requires **at least 5 handled bags AND reputation at least 5**. Money alone is insufficient. The five cases do not need to be all legal or all the same category.

Important limits:

- Intake upgrade **does not increase belt travel speed**, reduce separation or raise the global active-bag cap beyond 10.
- Scanner II does not shorten a positive dwell timer already in progress or change dog-scan timing.
- Dog scans do not purchase/train the kennel.
- Evidence/bio upgrades are not retroactive payouts.
- Terminal expansion removes visual ribbons, changes wing/bay signs and enables routes/manifests. It does **not** construct a new larger physical room; the existing bays were already present. The ribbons were visual, not collision walls.

**Sources:** S1 `UPGRADE_COSTS`, `_buy_upgrade:450–466`, `_belt_space`, `_move_bags`, `_update_dog`; S3 `set_expanded:175–185`; S6 shop.

## 17. Worked legal/contraband-to-expansion loop

A representative sequence matching the recorded earned-money walkthrough:

1. Route the first legal case: **$18**.
2. Secure the narcotics item and route its bag: **$8 + $32**.
3. Route the fruit/vegetable/seed case: **$40**. Individual organic deposits are optional and omitted in this example.
4. Complete safeguarding: **$50 + $45 first-rescue grant**.
5. Route the dense legal electronics case: **$18**.

After these five successes: **$211**, five handled cases and five reputation, assuming no mistakes. That qualifies for terminal expansion.

Buy terminal **$120**, Scanner II **$45** and dog training **$35**: **$200 spent**, leaving **$11**. Resolve the forced international legal bag for **$18**, reaching three legal successes and its **$30** grant. Lifetime earned is then **$259**, with **$59 remaining** and airport level 2.

This is a six-resolved-case example, **not a promise that bag IDs 1–6 are those six resolved bags**. The seeds-only sixth arrival may still be queued while another generated ID becomes the international case. No money needs to be seeded into this loop.

**Sources:** S1 reward/grant/purchase functions; the existing recorded airport walkthrough/report. Arithmetic derives from the stated rules, not a new engine execution.

## 18. Room, stations and routes

Coordinates below are interaction anchors in Godot `(x,y,z)` world units. They are not necessarily rendered support origins.

| Station | Interaction anchor | Purpose |
|---|---|---|
| Inspection desk | `(2, 1.1, 0)` | Place bag, then open/check contents |
| Scanner/belt marker | `(−1.2, 1.1, −2)` | Target carried bag/dog placement |
| Intake/display console | `(−1.2, 1, 0.1)` | Pause/resume or place carried bag/dog |
| Tool rack | `(−3, 1, 0.5)` | E tool cycling; numbered selection also works away from it |
| Evidence station | `(4.6, 1, 0)` | Secure restricted individual items |
| Development terminal | `(−3, 1, 3)` | Open/buy upgrades |

| Bay | Anchor | Bay color |
|---|---|---|
| A / NW101 | `(−7, 1, 4.6)` | Blue |
| B / SE202 | `(−4.5, 1, 4.6)` | Yellow |
| Security | `(−2, 1, 4.6)` | Red |
| Biosecurity | `(0.5, 1, 4.6)` | Green |
| Safeguarding | `(3, 1, 4.6)` | Teal |
| C / INT303 | `(5.5, 1, 4.6)` | Purple |
| Oversize | `(8, 1, 4.6)` | Brown |

Bay colors are destination presentation, **not a rule to match every bag color to the same-colored bay**. Read classification, size and flight.

Baggage carts, aircraft/apron scenery, structural parts and most signs are decoration or fixed geometry—not movable/pickup inventory. The physical rack's tool meshes are not finite tool pickups. Evidence deposits change model state; there is no separate interactive pile/retrieval system at the evidence bin.

**Sources:** S3 constants, `_build_stations`, `_build_bays`, `_build_window`, `_build_cart`; S2 targeting/gateway.

## 19. Multiplayer and ownership boundaries

The host owns arrivals, scanning, case classification, money, upgrades, dog updates, bag flight and ownership transitions. Clients request actions; the server derives the acting peer from the RPC sender rather than a supplied player ID.

Full simulation snapshots use reliable channel 2. Nominal send intervals are **0.033 seconds while a bag is airborne**, otherwise **0.08 seconds**, subject to actual frame/network scheduling. Player pose messages use unreliable-ordered channel 1.

Snapshot loading validates expected types/enums, finite values, positive IDs, carry cross-references and flight/event consistency before replacing state. It is not a disk-save feature or a complete proof of economic semantics.

Client poses are checked for finite values and room bounds, but this is **not robust speed/teleport anti-cheat**. Interaction selection is not a production occlusion/security system.

Disconnecting a carrying player releases its carried bag/item/dog to the floor near its last model position; held bags stop and remain off-belt. There is no money fine. Host departure returns clients toward the menu; no host migration or campaign recovery is implemented.

Two actual peers were demonstrated. The code has no game-specific two-player cap, but every nonhost worker currently gets the presentation label **PLAYER 2**. Do not infer polished larger-team support from the transport template.

**Ordinary co-op:** UDP 7000. Dedicated throw-playtest pairs use UDP 17127; other regression runners use their own ports.

**Sources:** S2 startup, networking/action gateway, `_receive_snapshot`, disconnect paths; S1 ownership helpers/snapshot validation; S8 ENet provider.

## 20. Exhaustive model action reference

There are exactly **23 recognized `sim.act` action strings**. Common prerequisites: the actor must exist and the shift must not be finished. Normal gameplay additionally enforces the controller/gateway conditions described earlier. A direct unit-test call is not equivalent to an ordinary key interaction at arbitrary distance.

| Action identifier | Essential prerequisites | State/result |
|---|---|---|
| `toggle_belt` | Common guards | Invert intake-running flag |
| `tool` | Integer 0–2 | Select hands/key/pliers; independent of carry slot |
| `pickup_bag` | Empty slot; available nonheld/nonsorted/nonairborne bag | Own bag; stop motion; off-belt true |
| `throw_bag` | Own held nonsafeguarding bag; valid local origin/unit aim | Close lid; launch; empty hands; throw event |
| `catch_bag` | Empty slot; airborne height/age/range rules | Atomic held ownership; stop; catch event |
| `place_bag` | Held bag; valid floor/belt/table placement; belt space if applicable | Release at destination; outline follows belt/off-belt state |
| `unlock` | Accessible locked bag; correct selected tool | Key unlocks approved; pliers cut any locked bag |
| `open` | Accessible unlocked bag | Set opened true; never toggles closed |
| `take_item` | Empty slot; accessible open bag; valid index; entry still inside and not safeguarding | Hold the original item record |
| `pickup_item` | Empty slot; available nondeposited nonsafeguarding floor item | Hold item |
| `drop_item` | Held item; finite target position | Put item at target; no ballistics |
| `return_item` | Held item; its accessible open source bag | Restore its location to bag |
| `seize_item` | Held nondeposited narcotics/organic item | Evidence state; $8/$16; seizure counter |
| `route` | Own held scanned bag; restricted bag opened; valid destination | Correct reward/resolve or wrong-route fine |
| `call_dog` | Dog on floor; valid goal | Set fixed goal; no persistent follow mode |
| `pickup_dog` | Empty slot; dog not already held | Own shared dog |
| `place_dog` | Held dog; floor/belt placement | Release safely; reset dog scan flag |
| `upgrade_scanner` | Unpurchased; $45 | Purchase scanner flag |
| `upgrade_kennel` | Unpurchased; $35 | Purchase dog-training flag |
| `upgrade_evidence` | Unpurchased; $30 | Purchase evidence flag |
| `upgrade_bio_lab` | Unpurchased; $70 | Purchase bio-lab flag |
| `upgrade_belt` | Unpurchased; $55 | Purchase intake flag; update arrival interval |
| `upgrade_terminal` | Unpurchased; $120; ≥5 handled and ≥5 reputation | Level 2; pending international arrival |

There is **no** `close`, manual `scan`, `save`, `load`, `jump`, `train_dog` or wildcard `upgrade_*` action. Six upgrade strings are explicitly recognized. Starting the next shift is a separate host call, not a client `sim.act` verb. UI-only toggles such as F/Escape/Tab are not extra model action strings.

Rejected model calls normally update shared feedback text even when gameplay state does not change. Malformed/disallowed gateway requests can be rejected before reaching the model.

**Sources:** S1 `act:115–254`; S2 `_perform_action:309–373`.

## 21. State machines and implementation edge cases

### 21.1 Entity states

- Bag: `belt`, `held`, `table`, `floor`, `airborne`, `sorted`.
- Individual content: `bag`, `held`, `floor`, `evidence`.
- Dog: `floor`, `held`, `belt`.

A bag can retain scan/unlock/outline/event data as its location changes. Location labels are model states, not a full physics surface taxonomy; a thrown bag settling on a supporting object can be treated as a resting floor-state object.

### 21.2 Rules that are easy to misread

1. **A 28 kg bag is not automatically oversize.** Size/classification/level decide the route.
2. **Taking contraband out does not legalize its bag.** Category is persistent.
3. **X-rays retain removed entries.** Do not read them as a live physical inventory reconstruction.
4. **Throwing closes the lid.** Restricted cases need reopening after a throw before routing.
5. **Seizure is optional for route completion.** It is additional item-level income, not a mandatory clearance checklist.
6. **You cannot arbitrarily repack items into other bags.** Returns enforce the source bag.
7. **Floor clutter is retained across shifts.** There is no cleanup bonus/fine or automatic trash pass.
8. **An alert is sticky per bag.** Kennel training does not erase old false positives.
9. **The dog can alert while carried.** It is not inactive in a player's arms.
10. **The dog scan is a gag, not training progression.** Repetition only increases its scan counter.
11. **A failed due arrival retries.** The system does not silently discard it or consume IDs.
12. **An airborne rebound may be caught.** First-contact history is not a catch prerequisite.
13. **Correct sorting requires E.** Physical bay overlap never substitutes for the route action.
14. **Legal cases need scanning, not necessarily unlocking/opening.** Restricted cases require opening.
15. **Terminal expansion changes existing bay access, signs and manifests**, not the physical room footprint.
16. **Shift continuation preserves a paused belt and existing in-flight/partial-scan state.** It is not a clean restart.

## 22. Current limits versus future design space

Implemented but intentionally simple: deterministic arrivals; fixed category per bag; three mass values; one-slot inventory; instant unlock/open actions; one dog; shared wallets; finite one-time upgrade tree; simplified thrown-bag collisions; local-network prototype workflow.

Not implemented by these sources:

- Random loot/weights, hidden probabilistic truth, a full contraband taxonomy, weapons/explosives or dangerous-object disposal.
- Item-by-item additive mass, bag damage, throwing dog/items, player injury, physical bag piles or a two-person heavy-bag carry requirement.
- Consumable tools, durability, timed lock minigames, an explicit close-bag control or bag relocking.
- Stamina, sprint/crouch/jump, skill classes, player leveling or independent money.
- A free-form item browser/selection wheel, arbitrary repacking, evidence retrieval or passenger document adjudication.
- Passenger NPC queues, independent adult rescue NPC AI, graphic exploitation or animal-harm mechanics.
- Dog hunger, training XP, patrol navigation, autonomous following, probabilistic scent accuracy or scan-based kennel upgrades.
- A new constructed wing/map, level 3+, procedurally escalating days, repeatable daily milestones, wages or an end-shift ranking system.
- Disk campaign saves, Steam matchmaking, Internet/NAT certification, host migration or production anti-cheat.

These may be future choices. They are not promised mechanics merely because a promotional phrase or decorative prop suggests them.

## 23. Evidence, source map and maintenance

### 23.1 Evidence boundaries

This document is a static source audit with programmatic catalog/action counts and formula calculations. No new engine suite was run specifically to author it.

Prior executed evidence on this branch includes 139 passing tests / 834 assertions, a 124-check airport walkthrough, normal airport/sushi network and host-loss runs, and recorded weighted relays by two real ENet peers. Those establish the named scenarios, not every possible edge case in this document.

The latest vertical capture completed all six catch events and passing gameplay reports, but its whole-session validator also logged pre-recording `LobbyRoot/PlayerSpawner` transition errors. The trailer is an editorial reuse of actual recorded gameplay; it is not a fresh clean-session or performance certificate. Software-rendered multiplayer captures used reduced simulation speed, normalized to normal playback; selected trailer shots also use disclosed slow motion.

### 23.2 Primary code references

- **S1 — Rules/model:** `scripts/airport/airport_simulation.gd` (829 lines). Actions 115–254; mass/throws/catches 257–420; upgrades/rewards/routes 450–508; arrival catalog 532–579; clock/queue/dog 581–668; continuation 670–677; snapshots 679–829.
- **S2 — Controller gateway/scene:** `scripts/airport/airport_game.gd` (570 lines). Targeting/input 136–219; context/contents 221–285; server authorization 296–373; networking 389–404; rendering/collision 406–556.
- **S3 — Room/catalog geometry:** `scripts/airport/airport_room.gd` (463 lines). Station/route constants; builders; expansion 175–185; baggage constructors; `item_mesh` 366–434.
- **S4 — First-person character:** `scripts/sushi/sushi_chef.gd` (77 lines), reused by the airport.
- **S5 — Bag/worker presentation:** `scripts/airport/airport_bag_presentation.gd` (203 lines).
- **S6 — Current local HUD:** `scripts/airport/airport_hud.gd` (214 lines). Includes later clean-video-HUD changes not yet committed at this audit.
- **S7 — Input map:** `project.godot`, input section 40–89.
- **S8 — Transport:** `scripts/multiplayer/network/providers/enet_network_provider.gd`; menu/lobby and template scene-readiness code.
- **Supporting tests:** `test/airport/test_airport_simulation.gd`, `test_airport_progression.gd`, `test_airport_throwing.gd`.

The gameplay baseline is [commit 0792ebf](https://github.com/xaviablaza/Friendslop-Template/commit/0792ebfdf2cb925c104e6b02073ff39d0830923d). Current-source details take precedence over older design notes when they disagree.

### 23.3 Audited catalog checks

The accompanying audit artifacts enumerate **23 model verbs, 12 generated content kinds, 11 individually carryable kinds, 18 unused renderer aliases, 6 initial templates, 6 palette colors with 5 actually spawned, 4 bag kinds, 3 sizes/masses, 6 station anchors, 7 routes and 3 flight IDs**. Counts were derived/deduplicated programmatically.

Audit JSONs also preserve source hashes and supporting line references. Core model SHA-256:

```text
36fbae3e6fb3e6ea311b8776f62ce0676a570dc17978256ec315ccfcdcd601b8
```

Update this reference when action dispatch, spawn tables, formulas, UI bindings, rewards or upgrade effects change. In particular, do not convert a visual alias into a claimed inventory type, an in-memory continuation into disk persistence, or a recorded example distance into a physics constant.
