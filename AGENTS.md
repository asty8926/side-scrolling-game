# AGENTS.md: instructions for AI coding agents

This repo is built entirely by AI coding agents (Grok Bot, Cursor agents, sometimes Claude Code). The owner (Asty, `asty8926`) writes no code. Your work must be precise, verifiable and scoped.

## 1. Read before doing anything

1. [docs/README.md](docs/README.md): index, **which file to read when**, and the **Elsword glossary** (KD, launch, pass, cancel, Awakening, NF, room, rank...). Use that vocabulary in code, issues and PRs.
2. [docs/vision.md](docs/vision.md): constraints and non-goals.
3. [docs/roadmap.md](docs/roadmap.md): current milestone and the **determinism rule**.
4. [docs/decisions/](docs/decisions/): accepted decisions. [0001](docs/decisions/0001-engine-godot.md) engine (Godot 4.7 + typed GDScript), [0002](docs/decisions/0002-addons-and-tooling.md) add-ons and tooling.
5. The system doc(s) under [docs/systems/](docs/systems/) for your task, plus the linked GitHub issue.

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

## 2. Engine and language (see [ADR 0001](docs/decisions/0001-engine-godot.md))

- **Godot 4.7.2-stable, pinned.** Use exactly this version locally and in CI (`GODOT_VERSION=4.7.2-stable`). Bumping it is its own PR. Never use Godot 3 APIs or syntax (`KinematicBody`, `yield`, `export var`, `onready var`, `setget`).
- **Check the docs for the pinned version, not your memory:** https://docs.godotengine.org/en/4.7/ (class reference + tutorials). If the docs and your memory disagree, the docs win. When unsure about an API, cite the doc page in the PR.
- **Typed GDScript everywhere** in our code: every variable, parameter, return type (`-> void` included), `Array[T]`, `Dictionary[K, V]`, typed signals. Use `:=` only when the right side has a static type. `class_name` for reusable types.
- **Warnings that are errors.** `project.godot` must contain these (verified on 4.7.2: a violating script fails to parse with "Warning treated as error"):

  ```ini
  [debug]
  gdscript/warnings/untyped_declaration=2
  gdscript/warnings/inference_on_variant=2
  gdscript/warnings/unsafe_property_access=2
  gdscript/warnings/unsafe_method_access=2
  gdscript/warnings/unsafe_cast=2
  gdscript/warnings/unsafe_call_argument=2
  gdscript/warnings/unsafe_void_return=2
  gdscript/warnings/unused_variable=2
  gdscript/warnings/unused_local_constant=2
  gdscript/warnings/shadowed_variable=2
  gdscript/warnings/shadowed_variable_base_class=2
  gdscript/warnings/narrowing_conversion=2
  gdscript/warnings/standalone_expression=2
  gdscript/warnings/unreachable_code=2
  gdscript/warnings/integer_division=0
  ```

  (`0` ignore, `1` warn, `2` error. `integer_division` is off because the combat sim uses integer fixed-point math on purpose.) Third-party add-ons stay excluded through the default `gdscript/warnings/directory_rules` (`res://addons` = exclude); our own code must never live under `addons/` unless it is an editor plugin we wrote, and then it gets an explicit include rule.
- **CI must fail on script errors.** Godot's headless run exits with code 0 even when a script fails to parse, so CI runs a check script that loads every `.gd` outside `addons/` and calls `quit(1)` on any failure, plus the GUT test run.
- **Error handling:** no silent failures. Check every `Error` return (`FileAccess`, `ResourceLoader`, `JSON`), validate data at load (`_validate()` on Resources, returning a list of problems), use `push_error()` with context, and keep the previous data on a failed reload. `assert()` only for programmer invariants (it is stripped in release builds).
- **No Rust or other native code** unless a measured hot spot needs it (then via godot-rust/gdext, with an ADR). No C/C++ in our code. No C# (`.NET` build of Godot is not used).

## 3. Rules

- **Stay inside the current milestone.** Don't build features from later milestones, even small ones. New ideas become a GitHub issue labeled `later`.
- **Determinism from M0:** gameplay runs in our own simulation on a fixed 60 Hz tick (`physics/common/physics_ticks_per_second=60`), stepped from one `_physics_process` driver. The sim is plain typed GDScript (`RefCounted` classes, no scene tree access) with a `step(inputs)` function, so tests can run it headless without nodes. It reads only per-player input frames. No wall clock, no `randf()`/`randi()` (use a seeded sim-owned RNG), no `Time`/`OS` calls, no dependence on node order or signals inside the sim. **Positions, velocities and timers in the sim are integers** (fixed-point sub-units), never floats, so the state hash is identical on macOS and Windows. Gameplay state must be snapshot-able and hashable.
- **Combat collision is ours:** hitboxes, hurtboxes, pushboxes and platforms are axis-aligned boxes on the 2D gameplay plane, checked by our code. Never use Godot physics (`Area3D`, `CharacterBody3D`, `RigidBody3D`, `move_and_slide`) to decide combat outcomes or movement in the sim. 3D nodes only **display** sim state (interpolate between ticks for smooth visuals).
- **Hit-stop and slow-mo are sim ticks**, not `Engine.time_scale`.
- **Every combat feature ships with a headless input-replay test:** a recorded per-tick input sequence produces the expected events and the same state hash on every run.
- **Keys are bound by physical position.** Input map events use `physical_keycode` (InputEventKey), never `keycode`/`unicode`. On AZERTY the physical `Z` key is labeled **W** and must work with zero configuration. UI shows the localized label via `DisplayServer.keyboard_get_label_from_physical()`.
- **Awakening defaults to Left Ctrl on every OS.** Cmd on macOS is opt-in only (Cmd+W/Cmd+Q conflicts).
- **Data lives in Resources (`.tres`, text format):** moves, hitboxes, cancel windows, enemies, rooms, shops, dialogue settings. One `class_name` Resource script per data type with `@export` fields, `@export_range`/`@export_group`/hints so the inspector is pleasant to edit, and a validator. When the plain inspector is clumsy for Asty (e.g. drawing hitbox rectangles on a timeline, placing platforms), add an `EditorInspectorPlugin`, a `@tool` preview or a small `EditorPlugin` dock. Keep each editor tool small and tied to one data type.
- **Scenes and resources are saved as text** (`.tscn`, `.tres`). No binary `.scn`/`.res` in the repo. Keep scenes small; one PR should not rewrite a scene another open PR touches.
- **Hot reload:** script changes reload live from the editor. Data (`.tres`) reloads in debug builds via our reloader (`ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)`) on file change; a bad file shows an error and keeps the previous data, never crashes.
- **No invented Elsword numbers.** Values not sourced from ElWiki are proposals to tune. Mark them `# proposal, tune` in code or in the Resource field's tooltip/comment and keep them in data.
- **Cite sources:** in PRs, reference the doc section and issue you implement. When you add research, link the ElWiki URL (and say if it's community/unverified).
- **Performance:** stable frame time on an Apple Silicon Mac. Budget: sim step under 2 ms per tick in M0-M2. Measure (Godot profiler / `Time.get_ticks_usec()` outside the sim) before optimizing, and report numbers with how they were measured.
- **Tests:** [GUT](https://github.com/bitwes/Gut) v9.7.1 vendored in `addons/gut/`, tests in `test/unit/` and `test/replay/`, run headless: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -ginclude_subdirs -gexit`.
- **Add-ons:** only those listed in [ADR 0002](docs/decisions/0002-addons-and-tooling.md), vendored at the pinned tag. Adding one needs an ADR update.
- **No Elsword assets or names in the game.** `docs/images/` is reference only.
- **Free tools only.** No paid services, plugins or assets.
- **Privacy:** the owner's public name is **Asty** (`asty8926`). Never write any other personal name in files, commits, issues or PRs. Commit as `asty8926 <asty8926@users.noreply.github.com>`.

## 4. Definition of done for a PR

- It implements the acceptance criteria checkboxes from the linked issue and system doc (tick them in the issue).
- Tests pass headless (GUT unit + replay tests) and the script-parse check passes in CI. Once the export job exists, the macOS export builds in CI.
- The relevant doc is updated if behavior or a decision changed (`status: accepted` when settled).
