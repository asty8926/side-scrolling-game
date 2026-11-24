---
title: "ADR 0001: Engine and language: Godot 4.7 with strictly typed GDScript"
status: accepted
date: 2026-11-24
supersedes: "the Rust + Bevy proposal in README, AGENTS.md and roadmap (pre-ADR drafts)"
---

# ADR 0001: Godot 4.7 + strictly typed GDScript

## Context

- Asty writes no code. All code comes from AI coding agents (Grok Bot and Cursor agents), on a budget of **a few owner-hours per week**.
- What Asty cares about most, after combat feel, is **simple editing UIs he can tweak**: dungeon rooms and platforms, move and hitbox data, shops, dialogue. He likes simple UIs whose fields and props he can customize. He does not want us to spend tokens rebuilding editors that already exist.
- The game is small in runtime terms: one screen-sized 2.5D room, 1-4 players, a handful of mobs. Raw language speed is not the bottleneck. **Combat feel, iteration speed and data editing are.**
- Non-negotiables carried over from [vision.md](../vision.md): free and open-source tools only, macOS first (Windows later), physical-key input (AZERTY + QWERTY), hot reload or close to it, typed code with explicit error handling, a deterministic fixed-tick simulation so online co-op does not need a rewrite.
- A side-by-side comparison (a typical 2-hour session, feature coverage, editors, networking) was written before this decision: [Engine choice for the Elsword-like game (Page)](https://cursor.com/canvas/store-069571c8-6770-4077-9dc2-fd73295be8bb/a1fe19b8-469e-4691-af85-3589ce3b845c).

## Options considered

| Option | For | Against | Verdict |
|---|---|---|---|
| **Rust + Bevy** (previous proposal) | Fast, strongly typed, code-first, ECS fits a deterministic sim, `lightyear` for netcode. | **No editor**: every editing UI (room/platform layout, move data, dialogue graph, shops) would have to be built by agents (egui), which is exactly the token spend Asty wants to avoid. Breaking API changes every few months. Code changes need a recompile (seconds, not instant). | Rejected. |
| **TypeScript + Three.js + Tauri** | Instant hot reload, agents know TS very well, strict types. | No editor either; 3D animation tooling, packaging and netcode all assembled by hand; web 3D performance and determinism get harder as the game grows. | Rejected. |
| **Fyrox** (Rust, with editor) | Rust + a real scene editor. | Small community and docs, so agents know it poorly; editor less mature; fewer free add-ons (dialogue, testing). High risk of agents guessing APIs. | Rejected. |
| **Godot 4.7 + typed GDScript** | Free (MIT), full editor: drag-and-drop 3D scenes for rooms and platforms, an **inspector that turns any `@export` field into an editable UI**, custom inspector plugins and editor panels in GDScript, built-in AnimationPlayer timeline, live script reload while the game runs, text-based scenes/resources (diffable by agents), one-click macOS/Windows export, headless mode for CI and servers, free add-ons (dialogue, tests), official Nakama client. | GDScript typing is optional (must be enforced), it is not Rust/TS (a change from [vision.md](../vision.md)), agents know it a bit less than TS, floats are not guaranteed bit-identical across CPUs (sim must avoid them). | **Chosen.** |

## Decision

1. **Engine: Godot 4.7.x stable**, pinned. As of 2026-11-24 the latest stable is **4.7.2** ([release](https://github.com/godotengine/godot/releases/tag/4.7.2-stable)). The exact version is written in [AGENTS.md](../../AGENTS.md) and in CI; bumping it is a deliberate PR.
2. **Language: GDScript with static typing everywhere**, enforced by project settings that turn untyped and unsafe code into **errors** (exact settings in [AGENTS.md](../../AGENTS.md)).
3. **Data in Godot Resources (`.tres`)**: moves, hitboxes, enemies, shops, dialogue, rooms. They are edited in the inspector (Asty) and as text (agents). Custom inspector plugins / `EditorPlugin` panels are added only where they make editing simpler.
4. **Combat is our own fixed-tick deterministic simulation** (60 ticks/s, integer fixed-point state, input frames per tick), driven from `_physics_process` but independent of Godot's physics engine. 3D nodes only display the sim's state.
5. **Rust stays available via [godot-rust/gdext](https://github.com/godot-rust/gdext)** (v0.5.6 on 2026-11-24) for a future hot spot only, after a measurement proves GDScript is too slow. No Rust before that.
6. **Online (M5, later):** a **dedicated headless Godot server** running the same GDScript simulation (server-authoritative + client prediction; netcode ADR before M5). **[Nakama](https://heroiclabs.com/nakama/)** (open source, self-hostable, official [Godot 4 client](https://github.com/heroiclabs/nakama-godot)) later for accounts, parties and matchmaking only, not for combat.
7. **Distribution:** macOS first, as an **unsigned** (ad-hoc signed, not notarized) export. CI on `main` (and manual dispatch) uploads the `.app` as a GitHub Actions artifact. Players right-click > Open, or System Settings > Privacy & Security > "Open Anyway", once. Windows export later. No paid Apple Developer Program.

## Consequences

**Good**
- Asty gets real editors on day one: a 3D scene editor for rooms and platforms, the inspector for every tunable number (damage, KD, hit-stop, cancel windows), AnimationPlayer for timelines. Agents spend tokens on the combat system, not on editor plumbing.
- Editors can be tailored cheaply: `@export_range`, `@export_group`, `@tool` previews, `EditorInspectorPlugin`, small dock panels, all in GDScript.
- Script changes reload while the game runs; data changes reload via our debug hot-reload (M0 issue).
- Headless Godot runs the same tests and replays in CI and will run the co-op server.

**Costs and how we handle them**
- *GDScript typing is opt-in.* Mitigated by project settings (warnings as errors), typed `Array[T]`/`Dictionary[K, V]`, and CI failing on any script error.
- *Agents know Godot 4.7 less well than TS, and Godot 3 examples pollute their memory.* Agents must check the docs for the pinned version (https://docs.godotengine.org/en/4.7/, or `/en/stable/` while it is 4.7) and never use Godot 3 APIs (`KinematicBody`, `yield`, `export var`, `onready var` without `@`).
- *Floating point is not bit-identical across machines (Apple Silicon vs x86 Windows).* The combat sim stores positions/velocities as **integers (fixed-point sub-units)** and uses no float math in hashed state.
- *Vision said "Rust or TypeScript".* Superseded by this ADR. The underlying goals (types, explicit errors, performance) are kept through strict typing, validation at load and measured performance budgets. Still no C/C++ in our own code.
- *Scene files can conflict when two agents edit the same scene.* Keep scenes small, one owner per scene per PR, text format only.

## Switch triggers (when we would revisit this ADR)

- Profiling on Asty's Mac shows the sim or AI step consistently over budget (e.g. > 4 ms per tick with 4 players + 20 mobs) **and** moving that hot spot to gdext does not fix it.
- Typed GDScript repeatedly lets a class of bugs through that a stronger type system would have caught, even with warnings as errors.
- Godot 4.x makes a breaking change that blocks the deterministic sim or headless server.
- Netcode (M5) proves impossible with a headless Godot server at acceptable cost.

Cheapest moment to switch is during M0. After M1 (combat feel go/no-go), a switch means porting the sim; the data format (Resources) and the docs carry over.

## References

- Comparison Page: https://cursor.com/canvas/store-069571c8-6770-4077-9dc2-fd73295be8bb/a1fe19b8-469e-4691-af85-3589ce3b845c
- Godot docs 4.7: https://docs.godotengine.org/en/4.7/
- GDScript static typing: https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html
- GDScript warning system: https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/warning_system.html
- Add-ons and tooling: [0002-addons-and-tooling.md](0002-addons-and-tooling.md)
