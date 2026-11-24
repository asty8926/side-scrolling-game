# side-scrolling-game

Custom tribute to Elsword: an open-source, **Elsword-inspired 2.5D action brawler**. 3D models and environments, seen from a side-scrolling camera, built around Elsword's combo feel.

- **First character:** a Rena-style elf ranger with kicks, arrows and a short blade: the `ZZZ<<>` run-cancel loop, the `>>ZX` slide-kick slash-through, air juggles managed by a KD (knockdown) gauge.
- **First content:** a training room, one dungeon (rooms, small platforms, a mini-boss, a boss, an end-of-run S+/S/A rank), one town with NPCs, dialogue and shops.
- **Real goal:** online co-op dungeon parties, then channel-based towns and hunting fields.
- **Platforms:** macOS first, Windows later. Free and open-source tools only.
- **Controls:** keyboard, Elsword-style (Z/X + arrows + skill keys). Works out of the box on **QWERTY and AZERTY** (keys are bound by physical position).

> Status: **pre-production.** Design docs are drafted; no game code yet.

## Planned stack (proposed, to be confirmed in an ADR during M0)

- **Rust + [Bevy](https://bevyengine.org/)**: a code-first, open-source engine with no visual editor lock-in. All code is written by AI coding agents.
- **Deterministic fixed-tick simulation** (60 Hz, input-driven, seeded RNG, snapshot/replay) from day one, so online co-op doesn't need a rewrite.
- Custom code only where the game's identity lives: command/combo parser, KD gauge, hit-stop, cancels, collision on the 2D gameplay plane.
- **Data-driven content** (moves, dungeons, dialogue, shops) in readable config files, **hot-reloaded** while the game runs, then **in-game editors** (dungeon platform layouts, dialogue node graphs, shops) that read and write those same files.
- AI-generated 3D models and animations (glTF), with Blender scripting available. Premade assets are placeholders only.

## Docs

- [docs/README.md](docs/README.md): start here (index, which doc to read when, Elsword glossary)
- [docs/vision.md](docs/vision.md): goals and constraints
- [docs/roadmap.md](docs/roadmap.md): milestones M0-M5, the determinism rule, scope guardrails
- [docs/systems/](docs/systems/): one doc per system (KD, combos, Awakening, dungeons, town, co-op...)
- [AGENTS.md](AGENTS.md): rules for AI coding agents

## License

Code: [MIT](LICENSE). Reference images in `docs/images/` are © KOG Studios and partners and are not covered by the MIT license (see [docs/images/README.md](docs/images/README.md)). This is a fan-made, non-commercial project, not affiliated with KOG, Nexon or Gameforge.
