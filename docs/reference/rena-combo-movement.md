# Rena combo movement reference

How far each hit of Rena's basic strings moves her in Elsword, and what our ranger does. Elsword is the inspiration only: no assets, short citations.

Units: **CW = one character width** = the ranger's hurtbox width = **600 sub-units** in our sim (`data/characters/ranger.tres`). Timing is in **ticks** (60 per second). ElWiki writes attacks as Z/X; our W key is the physical Z key on AZERTY, so `ZZZZ` here is `WWWW` on Asty's keyboard.

Each number is tagged:

- **[doc]** written on ElWiki.
- **[obs]** Asty's own play experience (feedback after M0, 2026-11-25).
- **[est]** our estimate from footage frames (see "Footage" below). Error is about ±0.3 CW: the camera eases, and the scale is calibrated from her walk speed and body width.
- **[ours]** our choice, tuned to the above. Every one is a `# proposal, tune` value in data.

## What ElWiki documents

ElWiki describes direction and kind of motion, never distances or frames.

| Command | ElWiki says (short) | Source |
|---|---|---|
| `ZZZZ` | "Basic 4 kick combo that launches enemies away on the final hit." No movement mentioned. | [Rena](https://elwiki.net/w/Rena), Commands |
| `XXXX` | "Fires 2 arrows, followed by a **backflip** and shooting 2 arrows", then a final knockdown shot. The backflip is on the 3rd input. | [Rena](https://elwiki.net/w/Rena), Commands |
| `>>ZZ` | "**Slide** to kick and launch the target." | [Rena](https://elwiki.net/w/Rena), Commands |
| `>>X` | "**Dodge behind** targets and shoot an arrow." | [Rena](https://elwiki.net/w/Rena), Commands |
| `>>ZX` (Trapping Ranger) | "**slash through** enemies with Erendil, **pushing them along** with you." | [Trapping Ranger](https://elwiki.net/w/Trapping_Ranger), Additional Commands |
| `>>Z…` (Night Watcher) | Dash commands "sprint forward even faster", "rush enemies from the back"; one variant "will move you through the enemy". | [Night Watcher](https://elwiki.net/w/Night_Watcher), Additional Commands |
| `>>ZZ` (Combat Ranger) | "slide once more and finish with an upwards kick"; a 2019 patch note says its "forward movement [was] reduced". So the slide covers real ground. | [Combat Ranger](https://elwiki.net/w/Combat_Ranger), Additional Commands and Updates |
| `XX>>X…` (Wind Sneaker) | "leap forward while staggering them with a knee strike". | [Wind Sneaker](https://elwiki.net/w/Wind_Sneaker), Additional Commands |

## Per-hit movement: reference vs ours

Displacement is per chain step, measured in open space: her x on the next step's first tick minus her x on this step's first tick, multiplied by her facing (+1 right, -1 left). Positive means forward.

| Step | Reference | Tag | Ours (sub) | Ours (CW) | Over ticks | Test range (CW) |
|---|---|---|---|---|---|---|
| `Z` 1st kick | no step | [obs] [est] | 0 | 0 | – | -0.05..0.05 |
| `Z` 2nd kick | ~0.5 CW forward | [obs] [est] | +300 | +0.50 | 0-4 (startup) | 0.35..0.65 |
| `Z` 3rd kick | ~0.5 CW forward | [obs] [est] | +300 | +0.50 | 0-5 | 0.35..0.65 |
| `Z` 4th kick (launcher) | a slightly longer lunge | [ours] | +450 | +0.75 | 0-8 | 0.5..1.0 |
| `X` 1st arrow | no recoil | [obs] | 0 | 0 | – | -0.05..0.05 |
| `X` 2nd arrow | small push back | [obs] | -150 | -0.25 | 2-7 | -0.4..-0.15 |
| `X` 3rd (backflip, 2 arrows) | backflip | [doc] for the backflip, distance [ours] | -900 | -1.50 | 0-14 | -1.8..-1.2 |
| `X` 4th arrow | push back | [obs] | -300 | -0.50 | 9-16 | -0.7..-0.35 |
| `>>Z` slide kick | real slide, keeps dash speed then slows | [doc] for "slide", ~2 CW [est] | +1140 (150→40 per tick) | +1.90 | 0-11 | 1.5..2.5 |
| `>>ZX` dash-through | travels past the target and drags it along; the 2019 rework "dashes farther behind the enemy" | [doc] for direction and drag, distance [est] | +1820 root motion, ends 450 past the far side | ≈ +3.8 travelled | 0-13 | travel 3.0..4.5, ends 1.5..2.2 CW past the target (center to center) |

Measured in the sim with the training dummy (ranger at 0, dummy at +1000): `>>Z` moves her 690 sub (1.15 CW) and pushes the dummy along by the same amount. `>>ZX` then moves her 2259 sub (3.8 CW). It drags the dummy 535 sub and ends 1124 sub (1.9 CW) past it, close enough for `ZZZ` to keep the combo going. Screenshot after `>>WX` in the game (combo 2, the ranger past the dummy and turned to face it): [../evidence/61-dash-wx-end.png](../evidence/61-dash-wx-end.png). Against the dummy, kicks 2-4 push it back 240 sub per hit, so the whole `ZZZZ` walks forward and all four hits land.

## Footage

Clips are reference only. They are not in the repo; they are kept on the build box under `/workspace/gamedev-ref/raw/`.

| Video | What it shows | Used for |
|---|---|---|
| [Rena (Twilight) Re:Born vs Pre-Re:Born command comparisons](https://www.youtube.com/watch?v=FqgY37BAtX4) (60 fps, on-screen keyboard) | Training room, one command per section, with captions | Main source. `ZZ` at 0:02-0:04 (Twilight, the Night Watcher line): the first press barely moves her, and the later presses move about 25 px each (~0.5 CW) [est]. `>>ZX` ("dzxx") at 0:44-0:56: about 480-500 px from the Z press to the stop, roughly 10 CW in total. That includes closing a ~4 CW gap to the target, so the dash-through itself is about 4-6 CW [est]. Re:Boot caption at 0:56-1:12: "dashes farther behind the enemy". |
| [Elsword Rena Renewal Night Watcher ALL Combos](https://www.youtube.com/watch?v=eZ3zNo8gbuk) | Training room with the command list open | Confirms the command set. Camera and costume made per-hit measurement unreliable. |
| [Rena's (WS·NW) movements and combo instructional videos](https://www.youtube.com/watch?v=AgU7HPZANTo) | Captioned techniques (`→→ZX` around 5:30) in PvP | Qualitative only. |
| [Basic Rena Combos](https://www.youtube.com/watch?v=hD_QEfmfQvQ), [Rena Basic Combo](https://www.youtube.com/watch?v=jKNvNP8nAYE) | Mixed dungeon combos | Not usable: cuts and moving targets. |

How the footage was measured: phase correlation of the background strip between frames, with the player area masked out. This gives the camera pan, which equals her world motion because the camera tracks her. Key presses come from the on-screen keyboard overlay. Scale: her walk is ~234 px/s and our walk is 65 sub/tick (3900 sub/s), so 1 px ≈ 15 sub. Her body is ~45 px wide, so 1 CW ≈ 45 px. The two calibrations agree within ~20%.

## Not found

- No frame data or distances for base Rena commands on ElWiki. Every distance above is [obs], [est] or [ours].
- No clean, single-command footage of base Rena `XXXX` recoil. The per-arrow recoil of `X` 2 and 4 comes from Asty's memory [obs]; only the 3rd-input backflip is documented.
- Night Watcher's exact `>>ZX` distance. The Twilight clip shows the same command line, but on a later job.
