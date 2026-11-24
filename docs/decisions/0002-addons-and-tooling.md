---
title: "ADR 0002: Add-ons and tooling for Godot 4.7"
status: accepted
date: 2026-11-24
---

# ADR 0002: Add-ons and tooling

Rule of thumb: **use an add-on only when it saves real work and its release explicitly supports our pinned Godot version.** Everything else stays custom and small. Add-ons are vendored into `addons/<name>/` at a pinned tag (no auto-update) and are excluded from our strict warnings by Godot's default `debug/gdscript/warnings/directory_rules` (`res://addons` = exclude).

Versions checked on 2026-11-24 against Godot **4.7.2-stable**.

| Need | Choice | Pinned version | Godot 4.7 compatibility | When | Why / alternatives |
|---|---|---|---|---|---|
| Unit + replay tests, headless CI | **[GUT](https://github.com/bitwes/Gut)** | **v9.7.1** (`godot_4_7` line) | Explicit: GUT's version table maps 9.7.1 to Godot 4.7.x. | M0 | Pure GDScript, simple CLI (`-gdir`, `-ginclude_subdirs`, `-gexit`, `-gjunit_xml_file`), mature docs agents know. **Not chosen:** [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) v6.2.3 also works with 4.7 and has richer assertions/IDE integration, but is heavier (C# support, its own runner); one test framework only. |
| Dialogue (branching, conditions, actions) | **[Dialogue Manager](https://github.com/nathanhoad/godot_dialogue_manager)** by nathanhoad | **v4.2.0** | Release titled "v4.2.0 for Godot 4.7"; v4 requires Godot 4.6+. | M3 (not before) | Mature, stateless runtime, text-based `.dialogue` files (great for agents and diffs), built-in editor tab with syntax highlighting, conditions/mutations that can call our `open_shop`, `give_item`, `set_flag`. **Caveat:** it is a script-like editor, not a visual node graph. If Asty wants a node view at M3, we add a small `GraphEdit` viewer/editor on top of the same files rather than switch tools. **Not chosen:** [Dialogic 2](https://github.com/dialogic-godot/dialogic) (visual timeline editor, but still "2.0 alpha-20" in July 2026 and heavier, visual-novel oriented). Re-check versions when M3 starts. |
| Camera (2.5D side view) | **Custom** (a small follow camera: fixed Z distance, horizontal follow with dead zone, vertical clamp per room) | - | - | M0 | Our needs are tiny and must not fight the fixed-tick sim. **Optional later:** [Phantom Camera](https://github.com/ramokz/phantom-camera) v0.12 (requires Godot 4.4+, has 3D lookahead and dead zones) if we need cinematic boss intros or camera blends. Note v0.12 had breaking changes, so pin if adopted. |
| State machines (player, mobs, bosses) | **None / custom** | - | - | M0+ | Combat states live inside our deterministic sim as plain typed GDScript (enum + match, data from Resources). Node-based state machine add-ons tie state to the scene tree and to frame timing, which breaks determinism and replay tests. **Not chosen:** [LimboAI](https://github.com/limbonaut/limboai) v1.8.1 (behavior trees + HSM, C++ GDExtension); reconsider only for boss AI authoring in M2 if custom AI gets unwieldy, and only if it can run inside the sim tick. |
| Native speed hot spot | **[godot-rust/gdext](https://github.com/godot-rust/gdext)** | (v0.5.6 today) | - | Only after a measured need | See ADR 0001. |
| Accounts, parties, matchmaking | **[Nakama](https://github.com/heroiclabs/nakama)** + [nakama-godot](https://github.com/heroiclabs/nakama-godot) | (client v3.4.0, Godot 4 branch, repo active Nov 2026) | Godot 4 client is the default branch. | M5 / Later | Self-hostable, free. Combat runs on our headless Godot server, not in Nakama. Check client compatibility with 4.7 when M5 starts (last tagged release is from 2024). |

## Tooling (no add-on)

- **CI:** GitHub Actions on `ubuntu-latest` downloads the official Godot 4.7.2 Linux binary, runs `godot --headless --import` then GUT headless. A macOS export job (unsigned `.app` zipped as an artifact) is added in M0 once the project runs; it needs the matching export templates (`Godot_v4.7.2-stable_export_templates.tpz`), downloaded in CI, free.
- **Formatting/linting:** none in M0 (strict warnings are our linter). Revisit [GDScript Toolkit](https://github.com/Scony/godot-gdscript-toolkit) (`gdformat`/`gdlint`) if style drift becomes a problem.
- **3D placeholders:** primitive meshes (capsule) or a CC0 model; AI-generated art pipeline is a side track (see roadmap).
