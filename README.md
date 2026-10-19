# Checked Chaos — Airport Baggage Greybox

The `airport-baggage` branch builds on the playable sushi foundation. Randomized arrivals → training X-ray clues → timed locks and contents inspection → repack, secure prohibited objects, care for animals, and sort bags into flight, security, biosecurity or animal-care bays.

## Expanded airport systems

- Seeded random contents and individual weights; probabilistic restricted/cleared lookalikes. Hidden truth stays on the host until inspection, rather than leaking through client snapshots or unopened X-ray labels.
- Legal belongings, narcotics, organics, weapons, explosives, dangerous objects, protected wildlife, customs goods and pet carriers. Fictional hazardous props have a specialist-disposal station.
- Additive shell-plus-item mass, impact damage, physical piles, throwable items, harmless cartoon dog hops, non-graphic player injury and first aid. Bags above 24 kg need two nearby operators in co-op; solo play permits slow dragging.
- Consumable key/pliers durability, timed lock sequences, seals, explicit closing/relocking, food/water portions, and a scrollable contents browser for selecting any item and repacking into another nearby open bag.
- Visible cats/rabbits in ventilated carriers replace the old adult silhouette. Hungry/thirsty carrier animals use supplies from the dog-care station before animal-care handoff. The detection dog has needs, training XP, stay/follow/patrol modes, probabilistic scent, and a scan prerequisite for its kennel upgrade.
- Stamina, sprint, crouch with clearance checks, jumping, splash/main menu, controls, and persistent audio/sensitivity/fullscreen settings.

Current rules and controls: [docs/airport-expansion.md](docs/airport-expansion.md). Earlier verification reports and videos describe their pinned pre-expansion versions; they are not evidence for the new mechanics.

## Weighted throws and two-player catches

Bag mass now adds the shell and each item still inside; 8/16/28 kg are explicit legacy throw-test fixtures, not the randomized gameplay weight classes. **G throws a carried bag or item**, or gives the dog a gentle harmless cartoon hop. **E catches airborne bags within reach**; **Q puts held objects down gently**. Animal carriers and shared heavy bags must be handled gently. Bag outlines, first-person carry hands and remote worker carry poses remain.

```sh
python3 tools/test-airport-expansion-throws.py # Two actual peers, 8/16/23 kg relay
# Historical pre-expansion video recipe (legacy runner expects 28 kg):
# python3 tools/test-airport-throws.py --record --time-scale 0.25
```

The **historical 1080×1920 vertical recording** stacks Player 1 above Player 2, preserving both complete 4:3 views. Game title and player labels sit in added title bars outside the gameplay image; in-game branding/player badges and demo chapter overlays are hidden. Capture uses a private Xvfb display and two simultaneous native windows, not fake actors or replayed network results. Output: `artifacts/airport-bag-throws-vertical.mp4`. Warm-up collects naturally arriving bags with normal keys before capture starts; the video shows weighted ground throws and a two-way airborne relay for each weight class. It is an automated, silent gameplay recording. The CPU-rendering option slows both real simulations during capture, then normalizes the MP4 to normal gameplay speed; unmodified capture is retained separately. The quarter-speed setting provides additional headroom for software-rendered captures. `--quick` runs only the light-bag regression, not full acceptance. Test transport uses **17127/UDP**. Detailed acceptance: [docs/airport-bag-throws.md](docs/airport-bag-throws.md).

## Play the airport

```sh
bash tools/setup-godot.sh
godot --path .
```

Choose **Play solo / Airport baggage**, or use the template's **Host Game → Start Game** / **Join** flow on **7000/UDP**. The previous sushi concept has its own main-menu button and its existing scene/test/recording commands are preserved.

**Controls:** WASD/mouse; Shift sprint; Ctrl crouch; Space jump. E context interaction; 1 hands, 2 key, 3 pliers; use E on a locked bag, then enter its displayed 1/2/3 sequence (Space also enters 1 while unlocking). O open; C close; R relock with a seal; I contents browser and arbitrary repacking. G throw; Q gentle drop; H join/leave a shared carry; K call dog; P cycle dog mode; F enlarge X-ray; TAB upgrades near the terminal; 1–6 buy while the shop is open; N next shift as host; ESC close a modal/release cursor. Use station menus for first aid, tool restock, dog care/supplies and disposal.

**Inspection:** varied colored cabin bags, duffels, backpacks, trunks and ventilated animal carriers. Legal non-graphic adult personal props remain legal. Unopened scans are neutral clues, not categorical truth; opening a bag reveals the inspected contents. Routing follows the actual remaining contents after removal or repacking, not its original classification. Dog alerts are clues, never convictions.

**Airport progression:** correct routes and once-only milestone grants fund scanner speed/clarity, dog training, evidence bonuses, biosecurity lab, faster/larger intake and terminal expansion. Expansion requires five correctly handled cases / five reputation plus $120; it opens a real flight-C bay and new international/oversize arrivals. Flight tags determine normal routing; large legal luggage uses oversize after expansion. Progress survives shift changes within the running session; there is no disk save or Steam integration.

## Airport checks and actual gameplay video

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-airport-network.py
bash tools/record-airport.sh
```

The opt-in tour walks the real controller and sends normal keys, earns all upgrade funds through actual cases, and writes assertion reports. Movie Maker records actual engine frames; the MP4 includes the procedural dog bark. Outputs stay in ignored `artifacts/`. The Linux network checks use private test ports 17117/17118; normal play uses 7000.

Current scope: [docs/airport-expansion.md](docs/airport-expansion.md). Historical baseline: [docs/airport-baggage.md](docs/airport-baggage.md), [docs/airport-verification.md](docs/airport-verification.md). This is an interactable greybox, not final art, a production customs simulator or production anti-cheat. Contraband and disposal rules are fictional game rules, not legal or real-world handling advice. Animal tossing/scanning is harmless cartoon fiction; player injury is non-graphic.

---

# Belt Behaviour — Revolving Sushi Graybox

A first-person, primitive-geometry restaurant prototype built on **Friendslop Template**. Prepare salmon, tuna and cucumber sushi, carry plates to a revolving conveyor, match customer requests, wash returned plates and spend earned money on handling upgrades. The existing ENet host/join lobby and scene readiness remain in use; solo play is one click from the main menu.

## Run this branch

- Requires **Godot 4.4.1** and **Git LFS**. GUT is already vendored in `addons/gut` (there is no npm install).
- Linux setup: install `git-lfs curl unzip` and OpenGL/audio runtime libraries, then run `bash tools/setup-godot.sh`. This installs the pinned engine under `~/.local/share/godot/4.4.1` and fetches the repository's real LFS assets. Opening pointer files without `git lfs pull` causes misleading image/font import failures.
- Launch: `godot --path .`, or open `project.godot` in the editor and press F6/F5 as appropriate.
- Choose **Play solo / Revolving sushi**, or **Host Game → Start Game**. Other players join the host IP using the template's ENet port **7000/UDP**. LAN/IP co-op, not Steam matchmaking.

**Controls:** WASD move; mouse or arrows look; E use the station you look at; F clear the oldest stale dish at the loading point; TAB open/close upgrades beside the terminal; 1/2/3 purchase while the terminal is open; N starts the next shift as host; ESC releases the cursor and exposes the main-menu button. The world does not pause while the cursor is released.

**Loop:** ingredient stations on the left → loading point at the far side → customers take matching dishes → plate return on the right → upgrades. Tray capacity starts at one; the $24 serving tray carries three. Plates become stale after 32 seconds and cannot be sold; clearing/discarding them returns dirty plates for washing. Each shift lasts two minutes; $80 is a soft target, not a hard game-over.

## Verification and real gameplay recording

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-sushi-network.py
bash tools/record-sushi.sh
```

The recording uses Godot's actual Movie Maker renderer and an opt-in automated player that walks the normal controller and sends E/1/TAB/N key events. It earns its money through customer purchases: no seeded cash or fake HUD. Output, screenshots and machine-readable checks are saved in ignored `artifacts/`. On headless Linux, recording additionally needs `xvfb` and `ffmpeg`; it uses a private virtual display and software OpenGL. The MP4 is silent graybox gameplay, not a trailer or a human playtest.

Design/scope: [docs/revolving-sushi.md](docs/revolving-sushi.md). Recorded execution results: [docs/verification.md](docs/verification.md). This is a disposable gameplay concept, not final art/audio, production anti-cheat, saved progression or a Steam build. The original 2D demo remains at `scenes/level/2d/Demo2DMap.tscn`.

---

# Original Friendslop Template 🎮

> [!IMPORTANT]
> To me, **Friendslop** means a game prioritizes fun moments with friends over everything else.
> Generally, this means that the graphics & UI are simple and to the point, but the core experience is present and polished.
> I'm developing this template for my own personal use as a solid foundation for future friendslop ideas I'd like to explore.

This is a Godot 4.4 starter kit designed to get your multiplayer game running quickly. It comes with scene synchronization, lobby, and player spawning systems. 

[![Tests](https://img.shields.io/github/actions/workflow/status/RGonzalezTech/Friendslop-Template/testing.yml?style=for-the-badge&logo=github&label=Tests)](https://github.com/RGonzalezTech/Friendslop-Template/actions/workflows/testing.yml)
[![Godot Version](https://img.shields.io/badge/Godot-4.4-%23478cbf?logo=godot-engine&logoColor=white&style=for-the-badge)](https://godotengine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](https://opensource.org/licenses/MIT)
[![Stars](https://img.shields.io/github/stars/RGonzalezTech/Friendslop-Template?style=for-the-badge&logo=github)](https://github.com/RGonzalezTech/Friendslop-Template/stargazers)
[![Forks](https://img.shields.io/github/forks/RGonzalezTech/Friendslop-Template?style=for-the-badge&logo=github)](https://github.com/RGonzalezTech/Friendslop-Template/network/members)

> [!TIP]
> **This is intended as a GitHub Template.** Github does not support Git LFS in templates, so you will need to manually clone/fork this repo to use it.

### 📺 Video
<p align="center">
  <em>Check out the overview video below to see the template in editor.</em>
</p>

<p align="center">
  <a href="https://www.youtube.com/watch?v=T7xIrRo7aLg">
    <img src="https://img.youtube.com/vi/T7xIrRo7aLg/maxresdefault.jpg" alt="Friendslop Template Walkthrough" width="100%">
  </a>
</p>

## 🚀 Key Features

*   **Multiplayer Ready**: Supports ENet out of the box and can be easily extended.
*   **Safe Scene Management**: A robust system to handle level transitions for all connected players simultaneously.
*   **Input Routing**: A clean pattern to handle local co-op input.
*   **Handshake Replication**: A custom spawning system that ensures clients are _actually ready_ to receive spawn/sync packets
*   **Testing**: Pre-configured with [GUT](https://gut.readthedocs.io/en/v9.5.0/) for unit testing.

## 📂 Project Structure

*   `addons/`: Third-party tools (I always start with [GUT](https://gut.readthedocs.io/en/v9.5.0/) in my projects).
*   `scenes/`: All your .tscn files (Menus, Levels, UI).
    *   Gameplay scenes should contain and manage their own logic and state when possible.
*   `scripts/`: The brains
    *   [`core/`](scripts/core/README.md): The Scene Manager nodes.
    *   [`input/`](scripts/input/README.md): Device input handling logic.
    *   [`multiplayer/`](scripts/multiplayer/README.md): Networking, Lobby, and Replication logic.
*   `test/`: Unit tests to keep your code sane.

## 🛠️ Getting Started

1.  **Clone or Fork**: Manually clone or fork this repository to your account (GitHub Templates do not support Git LFS).
2.  **Open in Godot**: Open the project in **Godot 4.4** or later.
3.  **Run & Play**: Run the project to host or join a lobby right away.

## Philosophy

I prefer **Simple over Complex**. This template avoids massive, monolithic managers in favor of smaller, focused components. If a script does more than one thing, it's probably doing too much.

See [CONTRIBUTING.md](CONTRIBUTING.md) for more information.

Enjoy!
