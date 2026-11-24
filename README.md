# side-scrolling-game

Custom tribute to Elsword: an open-source, **Elsword-inspired 2.5D action brawler**. 3D models and environments, seen from a side-scrolling camera, built around Elsword's combo feel.

- **First character:** a Rena-style elf ranger with kicks, arrows and a short blade: the `ZZZ<<>` run-cancel loop, the `>>ZX` slide-kick slash-through, air juggles managed by a KD (knockdown) gauge.
- **First content:** a training room, one dungeon (rooms, small platforms, a mini-boss, a boss, an end-of-run S+/S/A rank), one town with NPCs, dialogue and shops.
- **Real goal:** online co-op dungeon parties, then channel-based towns and hunting fields.
- **Platforms:** macOS first, Windows later. Free and open-source tools only.
- **Controls:** keyboard, Elsword-style (Z/X + arrows + skill keys). Works out of the box on **QWERTY and AZERTY** (keys are bound by physical position).

> Status: **M0 (vertical slice) in progress.** The Godot project and its test setup exist; there is no gameplay yet. Track progress in [epic #35](https://github.com/asty8926/side-scrolling-game/issues/35).

## How to try it (macOS)

No coding needed. You only install Godot once.

1. **Install Godot 4.7.2** (free): download "Godot Engine - macOS" for **4.7.2-stable** from the [official release page](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) (file `Godot_v4.7.2-stable_macos.universal.zip`), unzip it and drag `Godot.app` into Applications. Use exactly this version: newer or older ones may change things.
2. **Get the project**: on this GitHub page click **Code > Download ZIP** and unzip it (or `git clone` it).
3. **Open it**: start Godot, click **Import**, pick the `project.godot` file in the unzipped folder, then **Import & Edit**. The first opening takes a few seconds while Godot imports files.
4. **Run the project**: press **F5** (or the ▶ Play button, top right). For now a window opens with the text "side-scrolling-game M0" (the simulation already ticks 60 times per second behind it, with nothing in it yet). That's expected: the next issues add your keys, movement, the test room and the character.

### Run tests

- **In the editor:** open the **GUT** tab at the bottom of the window. The first time, open its settings (gear icon) and add `res://test` as a test directory with *Include Subdirectories* on. Then click **Run All**.
- **From a terminal** (from the project folder; on macOS replace `godot` with `/Applications/Godot.app/Contents/MacOS/Godot`):

  ```sh
  godot --headless --import && godot --headless -s res://tools/check_scripts.gd && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit
  ```

  The first command imports the project, the second fails if any of our scripts breaks the strict typing rules, the third runs the tests. GitHub Actions runs the same three steps on every push and pull request ([CI workflow](.github/workflows/ci.yml)).

## Project layout

| Folder | What lives there |
|---|---|
| `game/` | Scenes and scripts of the game. `game/main.tscn` is the scene that opens when you press Play. |
| `game/sim/` | The deterministic combat simulation: plain typed GDScript, no nodes, no scene tree, integer math only (1 m = 1000 sub-units), 60 ticks per second, seeded RNG, hashable snapshots. Rules: [game/sim/README.md](game/sim/README.md). `game/sim_driver.gd` steps it once per physics tick. |
| `game/view/` | 3D display: reads the simulation state and draws it (never changes it). |
| `game/debug/` | Debug tools: overlays, readouts. |
| `data/` | Game data as text Resources (`.tres`): moves, hitboxes, enemies, rooms... editable in Godot's Inspector. |
| `test/unit/`, `test/replay/` | GUT tests: unit tests and input-replay tests, run headless in CI. |
| `tools/` | CI helper scripts (`check_scripts.gd` fails the build on any script error). |
| `addons/` | Vendored third-party add-ons only ([GUT 9.7.1](https://github.com/bitwes/Gut/releases/tag/v9.7.1)). Excluded from our strict warnings. |
| `docs/` | Design docs and reference images. Godot ignores this folder (`docs/.gdignore`). |

Renderer: **Forward+** (Godot's default desktop renderer, the best fit for 3D on an Apple Silicon Mac). CI runs with `--headless`, which skips rendering entirely, so the renderer choice does not affect tests.

## Stack (decided: [ADR 0001](docs/decisions/0001-engine-godot.md))

- **[Godot 4.7](https://godotengine.org/)** (pinned to 4.7.2-stable), free and open source. Its editor gives us room/platform layout, an inspector for every tunable number, and an animation timeline without building our own editors.
- **Strictly typed GDScript**: untyped declarations and unsafe access are compile errors (project settings). All code is written by AI coding agents (Grok Bot and Cursor agents).
- **Deterministic fixed-tick combat simulation** (60 ticks/s, integer fixed-point state, per-tick input frames, seeded RNG, state hash + input-replay tests) from day one, so online co-op doesn't need a rewrite. Godot's physics engine is never used to decide combat outcomes.
- **Data as Godot Resources (`.tres`)**: moves, hitboxes, enemies, rooms, shops, dialogue. Editable in the inspector (with custom inspector panels where it helps) and as plain text by agents. Move data hot-reloads while the game runs.
- **Free add-ons only where they save real work**: GUT for tests, Dialogue Manager for dialogue (M3). See [ADR 0002](docs/decisions/0002-addons-and-tooling.md).
- **Later:** a dedicated headless Godot server for online co-op, [Nakama](https://heroiclabs.com/nakama/) for accounts/parties/matchmaking, and Rust via [godot-rust/gdext](https://github.com/godot-rust/gdext) only for a measured hot spot.
- **Builds:** macOS first (unsigned: right-click > Open or "Open Anyway" once in Privacy & Security), Windows later.
- AI-generated 3D models and animations (glTF), with Blender scripting available. Premade assets are placeholders only.

## Docs

- [docs/README.md](docs/README.md): start here (index, which doc to read when, Elsword glossary)
- [docs/vision.md](docs/vision.md): goals and constraints
- [docs/roadmap.md](docs/roadmap.md): milestones M0-M5, the determinism rule, scope guardrails
- [docs/decisions/](docs/decisions/): architecture decision records (engine, add-ons)
- [docs/systems/](docs/systems/): one doc per system (KD, combos, Awakening, dungeons, town, co-op...)
- [AGENTS.md](AGENTS.md): rules for AI coding agents

## License

Code: [MIT](LICENSE). Reference images in `docs/images/` are © KOG Studios and partners and are not covered by the MIT license (see [docs/images/README.md](docs/images/README.md)). This is a fan-made, non-commercial project, not affiliated with KOG, Nexon or Gameforge.
