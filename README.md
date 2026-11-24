# side-scrolling-game

Custom tribute to Elsword: an open-source, **Elsword-inspired 2.5D action brawler**. 3D models and environments, seen from a side-scrolling camera, built around Elsword's combo feel.

- **First character:** a Rena-style elf ranger with kicks, arrows and a short blade: the `ZZZ<<>` run-cancel loop, the `>>ZX` slide-kick slash-through, air juggles managed by a KD (knockdown) gauge.
- **First content:** a training room, one dungeon (rooms, small platforms, a mini-boss, a boss, an end-of-run S+/S/A rank), one town with NPCs, dialogue and shops.
- **Real goal:** online co-op dungeon parties, then channel-based towns and hunting fields.
- **Platforms:** macOS first, Windows later. Free and open-source tools only.
- **Controls:** keyboard, Elsword-style (Z/X + arrows + skill keys). Works out of the box on **QWERTY and AZERTY** (keys are bound by physical position).

> Status: **pre-production.** Design docs are drafted; no game code yet.

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
