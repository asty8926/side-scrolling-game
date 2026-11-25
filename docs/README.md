# Design docs: Elsword-like 2.5D brawler

Start here. These docs describe the Elsword systems Asty (GitHub `asty8926`) loves, what our version must do, and in which order we build them. They are written for **AI coding agents**: use the vocabulary below, follow the acceptance criteria, cite the doc section in every issue/PR.

**Status:** all docs are `draft` (researched 2026-11-24). Numbers come from ElWiki unless marked *community* (unverified) or *our proposal* (tuning target, not Elsword data). Anything not found is marked **unknown / to verify**; do not invent Elsword numbers.

## Read in this order

1. [vision.md](vision.md): goals, constraints, non-goals. Read before any decision.
2. [roadmap.md](roadmap.md): milestones M0-M5, the **determinism rule**, scope-creep guardrails.
3. [decisions/](decisions/): accepted decisions: [0001 engine (Godot 4.7 + typed GDScript)](decisions/0001-engine-godot.md), [0002 add-ons and tooling](decisions/0002-addons-and-tooling.md).
4. The system doc(s) for the milestone you're working on (table below).

## Which file to read when

| If your task touches... | Read | Milestone | Issue |
|---|---|---|---|
| Keyboard bindings, AZERTY/QWERTY, movement, dash, jump, platforms height, command strings | [systems/01-combat-inputs.md](systems/01-combat-inputs.md) | M0-M1 | [#24](https://github.com/asty8926/side-scrolling-game/issues/24) |
| KD gauge, knockdown, launches, super armor, stoic thresholds, mana break | [systems/02-kd-knockdown.md](systems/02-kd-knockdown.md) | M1 | [#2](https://github.com/asty8926/side-scrolling-game/issues/2) |
| The `ZZZ<<>` / `WWW<<>` loop, dash cancel, infinite combo cycles | [systems/03-combo-loops-and-cancels.md](systems/03-combo-loops-and-cancels.md) | M1 | [#25](https://github.com/asty8926/side-scrolling-game/issues/25) |
| `>>ZX` / `>>WX` slide kick + slash-through, pass-through moves | [systems/04-night-watcher-slide-x.md](systems/04-night-watcher-slide-x.md) | M0-M1 | [#4](https://github.com/asty8926/side-scrolling-game/issues/4) |
| Hit-stop, impact, hitstun, input buffer, cancel windows, cancels into skills | [systems/05-game-feel.md](systems/05-game-feel.md) | M1 | [#26](https://github.com/asty8926/side-scrolling-game/issues/26) |
| How far each hit moves the character (per-hit steps, recoil, slide and dash-through distances), feel checks | [reference/README.md](reference/README.md), [reference/rena-combo-movement.md](reference/rena-combo-movement.md) | M1 | [#61](https://github.com/asty8926/side-scrolling-game/issues/61) |
| Awakening beads, Ctrl/Cmd, transformation, Way of the Sword, Ara's Eun Mode | [systems/06-awakening.md](systems/06-awakening.md) | M4 | [#27](https://github.com/asty8926/side-scrolling-game/issues/27) |
| Rena's class resource (Nature's Force / NF) | [systems/07-natures-force.md](systems/07-natures-force.md) | M4 | [#28](https://github.com/asty8926/side-scrolling-game/issues/28) |
| MP gain/spend, no mana potions, MP regen, skill MP tiers | [systems/08-mp-economy.md](systems/08-mp-economy.md) | M1, M4 | [#29](https://github.com/asty8926/side-scrolling-game/issues/29) |
| Dungeon rooms, doors, platforms layout, mobs, mini-boss, boss, end rank | [systems/09-dungeons.md](systems/09-dungeons.md) | M2 | [#30](https://github.com/asty8926/side-scrolling-game/issues/30) |
| Boss rush mode | [systems/10-henir.md](systems/10-henir.md) | Later | [#10](https://github.com/asty8926/side-scrolling-game/issues/10) |
| Town, NPCs, dialogue graphs, shops | [systems/11-town-npcs-shops.md](systems/11-town-npcs-shops.md) | M3 | [#31](https://github.com/asty8926/side-scrolling-game/issues/31) |
| Parties, online co-op, channels, hunting fields | [systems/12-fields-channels-party.md](systems/12-fields-channels-party.md) | M5, Later | [#32](https://github.com/asty8926/side-scrolling-game/issues/32) |
| Image provenance and licensing | [images/README.md](images/README.md) | - | - |

Milestone epics: [M0 #35](https://github.com/asty8926/side-scrolling-game/issues/35), [M1 #36](https://github.com/asty8926/side-scrolling-game/issues/36), [M2 #19](https://github.com/asty8926/side-scrolling-game/issues/19), [M3 #20](https://github.com/asty8926/side-scrolling-game/issues/20), [M4 #21](https://github.com/asty8926/side-scrolling-game/issues/21), [M5 #22](https://github.com/asty8926/side-scrolling-game/issues/22), [Later #23](https://github.com/asty8926/side-scrolling-game/issues/23). Research issues: [#33](https://github.com/asty8926/side-scrolling-game/issues/33), [#14](https://github.com/asty8926/side-scrolling-game/issues/14), [#15](https://github.com/asty8926/side-scrolling-game/issues/15), [#34](https://github.com/asty8926/side-scrolling-game/issues/34).

## Glossary (Elsword vocabulary)

| Term | Meaning | Doc |
|---|---|---|
| **Command** | A basic move made of `Z`/`X`/arrow inputs (vs. a *skill* on a skill key). Mostly free; generates MP. | 01 |
| **`Z` / `X`** | Primary / secondary attack keys. Rena: `Z` = kicks, `X` = arrows (and Erendil for Trapping Ranger/Night Watcher). **On AZERTY, `Z` is the physical key labeled W.** | 01 |
| **`>>` / `→→` (DR)** | Double-tap forward = dash/run. `<<` = dash backward. `>>↑` (DRU) = dash jump. `↑↑` (UU) = double jump. | 01 |
| **String / combo** | Chain of commands, e.g. `ZZZZ`, `ZZZ↑Z`, `>>ZX`. Also: the hit counter while the enemy stays in hitstun. | 01, 03 |
| **Hitstun / flinch** | Time a hit target can't act. Values undocumented on ElWiki. | 05 |
| **Hit-stop** | Brief freeze of attacker and target on impact (our design target; not documented for Elsword). | 05 |
| **Delay / skill freeze** | Short time-stop + cut-in when a Special Active or Awakening is used (~0.3 s for awakening since 2021). | 05, 06 |
| **Cancel** | Interrupting a move's recovery with another action (dash, jump, next command, skill). | 03, 05 |
| **`ZZZ<<>` loop** (Asty: `WWW<<>`) | 3 basic hits, back-dash, reverse to face forward, repeat; avoids the 4th hit's knockdown. Community technique. | 03 |
| **KD (Knockdown)** | Per-target counter; each hit adds its *KD value*; any hit past the cap (**PvE 130**, PvP 100) or a KD-type hit knocks down. Resets after a cap knockdown. | 02 |
| **KD value** | How much a hit adds to KD (e.g. Elsword `Z` = 6.6). Can be negative (KD reducers, e.g. Kick -20). | 02 |
| **Launch (LA, LA1, LA2, LA3)** | Hits that send the target up/away; vertical launches extend the KD cap by 34% (decaying). | 02 |
| **Pass (P)** | A move that goes through the target (e.g. `>>ZX`, `>>X`). | 02, 04 |
| **Reset (R)** | A hit that resets KD to 0 when used past the cap (S1 remnant: multi-hit-same-frame attacks). | 02 |
| **Juggle / air combo** | Keeping a launched target in the air with no-KD air attacks. | 03 |
| **Super Armor** | No hitstun/knockdown while active (red outline). | 02 |
| **Stoic Threshold** | Hits a boss can take before auto Super Armor + push-back knockdown. | 02 |
| **Mana Break** | Spend ≥100 MP (hold Z/X to charge) to force your own knockdown and escape a combo. | 02, 08 |
| **MP** | Mana Points; 300 base (+100 passive). Gained by hitting/being hit; spent by skills (Tenacity 70-120, Strength 130-240, Bravery 250-300). | 08 |
| **Active / Special Active / Hyper Active** | Skill categories: cheap utility / big MP skill with cut-in / ultimate (LShift). | 08 |
| **Skill slots** | Default keys A, S, D, C, Q, W, E, R (+F, T); bind by physical position. | 01 |
| **Awakening (Mode)** | Ctrl (Asty: Cmd on Mac) consumes all **awakening beads** (max 3; 1 bead = 100 hits dealt or 50 received) for +20% attack, 30 s per bead; 3 stacks can transform the character. | 06 |
| **Awakening bead / gauge** | The 3 orbs under the portrait and the charge bar next to them. | 06 |
| **Nature's Force (NF)** | Rena's class system: up to 5 NF, +1 per 3 commands landed, passive buffs, NF spent for bonus explosions. | 07 |
| **Way of the Sword** | Elsword's class system: Destruction / Vitality auras (V key). | 06 |
| **Eun Mode** | Ara's 3-bead awakening: possessed by the nine-tailed fox Eun (9 tails, new stance, energy regen). | 06 |
| **Erendil** | Rena's sacred short sword (Trapping Ranger / Night Watcher). Asty calls it her dagger. | 04 |
| **Trapping Ranger (TR) / Night Watcher (NW)** | Rena's 1st / 2nd job on the Erendil path. | 04 |
| **Dungeon / room (stage)** | Instanced level made of rooms joined by doors; a room is cleared by killing its mobs. | 09 |
| **Mob / Mini Boss / Boss** | Regular monster / mid-dungeon elite / final boss. | 09 |
| **Rank (SS/S+, S, A, B, C, D...)** | End-of-dungeon evaluation from category scores (combo, technique, damage taken, time...). Formula unknown; ours is explicit. | 09 |
| **Fever** | Party gauge +1 per room cleared; when full, random party refill and MP bonus. | 09, 12 |
| **Henir's Time and Space** | Boss-rush dungeon: each stage is a boss from other dungeons, with rest areas. | 10 |
| **Village / town** | Walkable hub with NPCs (merchant, blacksmith, accessory shop, alchemist...). | 11 |
| **Hunting Field** | Shared open map with respawning mobs (aggressive yellow bar / reactive green bar), field bosses. | 12 |
| **Channel** | A parallel instance of towns/fields; switch only in towns. | 12 |
| **Party / leader / host** | Group of up to 4 in dungeons; leader manages, host carries the connection in Elsword. | 12 |
| **Heroes Assemble** | Buff scaling stats for smaller parties. | 12 |

## Sources and method

- Primary source: **ElWiki** (https://elwiki.net), text under **CC BY-NC-SA 3.0**; game content © KOG Studios / Nexon / Gameforge / KOG Games. Short quotes only, always cited.
- elwiki.net blocks scripted access (Cloudflare). Pages were read through a fetch tool and through **Wayback Machine** snapshots (2025-12), which also preserve the key-icon images that encode command inputs.
- `https://elwiki.net/w/Awakening` redirects to an unrelated skill; use `https://elwiki.net/w/Awakening_Mode`.
- Some ElWiki pages are flagged outdated (Knockdown) or stubs (Commands: hitstun/launch sections). Community sources (Reddit, forums) are used only where ElWiki is silent and are marked unverified.

## Doc conventions

- Every system doc has YAML frontmatter: `title, system, priority (P0-P3), milestone, status, sources`.
- Sections: What it is in Elsword / Why Asty loves it / What our version must do (checkbox acceptance criteria) / Open questions / Sources / Images.
- When a doc decision is made, update the doc and change `status` to `accepted`; record big technical decisions as ADRs in [`docs/decisions/`](decisions/).
