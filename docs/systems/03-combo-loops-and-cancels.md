---
title: The ZZZ<<> loop (WWW<<> on AZERTY) and infinite combo cycles
system: combo-loops
priority: P0
milestone: M1
status: draft
sources:
  - https://elwiki.net/w/Knockdown
  - https://elwiki.net/w/Trapping_Ranger
  - https://elwiki.net/w/Rena
  - https://www.reddit.com/r/elsword/comments/6aavnv/raven_rf_combo_help/
  - https://www.reddit.com/r/elsword/comments/1ci7dll/raven_can_zz_loop_without_x/
---

# The `ZZZ<<>` loop and infinite combo cycles

Depends on: [01-combat-inputs.md](01-combat-inputs.md), [02-kd-knockdown.md](02-kd-knockdown.md), [05-game-feel.md](05-game-feel.md).

## What it is in Elsword

### The loop (community technique)

Not documented as a named technique on ElWiki pages read. Community description (Reddit, unverified, consistent with Asty's account):

> Do `ZZZ`, then immediately back-dash and turn back: `ZZZ<<>  ZZZ<<>  ZZZ<<>`. The back-dash cancels the end of the third hit before the 4th (knockdown) hit, and turning forward resets the combo string so `ZZZ` starts again while the enemy is still in hitstun. Avoid pressing the 4th `Z`.

Mechanically this relies on four Elsword properties:

1. **The basic string's 4th hit knocks down** (classic Rena `ZZZZ`; Elsword `ZZZZ` = type R/KD on the KD table). So you stop after 3.
2. **Movement cancels attack recovery.** The `<<` dash input during the recovery of the 3rd hit interrupts it. ElWiki supports dash-canceling in general: NW patch 05/29/2014 "Can cancel all [X] inputs earlier by dashing"; TR `ZZZZZ`'s final Z "can be interrupted by movement"; Rena patch 2019 "adjusted command responsiveness to allow for less restrictive movement."
3. **Reversing direction mid-dash stops the dash and turns the character** (`>` after `<<`), putting her facing the enemy at close range with the combo counter reset.
4. **Enemy hitstun outlasts the cancel**: the enemy is still flinching when the new `ZZZ` starts, so it's a true loop. Each pass adds ~3 hits of KD (e.g. ~21 KD for Elsword-like values), so the loop alone eventually hits the **KD cap** (130 PvE) and forces a knockdown. That is why "infinite" combos need cycle management (next section).

A built-in version of the same idea exists in Trapping Ranger's kit: "Holding [←] or [→] during the 4th [Z] will reset the combo with little to no delay" (ElWiki, Trapping Ranger).

### Infinite combo cycles (managing KD)

Asty's description: "doing just enough combos on them to increase the KD and then decrease or reset it then cycle... comboing them, then knocking them up, doing either aerial combo or putting them back down without knocking them down and cycling."

What ElWiki documents that makes this possible:

- **Launch moves extend the KD cap** (+34%, decays over time) instead of adding toward it. Rena's launchers: `ZZZ↑Z` (LA3), `>>ZZ` (LA); NW `>>(pause)→↑ZZ` (LA, Super Armor overhead slash).
- **Air attacks without knockdown**: Rena `↑X` ("without knocking down"), `↑↑Z` and `↑↑X` ("without knocking down", landing shockwave), `>>↑Z` (no longer knocks down since 2013).
- **Pass moves (P)** reposition through the enemy without KD-ing (TR `>>ZX`, `>>↑ZZ`, `↑↑ZX`), letting you re-face and continue.
- **KD reducers**: skills with negative KD (e.g. Kick -20).
- **Reset rule** (S1 remnant): at cap, a multi-hit-same-frame attack resets KD to 0.

A cycle therefore looks like: ground loop (`ZZZ<<>` x N) → launcher → air string (no-KD air hits) → land and re-ground the enemy without a KD hit → repeat, inserting KD reducers/resets as the gauge nears the cap. Exact Rena cycles that were "infinite" in a given season are **not documented** on ElWiki; they changed with patches.

## Why Asty loves it

> "What I absolutely love in Elsword is how there's a technique that involves doing this combo keys loop: WWW<<>... used to avoid doing 'WWWW' where 4 basic attacks knock down... resulting in not being able to combo them right after."

This loop is the **#1 feel test** for the whole project. If it doesn't feel crisp, M1 is not done.

## What our version must do (acceptance criteria)

- [ ] On a training dummy (KD visible in debug), the inputs `ZZZ<<>` repeated 5 times keep the dummy in hitstun the whole time **without** a knockdown, as long as the KD cap is not reached.
- [ ] On AZERTY the same physical sequence is `WWW` + `←←` + `→`.
- [ ] `ZZZZ` (4 hits) always knocks down (classic behavior), and the KD debug shows why (type KD).
- [ ] Cancel windows are data: each move declares from which frame a **movement/dash cancel** is allowed (`cancel.dash_from_frame`). The 3rd basic hit must allow dash-cancel after its active frames.
- [ ] Reversal: during a backward dash, pressing forward stops the dash within ≤2 ticks and faces forward; the next `Z` starts the string at hit 1.
- [ ] Hitstun duration per hit is data (`hitstun_ticks`). Default tuned so that `ZZZ<<>Z` connects at 60 Hz with human timing (target: a window of at least ~6-8 ticks for the restart; **our tuning target, not Elsword data**).
- [ ] Repeating the loop eventually reaches the KD cap and the dummy is knocked down (proves KD is respected; no true infinite without cycle management).
- [ ] A scripted **input replay test** (headless) runs `ZZZ<<>` x5 at fixed frame timings and asserts: hit count, no knockdown before cap, knockdown after cap. This runs in CI.
- [ ] Cycle test: ground loop → `ZZZ↑Z` launcher → `↑X` air hits → land → loop again; assert KD cap was extended by the launcher.
- [ ] Combo counter UI (hit count + damage) like Elsword's, resets when the target leaves hitstun.

## Open questions

1. Hitstun values: no official data. Plan: frame-count Elsword videos (YouTube) for `ZZZ<<>` timing to set a baseline.
2. Do we allow the loop on bosses? Elsword uses stoic thresholds / super armor on bosses. Proposal: yes on mobs, bosses get stoic thresholds.
3. Should the reversal (`>`) be required, or does `<<` alone reset the string? Asty's input is `<<>`; keep that.
4. Allow the TR-style "hold direction during 4th Z to reset" as an easier alternative? Proposal: yes, it's in the Rena-line kit already.

## Sources

- ElWiki Knockdown (KD types, launch extension, reset rule): https://elwiki.net/w/Knockdown
- ElWiki Trapping Ranger (reset by holding a direction, movement interrupt): https://elwiki.net/w/Trapping_Ranger
- ElWiki Night Watcher (dash cancel of X inputs): https://elwiki.net/w/Night_Watcher
- ElWiki Rena (no-knockdown air attacks, 2019 responsiveness patch): https://elwiki.net/w/Rena
- Reddit (community, unverified): https://www.reddit.com/r/elsword/comments/6aavnv/raven_rf_combo_help/ , https://www.reddit.com/r/elsword/comments/1ci7dll/raven_can_zz_loop_without_x/

## Images

No dedicated image exists on ElWiki for this loop. Recommended: record a short reference clip from Elsword gameplay (or find a YouTube combo video) and link it here; keep frame timings in a table.

![ZZZ<<> key icons](../images/input-icons/Z.png) ![](../images/input-icons/Z.png) ![](../images/input-icons/Z.png)
