---
title: Nature's Force (Rena's class system)
system: natures-force
priority: P1
milestone: M4
status: draft
issue: 28
sources:
  - https://elwiki.net/w/Nature%27s_Force_System
  - https://elwiki.net/w/Rena
  - https://elwiki.net/w/Awakening_Mode
---

# Nature's Force (NF)

> Tracking issue: [#28](https://github.com/asty8926/side-scrolling-game/issues/28) · Milestone epic: [#21](https://github.com/asty8926/side-scrolling-game/issues/21)

## What it is in Elsword

ElWiki "Nature's Force System" (current version; history below):

- "A system exclusive to elves." Shown **below Rena's MP bar** as orbs labeled **NF**. Max **5 NF**.
- **Gain:** hitting targets with basic kicks, arrow commands, and Active skills: **1 NF per 3 commands landed**. A multi-hit command counts once.
- **Awakening:** recovers **5 NF**; each excess NF gives **15 MP** (PvP 3). Awakening with **3 beads** sets NF to 5 permanently for the awakening (NF no longer consumed in 3-bead awakening since 2018).
- **Visuals:** 1 NF faint green orb; 2 NF orb gets a trail; 3 NF more luminous; 4 NF second orb; 5 NF third orb. (Orbs don't map 1:1 to bars.)
- **Passive buff while NF ≥ 1** (PvE, per NF 1→5): Arrow command MP recovery +10%→+50%; Arrow command MP usage -10%→-50%; Critical damage +6%→+30%; Elemental resistance +50→+250; Movement speed +4%→+20%.
- **Damage boost (consumption):** most combos consume **1 NF on the last command** to add an extra **non-flinching** explosion hit (**370%** in PvE). Not for one-command combos; no NF consumed if nothing is hit. Some commands consume more (e.g. a 3-arrow finisher uses 1 per arrow).
- **Special Actives** consume NF for an extra blast on their first hit: **Tenacity 1, Strength 2, Bravery 3** NF; damage 370% × 1.2 × NF used. Explosion "hits all targets in range and ignores defense and guard", "does not inflict hitstun but can proc Attributes."

History (relevant to "classic" feel): added KR 01/02/2014; originally 7 then 6 commands per NF; reduced to 3 in 2016; MP recovery effects reduced over time; damage-reduction effect removed 2016. Nature's Force did **not** exist in Elsword's first years (2007-2013).

## Why Asty loves it

Named explicitly as Rena's Awakening-related system he wants (https://elwiki.net/w/Nature%27s_Force_System). It rewards **comboing with commands** (not spamming skills) with damage and MP efficiency, which matches his "no mana potions, combos fuel everything" goal.

## What our version must do (acceptance criteria)

- [ ] Class resource `nf: 0..=5` on the Rena-like character, shown under the MP bar with escalating orb VFX.
- [ ] +1 NF per 3 **distinct commands** that land (multi-hit command = 1). Counter in data.
- [ ] While NF ≥ 1: passive buffs from a per-NF table in data (start with arrow MP gain ↑, arrow MP cost ↓, move speed ↑; skip elemental/crit until those stats exist).
- [ ] Last command of a string with ≥2 commands consumes 1 NF on hit and spawns a non-flinching AoE explosion that ignores defense (damage % in data). No consumption on whiff.
- [ ] Skills consume NF by tier (1/2/3) for a bonus blast.
- [ ] Awakening hook: +5 NF, excess → MP; 3-bead awakening locks NF at 5 (no consumption) for the duration.
- [ ] Unit tests for gain counting, consumption on hit only, awakening lock.

## Open questions

1. Our name/theme for NF (can't ship "Nature's Force").
2. Since NF is post-2014 Elsword, does Asty want it in the "classic" feel, or a simplified version? He named it, so default: include, simplified.
3. Show the NF explosion's damage separately in the combo counter?

## Sources

- https://elwiki.net/w/Nature%27s_Force_System
- https://elwiki.net/w/Rena (Special Ability section)
- https://elwiki.net/w/Awakening_Mode

## Images

| Local | What | Source |
|---|---|---|
| `../images/natures-force/NSPoster.png` | KR promo poster for the system (2014) | https://elwiki.net/w/Nature%27s_Force_System |
| `../images/natures-force/Ns1.png` | NF gauge UI under the MP bar | same |
| `../images/natures-force/NF2.gif` | Orbs appearing around Rena | same |
| `../images/natures-force/Ns4.gif` | NF extra-attack explosion | same |
| (404 in archive) `NF5.png` buff/MP-regen state | https://elwiki.net/wiki/images/thumb/1/1f/NF5.png/200px-NF5.png |

![NF gauge](../images/natures-force/Ns1.png)
![NF orbs](../images/natures-force/NF2.gif)
