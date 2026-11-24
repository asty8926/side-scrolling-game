# AGENTS.md: instructions for AI coding agents

This repo is built entirely by AI coding agents (Claude Code, Cursor). The owner (Asty, `asty8926`) writes no code. Your work must be precise, verifiable and scoped.

## 1. Read before doing anything

1. [docs/README.md](docs/README.md): index, **which file to read when**, and the **Elsword glossary** (KD, launch, pass, cancel, Awakening, NF, room, rank...). Use that vocabulary in code, issues and PRs.
2. [docs/vision.md](docs/vision.md): constraints and non-goals.
3. [docs/roadmap.md](docs/roadmap.md): current milestone and the **determinism rule**.
4. The system doc(s) under [docs/systems/](docs/systems/) for your task, plus the linked GitHub issue.

| Task touches... | Doc |
|---|---|
| Key bindings, movement, command strings | `docs/systems/01-combat-inputs.md` |
| KD gauge, knockdown, launches, super armor | `docs/systems/02-kd-knockdown.md` |
| `ZZZ<<>` loop, dash cancel, combo cycles | `docs/systems/03-combo-loops-and-cancels.md` |
| `>>ZX` slide kick + slash-through | `docs/systems/04-night-watcher-slide-x.md` |
| Hit-stop, hitstun, buffer, cancel windows | `docs/systems/05-game-feel.md` |
| Awakening (beads, Ctrl) | `docs/systems/06-awakening.md` |
| Nature's Force class resource | `docs/systems/07-natures-force.md` |
| MP gain/spend (no MP potions) | `docs/systems/08-mp-economy.md` |
| Dungeons, rooms, mobs, bosses, rank | `docs/systems/09-dungeons.md` |
| Boss rush (later) | `docs/systems/10-henir.md` |
| Town, NPCs, dialogue, shops | `docs/systems/11-town-npcs-shops.md` |
| Parties, co-op, channels, fields | `docs/systems/12-fields-channels-party.md` |

## 2. Rules

- **Stay inside the current milestone.** Don't build features from later milestones, even small ones. New ideas become a GitHub issue labeled `later`.
- **Determinism from M0:** gameplay runs on a fixed 60 Hz tick and reads only per-player input frames. No wall clock, no unseeded RNG, no iteration-order-dependent logic in the simulation. Gameplay state must be snapshot-able and hashable. Combat collision is our own 2D code on the gameplay plane, not a 3D physics engine. Every combat feature ships with a headless **input-replay test**.
- **Keys are bound by physical position** (scan code / physical key code), never by produced character. On AZERTY, physical `Z` is labeled **W** and must work with zero configuration. The UI shows the localized key label.
- **Awakening defaults to Left Ctrl on every OS.** Cmd on macOS is opt-in only (Cmd+W/Cmd+Q conflicts).
- **Data-driven and hot-reloadable:** move frames, hitboxes, damage, KD, MP, cancel windows, dungeons, dialogue and shops live in validated data files. A bad file shows an error and keeps the previous data. It never crashes the game.
- **No invented Elsword numbers.** Values not sourced from ElWiki are proposals to tune. Label them `// proposal, tune` in data or code and keep them in data files.
- **Cite sources:** in PRs, reference the doc section and issue you implement. When you add research, link the ElWiki URL (and say if it's community/unverified).
- **Error handling is central:** no `unwrap()`/`expect()` in game code paths except for proven invariants. Use typed errors and log with context.
- **Performance:** stable frame time on an Apple Silicon Mac. Measure before optimizing, and report numbers with how they were measured.
- **No Elsword assets or names in the game.** `docs/images/` is reference only.
- **Languages:** Rust (preferred) or TypeScript for tooling. No C/C++ in our code.
- **Free tools only.** No paid services, plugins or assets.

## 3. Definition of done for a PR

- It implements the acceptance criteria checkboxes from the linked issue and system doc (tick them in the issue).
- Tests pass (unit + replay tests). It builds on macOS (CI).
- The relevant doc is updated if behavior or a decision changed (`status: accepted` when settled).
