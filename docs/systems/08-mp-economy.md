---
title: MP economy without mana potions
system: mp-economy
priority: P1
milestone: M1 (basic gain/spend), M4 (passives, class bonuses)
status: draft
issue: 29
sources:
  - https://elwiki.net/w/Statistics
  - https://elwiki.net/w/Rena
  - https://elwiki.net/w/Skills
  - https://elwiki.net/w/Mana_Break
  - https://elwiki.net/w/Way_of_the_Sword
  - https://elwiki.net/w/Nature%27s_Force_System
  - https://www.reddit.com/r/elsword/comments/1gx1dlh/someone_can_explain_me_how_mana_work/
---

# MP economy (no mana potions)

> Tracking issue: [#29](https://github.com/asty8926/side-scrolling-game/issues/29) · Milestone epic: [#36](https://github.com/asty8926/side-scrolling-game/issues/36) · Research: [#34](https://github.com/asty8926/side-scrolling-game/issues/34)

## What it is in Elsword

**Documented on ElWiki:**

- **Max MP:** "All characters start out with a default amount of **300 MP**, but gain an additional **100 MP** through Class Passives." Some classes temporarily raise max MP. (Statistics)
- **MP on hit / when hit:** stats "MP Recovery Upon Attack Increase" ("Increases the amount of MP gained upon attacking enemies", max 50%) and "MP Recovery Upon Attacked Increase" (max 50%). These replaced Accuracy/Evasion in 2016. So **dealing and receiving hits both generate MP** by design.
- **Commands as MP engine:** "Commands that do not cost any MP tend to be used to quickly restore it instead." (Commands)
- **Rena's MP regeneration stance:** "After a second standing still, she enters her MP regeneration mode, which recovers **5 MP per second** (half of Aisha's rate)." (Rena). PvP nerf 2024: halved after 2 s of charging.
- **Arrows cost MP:** "As Rena's arrows require MP, Rena can also regenerate MP." Arrow commands list 2-15 MP per input.
- **Skill MP costs (Special Actives):** **Tenacity 70-120 MP, Strength 130-240 MP, Bravery 250-300 MP**; Actives ("Flexibility") are low cost. (Skills)
- **Mana Break** spends ≥100 MP to escape a combo (see [02-kd-knockdown.md](02-kd-knockdown.md)).
- **Class MP mechanics:** Elsword's Aura of Vitality: "MP Gain when Attacked increase: 100%", "Vitality-based Command/Skill MP recovery per hit increase: 100%" (PvE). Rena's NF: arrow MP recovery up to +50%, arrow MP usage down to -50%; excess NF on awakening → 15 MP each. Ara's Energy is "a substitute for MP"; excess energy on awakening heals 5% MP per bead.

**Community (not on ElWiki, unverified):** a `Z` command hit gives **about 5 MP per hit**, there is a passive regen of **~1 MP/s**, and being hit also gives MP (Reddit, 2024).

**Early-Elsword specifics** Asty remembers ("combos, passives and spells were enough to get mana back"): exact historical values (e.g. MP per hit in 2008-2012, the old 3-segment MP bar with 100/200/300 tier costs) are **not documented** on pages read. To verify via old patch notes/videos if parity matters.

## Why Asty loves it

> "I also love MP (mana point) regen spells for non-support classes... I want to avoid using mana potions altogether and want to rely on the good ol' Elsword in its first years where combos, passives and spells were enough to get mana back instead of spamming spells and potions without comboing ever."

The economy must make **comboing the way you earn skills**.

## What our version must do (acceptance criteria)

- [ ] **No MP potions exist** in the game's item data (lint check in CI: no consumable with an MP-restore effect).
- [ ] MP sources (all values in one data file): MP per hit dealt by commands (start ~5, per-move override), MP per hit received (start ~5-10), idle regen (start 1 MP/s), Rena-like **charge stance** (stand still ≥1 s → 5 MP/s, interrupted by any input), class passives/skills that grant MP.
- [ ] MP sinks: arrow commands (2-15), skills by tier (Active ~30-60, Tenacity ~70-120, Strength ~130-240, Bravery ~250-300), Mana Break (later).
- [ ] Max MP 300 at start (+100 via passive later). Optional: MP bar drawn in 3 segments of 100 so tiers read instantly (classic look, to confirm with Asty).
- [ ] Balancing test (simulation): a scripted "average combo" run (`ZZZ<<>` loops + one skill) on a mob pack should earn a Tenacity skill roughly every N seconds (N to be tuned with Asty; record target here).
- [ ] At least one **MP-regen skill or passive** for the Rena-like kit (Asty explicitly likes these on non-support classes), e.g. a buff that raises MP per hit for X seconds.
- [ ] Skills fail gracefully when MP is insufficient (feedback sound + UI flash, no input eaten for the next buffered command).

## Open questions

1. Should hits received give MP (comeback mechanic) at the same rate as Elsword (community: yes)? Proposal: yes.
2. MP per hit for multi-hit arrows/skills: per hit or per move? Elsword appears per hit; risk of skill loops feeding themselves. Proposal: skills give 0 MP on their own hits unless tagged.
3. Do we keep the stand-still charge stance? It's iconic for Rena/Aisha, but slows dungeon pace. Proposal: keep, with low rate.

## Sources

- https://elwiki.net/w/Statistics
- https://elwiki.net/w/Commands
- https://elwiki.net/w/Rena (MP Regeneration section)
- https://elwiki.net/w/Skills (Special Active tiers by MP cost)
- https://elwiki.net/w/Mana_Break
- https://elwiki.net/w/Way_of_the_Sword
- https://elwiki.net/w/Nature%27s_Force_System
- Reddit (community): https://www.reddit.com/r/elsword/comments/1gx1dlh/someone_can_explain_me_how_mana_work/

## Images

| Local | What | Source |
|---|---|---|
| `../images/combat-inputs/MPRegainR.gif` | Rena's MP regeneration stance (animated) | https://elwiki.net/w/Rena |
| `../images/combat-inputs/Combat_Pose_-_Rena_(Mana_Charging).png` | Mana charging stance | https://elwiki.net/w/Rena |
| `../images/mp-economy/Manabreak1.jpg` | Mana Break charge bar in the MP bar | https://elwiki.net/w/Mana_Break |

![Rena MP regen](../images/combat-inputs/MPRegainR.gif)
