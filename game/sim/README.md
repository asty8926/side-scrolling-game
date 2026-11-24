# game/sim: the deterministic simulation

Everything that decides gameplay outcomes lives here. Rules (from [AGENTS.md](../../AGENTS.md) section 3 and the determinism rule in [docs/roadmap.md](../../docs/roadmap.md)):

- Classes extend `RefCounted`, never a node. No scene tree, no `$`, no `get_node`.
- One fixed tick = 1/60 s. `SimWorld.step(inputs)` advances exactly one tick; its only input is an `Array[InputFrame]`.
- **Integers only in state.** `SimUnits.PER_METER = 1000` sub-units per meter (*proposal, tune*). Velocities are sub-units per tick, timers are ticks. `SimUnits.to_vector3()` is for views only.
- Randomness only from the world's `SimRng` (seeded xoshiro128**, part of the snapshot). No `randi()`, `randf()`, `Time`, `OS`, `Engine`, `Input`.
- Entities are an `Array` in insertion order. Never iterate a `Dictionary` for gameplay.
- `snapshot()` writes every field in a fixed order (bump `SNAPSHOT_VERSION` when fields change), `state_hash()` is its SHA-256, `restore()` validates and keeps the old state on bad data.
- `game/sim_driver.gd` (outside this folder) is the only node: it steps the world once per `_physics_process`. Views read the world, never write it.

`test/unit/test_sim_guard.gd` scans this folder in CI and fails on forbidden APIs or float fields.
