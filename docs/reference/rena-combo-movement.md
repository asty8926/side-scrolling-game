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
| `>>Z` slide kick | run converts to the slide immediately on Z [seen]; footage length ~1.5-2 CW in ~15-20 frames [guess]; Asty asked for it to go much further than our previous 1.9 CW, so this is doubled on purpose | [seen] for instant convert, [guess] for footage length, distance [ours] (Asty's choice, longer than footage) | +2280 (300→80 per tick) | +3.80 | 0-11 | 3.2..4.5 |
| `>>ZX` dash-through | X can be pressed as soon as the slide connects (hit-cancel) [seen]; Reboot/Night Watcher travels ~3-4 CW past the target before the backward arrow [seen]; we land at 3.5 CW past [ours] | [seen] for hit-cancel and past-target travel, distance [ours] | +1820 root motion, ends 1500 past the far side | ≈ +5.4 travelled | 0-13 | travel 4.5..6.5, ends 3.0..4.2 CW past the target (center to center) |

Open-space `>>Z` now travels 2280 sub (3.80 CW). Against the training dummy (ranger at 0, dummy at +1000), the slide is no longer eaten by the body box: leftover root motion drives the dummy forward so they travel together, and the kick still lands. `>>ZX` `pass_overshoot` is 1500, so she ends 2100 sub (3.5 CW, center to center) past the dummy. `dash_z.cancel_from` is 6 (the first active tick) so X can hit-cancel when the slide connects. The first two follow-up kicks were lengthened earlier so WWW still lands after the pass (`Z` 1: offset 800, width 900; `Z` 2: offset 650, width 800); whether standing W should stay that long is still Asty's call. Screenshot after `>>WX` in an earlier build: [../evidence/61-dash-wx-end.png](../evidence/61-dash-wx-end.png). Against the dummy, kicks 2-4 push it back 240 sub per hit, so the whole `ZZZZ` walks forward and all four hits land.

## `ZZZ` and the `ZZZ<<>` loop

| Thing | Reference | Tag | Ours |
|---|---|---|---|
| Time between kicks | ~10-15 frames | [guess] | cancel window opens at the first recovery tick (8, 8, 9); a buffered press starts the next kick immediately |
| Later Z during a kick | cancels the current kick's recovery | [seen] | existing `cancel_into` + 8-tick input buffer |
| Forward step per kick | ~0.25-0.5 CW, to stay glued as the target is pushed | [seen] | Z1 0, Z2/Z3 +0.50 CW, Z4 +0.75 CW (unchanged) |
| `<<` of `ZZZ<<>` | she instantly faces away, no step | [seen] | `dir_cancel_from` on Z1-Z3; one back press ends the move, faces away, vx = 0 |
| `>` after `<<` | snaps back to facing the enemy; combo state resets to neutral | [seen] | forward press (or Z/X) restores the original facing and idle, so the next Z is Z1 |
| Whole `<` `>` twitch | under 10 frames before the next Z | [guess] | 2 ticks in the scripted test; no travel |

The 4th kick is avoided because `<<` cancels Z3 during recovery. `<<` alone is not enough to restart the string facing the enemy; `>` is required (docs/systems/03).

## Body collision

Walking or running into the dummy does **not** move it; the player stops at its box and (if dashing) runs in place. [seen] in the Night Watcher training-room clip. Only attacks displace a monster: a slide's leftover root motion drives the dummy forward so `>>Z` still covers its full distance instead of bouncing off the box.

## Hit-stop

A long freeze on hit, seen in the Night Watcher clip (`eZ3zNo8gbuk`, 0:00-0:30), is **not** a default Rena mechanic. Asty identified it as the Ice Eldrit (Eldrit stone) Freeze proc on the weapon enchant. We do **not** copy that.

We do keep a very short tick-based impact pause: **2 ticks** [ours], tunable per move as `MoveData.hitstop_ticks` in `data/characters/ranger_moves.tres` (default 2). During those ticks the sim still records input, so a buffered cancel starts as soon as the pause ends. This is not `Engine.time_scale`. A longer freeze would be a new enchant or skill later, not a basic-hit rule.

Heavy hits (Z4, X4, `>>ZX`, `>>ZZ`) also pulse a small view-only camera shake (`CameraParams.shake_amplitude`, default 0.08 m). It is not part of the sim.



## Arrows (`XXXX`)

ElWiki describes the string ("Fires 2 arrows, followed by a backflip and shooting 2 arrows", then a knockdown shot) but gives no range or frame data. No clean open-space `XXXX` clip was available (training clips hit a dummy at close range; dungeon clips cut). Values below are [ours], chosen so the arrows feel closer to a screen-width shot and so mashing cannot skip the bow animation.

| Thing | Previous | Ours | Notes |
|---|---|---|---|
| Arrow speed (`X` 1–3) | 400 sub/tick | 400 sub/tick (unchanged) | 24 m/s (400 sub/tick at 60 ticks/s) |
| Lifetime (`X` 1–3) | 30 ticks (12.0 m of flight, 20 CW) | **17 ticks (6.8 m of flight, 11.3 CW)** | Spawns 0.4 m in front of the ranger and disappears 7.2 m from her, just inside a visible half-screen (~7.5 m at the default camera). |
| Final shot (`X` 4) | 500 sub/tick × 30 (15.0 m of flight) | **500 × 14 ticks (7.0 m of flight, 11.7 CW)** | Disappears 7.4 m from the ranger. Same idea, slightly snappier shot. |
| `X` 1 and 2 `cancel_from` | 8 ticks | **16 ticks** | The arrow fires at tick 6; the next press cannot start until 16, so a mash cannot go faster than the animation. Buffer still delivers a press that arrived a little early. |
| `X` 3 `cancel_from` (backflip, two arrows) | 16 | **22** | After the second arrow (spawn tick 14) plus a short follow-through. |

Only a press in the 8-tick buffer before `cancel_from` is kept, and then it starts at the first legal tick. An earlier press expires; it does not start the next arrow early, and it is not held until the cancel window opens.

## Command timing for `>>Z`

`>>Z` (Asty's `>>W`) is a dash command: it must follow a `>>` run, not a walk. Three timings all start the sliding kick:

- W while still holding the run, including many ticks after the double-tap.
- W on the same tick as the second →. Combat selects the attack before movement starts the dash, so this tick has to count as a dash command on its own.
- W up to `dash_attack_linger_ticks` (12 ticks, [ours]) after the run key is released. After that window, W is the standing first kick and does not slide.

## Footage


Clips are reference only. They are not in the repo; they are kept on the build box under `/workspace/gamedev-ref/raw/` (cuts under `/workspace/gamedev-ref/clips/`). Frame notes below are tagged [seen] when read off a clip and [guess] when estimated from it.

| Video | What it shows | Used for |
|---|---|---|
| [Rena (Twilight) Re:Born vs Pre-Re:Born command comparisons](https://www.youtube.com/watch?v=FqgY37BAtX4) (60 fps, on-screen keyboard) | Training room, one command per section, with captions | Main source. `ZZ` at 0:02-0:04 (Twilight, the Night Watcher line): the first press barely moves her, and the later presses move about 25 px each (~0.5 CW) [est]. `>>ZX` ("dzxx") at 0:44-0:56: about 480-500 px from the Z press to the stop, roughly 10 CW in total. That includes closing a ~4 CW gap to the target, so the dash-through itself is about 4-6 CW [est]. Re:Boot caption at 0:56-1:12: "dashes farther behind the enemy". |
| [Elsword Rena Renewal Night Watcher ALL Combos](https://www.youtube.com/watch?v=eZ3zNo8gbuk) (cut 0:00-0:30) | Training room with the command list open | Body collision [seen]: she stops against the dummy and runs in place; the dummy is not shoved by walking. A long freeze on hit in this clip is the Ice Eldrit weapon proc, not a default mechanic (Asty, 2026-11-26). |
| [Rena's (WS·NW) movements and combo instructional videos](https://www.youtube.com/watch?v=AgU7HPZANTo) | Captioned techniques (`→→ZX` around 5:30) in PvP | Qualitative only. |
| [Basic Rena Combos](https://www.youtube.com/watch?v=hD_QEfmfQvQ), [Rena Basic Combo](https://www.youtube.com/watch?v=jKNvNP8nAYE) | Mixed dungeon combos | Not usable: cuts and moving targets. |

How the footage was measured: phase correlation of the background strip between frames, with the player area masked out. This gives the camera pan, which equals her world motion because the camera tracks her. Key presses come from the on-screen keyboard overlay. Scale: her walk is ~234 px/s and our walk is 65 sub/tick (3900 sub/s), so 1 px ≈ 15 sub. Her body is ~45 px wide, so 1 CW ≈ 45 px. The two calibrations agree within ~20%.

## Not found

- No frame data or distances for base Rena commands on ElWiki. Every distance above is [obs], [est] or [ours].
- No clean, single-command footage of base Rena `XXXX` recoil. The per-arrow recoil of `X` 2 and 4 comes from Asty's memory [obs]; only the 3rd-input backflip is documented.
- A clean `>>Z` slide on its own. In the Twilight `dzx` section (0:45.37-0:45.47) X follows Z after only 6 frames, so the slide cannot be separated from the dash-through. Footage of similar slides is ~1.5-2 CW [guess]; ours is 3.80 CW [ours] because Asty asked for it to go much further.
- Night Watcher's exact `>>ZX` distance. The Twilight clip shows the same command line, but on a later job.
