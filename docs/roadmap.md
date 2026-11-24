---
title: Roadmap and milestones
status: draft
last_updated: 2026-11-24
---

# Roadmap

Principle: **feel first, content second, network last but planned from day one.** Each milestone has an exit test Asty can play. Nothing from a later milestone starts before the current one's exit test passes (that is the anti-scope-creep rule).

## Determinism rule (applies from M0)

Co-op is the real goal, so even single-player code must be network-ready:

1. **Fixed-timestep simulation** (60 ticks/s, stepped from one `_physics_process` driver in Godot), fully separate from rendering/animation playback. The sim is plain typed GDScript with no scene-tree access.
2. The simulation's only inputs are **per-player input frames** per tick (see [systems/01-combat-inputs.md](systems/01-combat-inputs.md)). No reading the keyboard, clock, or random numbers directly inside gameplay code.
3. **Seeded RNG** owned by the simulation; no global `randi()`/`randf()`, no wall clock, no dependence on node order or signal order in gameplay logic. **Integer fixed-point** positions/velocities (no floats in hashed state), so macOS and Windows produce the same hash.
4. Combat physics (hitboxes, pushboxes, platforms) is **our own simple 2D code** on the gameplay plane, not Godot's physics engine (determinism + exact feel). 3D nodes are for visuals only.
5. Gameplay state is plain typed data that can be **snapshotted, hashed and restored** (enables replays, rollback or server reconciliation, and CI replay tests).
6. Animation timing (startup/active/recovery) comes from move data, not from animation clip length, so AI-generated animations can be swapped freely.

Exit check for this rule, every milestone: a recorded input replay produces the **same state hash** on two runs (and later on macOS vs Windows).

## Milestones

| # | Name | Contents | Exit test (Asty plays) | System docs | Epic |
|---|---|---|---|---|---|
| **M0** | Vertical slice | Window + 2.5D camera, placeholder 3D character (free asset or Blender-generated), test room with platforms one jump apart, training dummy. Inputs by physical key (QWERTY+AZERTY), walk/dash/jump/double jump/drop. `ZZZZ`, `XXXX`, `>>ZZ`, `>>ZX` rough. Hot-reload of move data (`.tres` Resources). Debug overlay (frame, hitboxes, KD). Headless tests + replay harness in CI. Godot 4.7 project ([ADR 0001](decisions/0001-engine-godot.md)). | On his AZERTY Mac: `WWW`, `>>WX` work out of the box; changing a damage/hitstun number in a file updates the game without restart. | 01, 04 | [#35](https://github.com/asty8926/side-scrolling-game/issues/35) |
| **M1** | Combat feel | Hit-stop, hitstun, knockback, input buffer, cancel windows, **KD gauge** + launches + reset, `ZZZ<<>` loop, `>>ZX` polished, air combos, combo counter, MP gain/spend basics, 2-3 skills with cancel-from-commands. Replay tests in CI. | The `WWW<<>` loop and `>>WX` "feel like Elsword" to him on a dummy; KD knocks down when expected. **This is the go/no-go milestone.** | 02, 03, 05, 08 | [#36](https://github.com/asty8926/side-scrolling-game/issues/36) |
| **M2** | First dungeon | 2 mob types with AI that attack the player, collision/pushboxes, player can be hit/juggled/knocked down, 3-4 rooms with platforms and doors, mini-boss, boss (super armor, stoic threshold), results screen with rank. Dungeon data format + first version of the **room/platform editor**. | Clears the dungeon solo, gets a rank, wants to replay for S+. | 09, 02 | [#19](https://github.com/asty8926/side-scrolling-game/issues/19) |
| **M3** | Town | One town, 3-4 NPCs, dialogue graph format + validator (+ node editor if time), shop data + UI, town ↔ dungeon flow, save file. | Walks the town, talks, buys gear, enters the dungeon. | 11 | [#20](https://github.com/asty8926/side-scrolling-game/issues/20) |
| **M4** | Awakening & class system | Awakening beads/gauge, Ctrl (Cmd option) activation, 3-bead transformation, Nature's-Force-like system, MP passives/regen skill, more skills. | Awakens at 3 beads mid-boss and feels the power spike. | 06, 07, 08 | [#21](https://github.com/asty8926/side-scrolling-game/issues/21) |
| **M5** | Online co-op | Netcode ADR, dedicated headless Godot server running the same sim (authoritative, self-hostable), Nakama for parties/matchmaking if useful, party of 2-4 in the dungeon, latency tests. Windows build. | Clears the dungeon with a friend online (one on Mac, one on Windows). | 12 | [#22](https://github.com/asty8926/side-scrolling-game/issues/22) |
| Later | Growth | Hunting fields + channels + shared towns, Henir boss rush (needs ≥4 bosses), more dungeons, a 2nd character, PvP (maybe). | - | 10, 12 | [#23](https://github.com/asty8926/side-scrolling-game/issues/23) |

## Why this order

- **M0 before anything:** proves the toolchain (agents can build, Asty can run on macOS, hot reload works, AZERTY works). Cheapest moment to change engine/language decisions.
- **M1 is the heart.** Asty's top loves (the loop, `>>ZX`, KD, hit-stop, cancels) are all combat feel. If M1 fails, more content won't save it; if M1 succeeds, everything else is "just" content and systems.
- **Dungeon (M2) before town (M3):** the dungeon exercises combat against real opponents (AI, collision, being hit), which may force changes to the combat core. The town is mostly UI/data and doesn't feed back into combat.
- **Awakening (M4) after content exists:** Awakening is a multiplier on fun that's already there; it needs real fights (bosses) to be tuned. It also depends on MP/skills being stable.
- **Networking (M5) late but cheap:** thanks to the determinism rule, M5 is "add a transport + authority", not a rewrite. Doing it earlier would slow every feel iteration in M1-M2.
- **Fields/channels/Henir later:** they are multipliers of existing content (Henir reuses bosses; fields reuse mobs) and need the server.

## Scope-creep guardrails

- One character until M4 is done. One dungeon until M3 is done (a second dungeon is allowed only to reuse existing mobs).
- Every new idea goes into a GitHub issue labeled `later` with the milestone it belongs to; it is not worked on before that milestone.
- Every issue must cite the system doc section it implements and include acceptance criteria copied/adapted from it.
- Art: placeholders until M2 exit; AI-generated final art pipeline is evaluated as a side track (doesn't block milestones).
- Editors: each editor is built **after** its file format is stable and used by hand at least once (avoid building editors for formats that will change).

## Open questions (roadmap-level)

1. ~~Engine/framework~~ **Decided:** Godot 4.7 + strictly typed GDScript, see [decisions/0001-engine-godot.md](decisions/0001-engine-godot.md) (replaces the earlier Rust + Bevy proposal). Add-ons: [decisions/0002-addons-and-tooling.md](decisions/0002-addons-and-tooling.md).
2. Gameplay plane: strictly 2D (Elsword-like) - proposal yes.
3. Rank and MP tuning targets need Asty's playtest input in M1/M2.
