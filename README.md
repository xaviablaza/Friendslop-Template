# Checked Chaos — Airport Baggage Greybox

The `airport-baggage` branch builds on the playable sushi foundation. Straight automatic intake → live training X-ray → locks/contents inspection → carry and sort into flight, security, biosecurity or safeguarding bays.

## Weighted throws and two-player catches

Bags now have mass: 8 kg light luggage, 16 kg medium loads and 28 kg heavy/dense electronics cases. **G throws a carried bag** with weight-dependent speed/range, gravity, impacts and settling. **E catches an airborne bag within reach**; **Q puts it down gently**. Heavier loads slow walking. Bags taken off the belt have a yellow silhouette outline; returning them to the belt removes it. First-person carrying uses both visible hands, and remote operators have worker avatars with matching carry poses. Dogs/items are never thrown by G.

```sh
python3 tools/test-airport-throws.py          # Two actual headless ENet peers
python3 tools/test-airport-throws.py --record --time-scale 0.5 # Both real player windows together
```

The split-screen recording uses a private Xvfb display and simultaneous native screen capture, not two fake actors or replayed network results. Warm-up collects naturally arriving bags with normal keys before capture starts; the video shows weighted ground throws and a two-way airborne relay for each weight class. It is an automated, silent gameplay recording. The CPU-rendering option slows both real simulations to half-speed during capture, then normalizes the MP4 to normal gameplay speed; unmodified capture is retained separately. `--quick` runs only the light-bag regression, not full acceptance. Test transport uses **17127/UDP**. Detailed acceptance: [docs/airport-bag-throws.md](docs/airport-bag-throws.md).

## Play the airport

```sh
bash tools/setup-godot.sh
godot --path .
```

Choose **Play solo / Airport baggage**, or use the template's **Host Game → Start Game** / **Join** flow on **7000/UDP**. The previous sushi concept has its own main-menu button and its existing scene/test/recording commands are preserved.

**Controls:** WASD/mouse; E context interaction; 1 hands, 2 approved-lock key, 3 large pliers; O open selected bag; I take the next available item / return a held item to its source bag; G throw a bag (gently place items/dog); Q gently put down a bag; K call the dog; F enlarge X-ray; TAB airport development (near terminal); 1–6 purchase while development is open; N next shift as host; ESC cursor/menu. Use the console to pause/resume intake while inspecting. Put carried bags on the desk before handling their contents.

**Playable mechanics:** varied colored cabin bags, duffels, backpacks and large trunks; approved/foreign locks; visible tools and opening lids; individual contents; narcotics evidence; fruit/vegetable/seed bonuses; legal non-graphic dildo/vibrator joke props; serious adult safeguarding/rescue cases; dog scent alerts (clues, not convictions), calling/carrying/dropping and a harmless fictional non-ionizing scanner gag. The scanner displays the actual simulated contents, with labels after inspection or a scanner upgrade.

**Airport progression:** correct routes and once-only milestone grants fund scanner speed/clarity, dog training, evidence bonuses, biosecurity lab, faster/larger intake and terminal expansion. Expansion requires five correctly handled cases / five reputation plus $120; it opens a real flight-C bay and new international/oversize arrivals. Flight tags determine normal routing; large legal luggage uses oversize after expansion. Progress survives shift changes within the running session; there is no disk save or Steam integration.

## Airport checks and actual gameplay video

```sh
godot --headless --editor --import --quit
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://gutconfig.json -gexit
python3 tools/test-airport-network.py
bash tools/record-airport.sh
```

The opt-in tour walks the real controller and sends normal keys, earns all upgrade funds through actual cases, and writes assertion reports. Movie Maker records actual engine frames; the MP4 includes the procedural dog bark. Outputs stay in ignored `artifacts/`. The Linux network checks use private test ports 17117/17118; normal play uses 7000.

Full scope: [docs/airport-baggage.md](docs/airport-baggage.md). Execution evidence: [docs/airport-verification.md](docs/airport-verification.md). This is an interactable greybox, not final art, a production customs simulator or production anti-cheat. Contraband rules are fictional game rules, not legal advice. Safeguarding figures are adults and non-graphic; the dog scanner is explicitly harmless fiction.

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
