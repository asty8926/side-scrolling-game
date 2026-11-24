---
title: Vision and constraints
status: draft
owner: Asty (asty8926)
last_updated: 2026-11-24
---

# Vision and constraints

> Read this before anything else. Every design or tech decision should be checked against this page.
> The system docs in [`systems/`](systems/) describe *what* to build; this page describes *why* and *within which limits*.

## What we are building

An open-source, Elsword-inspired **2.5D action brawler**: 3D models and 3D environments viewed through a **side-scrolling camera**, with Elsword's combo feel at the core.

- **Not** a full Elsword clone. We take the systems Asty loves, not the content (no 15 characters, no 400 dungeons, no gacha/cash shop).
- **First character:** a Rena-inspired elf ranger (kicks + arrows + a short-blade "Erendil"-style sub-weapon), with the Trapping Ranger / Night Watcher flavor (see [systems/04-night-watcher-slide-x.md](systems/04-night-watcher-slide-x.md)).
- **First content:** a test room with a dummy, one dungeon with rooms, platforms, monsters, a mini-boss and a boss, an end-of-dungeon rank, one town with NPCs, dialogues and shops.

## What "done" means (Asty's words, summarized)

1. **A personal playground he loves playing.** Feel comes before content. If the combo loop in [systems/03-combo-loops-and-cancels.md](systems/03-combo-loops-and-cancels.md) does not feel right, nothing else matters.
2. **If it turns out great, the seed of a real game** that can grow. So the code must be clean, documented and extensible, not a throwaway prototype.
3. **Multiplayer is the real goal:** online co-op parties in dungeons, and channel-based shared towns and hunting fields (see [systems/12-fields-channels-party.md](systems/12-fields-channels-party.md)). Local single-player comes first for testing, but the simulation must be written so networking can be added without a rewrite (see [roadmap.md](roadmap.md), "Determinism rule").

## Hard constraints

| Constraint | Detail | Consequence for agents |
|---|---|---|
| Zero hand-written code by Asty | All code is written by AI coding agents (Claude Code, Cursor). | Docs, issues and acceptance criteria must be precise enough that an agent can implement and verify without asking. Prefer small, testable issues. |
| Language | **Rust or TypeScript** preferred. **No C / C++** in our own code. | Pick tools whose extension surface is Rust or TS. |
| Free tools only | Open source on GitHub; the only paid thing is AI tokens. | No paid engines, plugins, asset stores or SaaS in the build pipeline. |
| Platforms | **macOS first**, Windows later. Downloadable build. | CI must produce a macOS build early; avoid Windows-only or macOS-only APIs in game code. |
| Performance + error handling are central | Stable frame time, no crashes on bad data. | Typed data, validated config files, explicit error paths (Rust `Result` / TS strict mode + schema validation), no silent failures. |
| Iteration speed | Something close to **hot reload**: change a value or a map and see it in game without a full rebuild. | Gameplay numbers, maps, dialogues and shops live in data files that are watched and reloaded at runtime. |
| Editors | Visual editors (dungeon platform layouts, shops, dialogue node graphs) **in game or as tools**, or at least **centralized config files**. | Every content type gets a schema first, then a file format, then (later) an editor that reads/writes that same format. |
| Don't burn tokens on solved problems | Use well-established, extensible, open-source building blocks (rendering, physics, audio, windowing) unless an agent can build something clearly better and more "his". | Prefer libraries/engines that are code-first and hackable over black boxes. Custom code is reserved for what makes the game *this* game: combo system, KD, game feel, editors. |
| Art | **AI-generated 3D models and animations.** Premade/free assets only as placeholders ("something other than a rounded cube"). Blender is installed and agents may drive it (Blender Python scripting). | Asset pipeline must accept glTF/GLB. Animation timing (startup/active/recovery frames) must be data-driven so placeholder and final animations can swap without code changes. |
| Keyboard | Elsword-style keyboard play: Z/X + arrows + skill keys. Must work **out of the box on both QWERTY and AZERTY** (Asty uses AZERTY). | Bind by **physical key position** (scan code / `KeyboardEvent.code` / winit `PhysicalKey`), never by produced character. See [systems/01-combat-inputs.md](systems/01-combat-inputs.md). |
| Awakening key | Ctrl on Windows; Asty wants **Cmd on macOS**. | Watch for macOS shortcut conflicts (Cmd+Q, Cmd+W, Cmd+H). See open questions in [systems/06-awakening.md](systems/06-awakening.md). |

## Taste notes (things Asty explicitly loves)

From his own description, in priority order of how strongly he expressed them:

1. The **`WWW<<>` loop** on AZERTY (= `ZZZ<<>` on QWERTY): three basic hits, dash backwards, reverse to cancel and face forward again, repeat, so the 4th hit never knocks the enemy down.
2. The **KD (knockdown) gauge** and the "infinite" combo cycles that manage it.
3. **Night Watcher's `>>WX`** (= `>>ZX`): dash, slide kick that carries her forward, then X to slash through the enemy and end up on its other side.
4. **Hit-stop and impact, fast responsive input, canceling combos into skills.**
5. **Awakening** (3 beads, Ctrl/Cmd) with class-specific effects (Rena's Nature's Force, Elsword's Way of the Sword, Ara's nine-tailed-fox Eun Mode).
6. **Dungeons:** fast, small platforms, room-by-room, mini-bosses and bosses, **end rank** (S+, S, A, B, ...).
7. **MP economy without mana potions:** combos, passives and spells fuel MP, like early Elsword.
8. **Henir's Time and Space** (boss rush), later.
9. **Towns with NPCs, dialogues, shops**, and later **fields and channels**.

## Non-goals (scope-creep guardrails)

- No PvP until co-op works (Elsword's KD numbers differ between PvE and PvP; we tune PvE only).
- No item enhancement/refinement/socketing/gacha systems.
- No second character until the first one passes the feel milestone (M1).
- No class advancement tree; our Rena-like character is a single "best-of" kit.
- No 3D free movement: gameplay is on a 2D plane (x = left/right, y = up/down); depth (z) is visual only, or a small number of discrete "lines" at most (to decide, see roadmap open questions).

## Legal / licensing note

- ElWiki text is licensed **CC BY-NC-SA 3.0**; game content and images are **© KOG Studios / Nexon / Gameforge / KOG Games**. They are kept in `docs/images/` as attributed reference while the project is personal. See [images/README.md](images/README.md).
- Our own code is MIT licensed (see `LICENSE`).
- Our game must not ship Elsword names, art, sounds or text. Docs use Elsword vocabulary as **reference**; in-game names should be our own (e.g. not "Rena", "Erendil", "Nature's Force"). Naming is an open task.
