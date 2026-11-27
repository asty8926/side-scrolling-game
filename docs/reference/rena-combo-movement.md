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
| `>>Z` slide kick | run converts to the slide immediately on Z [seen]; footage length ~1.5-2 CW in ~15-20 frames [guess]; Asty asked twice for it to go much further (first 1.9, then 3.80 still too short) | [seen] for instant convert, [guess] for footage length, distance [ours] | +3900 (420→60, snappy curve) | +6.50 | 0-15 | 5.8..7.5 |
| `>>ZX` dash-through | X can cancel the slide from the first ticks, not only on connect [obs]; it is a fixed-distance pass-through even with no enemy, and hits each target along the path once [obs]; footage Reboot/Night Watcher travels ~3-4 CW past a target [seen] | [obs] for no-enemy full dash and multi-hit, [seen] for past-target travel, distance [ours] | +4800 root motion (580→20); pass for the whole move; `pass_overshoot` 0 | +8.00 of slash (plus leftover slide if X is late) | 0-15 | slash 7.0..9.0 in open space; ends ≥6 CW past the training dummy |

Open-space `>>Z` travels 3900 sub (6.50 CW). Against the training dummy (ranger at 0, dummy at +1000), leftover root motion still drives the dummy forward during the slide so they travel together, and the kick still lands. `>>ZX` is a fixed 4800 sub (8.00 CW) pass-through: it ignores pushboxes for the whole move, so it covers that distance in empty space as well as through one or more enemies. Each enemy on the path is hit once. A mid-slide X (after some of the slide has already travelled) can total a bit over 10 CW; that is accepted [ours] so empty-space `>>WX` itself stays long. `dash_z.cancel_from` is 0, so X can cancel from the first ticks; a press after the kick's first active frame still lets the slide hit, then the slash starts. Because the slash now ends far past the dummy, a follow-up `WWW` will usually miss unless the player runs back. That is fine [ours]. Screenshot after `>>WX` in an earlier, shorter build: [../evidence/61-dash-wx-end.png](../evidence/61-dash-wx-end.png). Against the dummy, kicks 2-4 still push it back 240 sub per hit, so a standing `ZZZZ` walks forward and all four hits land.

## `ZZZ` and the `ZZZ<<>` loop

| Thing | Reference | Tag | Ours |
|---|---|---|---|
| Time between kicks | ~10-15 frames | [guess] | cancel window opens at the first recovery tick (8, 8, 9); a buffered press starts the next kick immediately |
| Later Z during a kick | cancels the current kick's recovery | [seen] | existing `cancel_into` + 8-tick input buffer |
| Forward step per kick | ~0.25-0.5 CW, to stay glued as the target is pushed | [seen] | Z1 0, Z2/Z3 +0.50 CW, Z4 +0.75 CW (unchanged) |
| `<<` of `ZZZ<<>` (and `XXX<<>`) | a double-tap always starts a run in that direction, including out of recovery [obs]; footage of a no-step twitch was just `>` arriving immediately after | [obs] (overrides the earlier no-step reading) | from the first recovery tick, a double-tap `<<` / `>>` ends the move and starts a dash on the same tick. A single back press does not lock the fighter or swallow the first tap of a later `<<`. |
| `>` after `<<` | cancels the run that just started and flicks facing; combo state is already idle, so the next Z/X is the first hit | [obs] | existing `dash_reverse`: the opposite press the frame it is pressed stops the dash and turns around |
| Chaining `>>Z` / `>>ZX` | no dead frames between loops [obs] | [obs] | recovery (tick 10 on the slide, tick 20 on the slash) is dash-cancellable; same-tick Z after `>>` still starts the next slide. Old uncancelable tail (ticks 21-23 plus idle) is gone. |

The 4th kick or 4th arrow is avoided because `<<` (the double-tap) cancels recovery and `>` cancels that run, so the next press is Z1 / X1. The same rule applies to mixed chains (for example `ZZX<<>Z`). `WWW<<>WWW<<` must end in a left run: the first `<<>` must not eat the later `<<`.

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

## Walk and run speed

Footage walk is about 234 px/s with a ~45 px body, so roughly **5.2 CW/s** [est]. Our previous walk was already 65 sub/tick = 6.5 CW/s, but Asty still found it far too slow on screen. New values [ours], both in `data/characters/ranger_movement.tres`:

| | Previous | Ours | Notes |
|---|---|---|---|
| Walk | 65 sub/tick (6.5 CW/s, 3.9 m/s) | **120 sub/tick (12.0 CW/s, 7.2 m/s)** | Clearly above the footage estimate so the room feels like Elsword. |
| Run | 150 sub/tick (15.0 CW/s) | **240 sub/tick (24.0 CW/s, 14.4 m/s)** | 2× walk, still clearly faster than a walk. |

The older footage scale note ("our walk is 65 sub/tick, so 1 px ≈ 15 sub") was a calibration at that time; the pixel-to-CW figure (~45 px/CW) does not change.

## Display

The game's base viewport is **1920×1080**, with `canvas_items` stretch and `aspect` expand so a 3D side camera keeps its aspect. `allow_hidpi` is on for macOS Retina. The playable build launches in borderless fullscreen (`game/view/display_mode.gd`); Alt+Enter or F11 toggles a 1920×1080 window. Headless CI stays windowed. HUD and debug text are sized for the 1080p canvas. This is view-only; the sim is unchanged.

## Footage


Clips are reference only. They are not in the repo; they are kept on the build box under `/workspace/gamedev-ref/raw/` (cuts under `/workspace/gamedev-ref/clips/`). Frame notes below are tagged [seen] when read off a clip and [guess] when estimated from it.

| Video | What it shows | Used for |
|---|---|---|
| [Rena (Twilight) Re:Born vs Pre-Re:Born command comparisons](https://www.youtube.com/watch?v=FqgY37BAtX4) (60 fps, on-screen keyboard) | Training room, one command per section, with captions | Main source. `ZZ` at 0:02-0:04 (Twilight, the Night Watcher line): the first press barely moves her, and the later presses move about 25 px each (~0.5 CW) [est]. `>>ZX` ("dzxx") at 0:44-0:56: about 480-500 px from the Z press to the stop, roughly 10 CW in total. That includes closing a ~4 CW gap to the target, so the dash-through itself is about 4-6 CW [est]. Re:Boot caption at 0:56-1:12: "dashes farther behind the enemy". |
| [Elsword Rena Renewal Night Watcher ALL Combos](https://www.youtube.com/watch?v=eZ3zNo8gbuk) (cut 0:00-0:30) | Training room with the command list open | Body collision [seen]: she stops against the dummy and runs in place; the dummy is not shoved by walking. A long freeze on hit in this clip is the Ice Eldrit weapon proc, not a default mechanic (Asty, 2026-11-26). |
| [Rena's (WS·NW) movements and combo instructional videos](https://www.youtube.com/watch?v=AgU7HPZANTo) | Captioned techniques (`→→ZX` around 5:30) in PvP | Qualitative only. |
| [Basic Rena Combos](https://www.youtube.com/watch?v=hD_QEfmfQvQ), [Rena Basic Combo](https://www.youtube.com/watch?v=jKNvNP8nAYE) | Mixed dungeon combos | Not usable: cuts and moving targets. |

How the footage was measured: phase correlation of the background strip between frames, with the player area masked out. This gives the camera pan, which equals her world motion because the camera tracks her. Key presses come from the on-screen keyboard overlay. Scale: her walk is ~234 px/s and our walk at the time of that measurement was 65 sub/tick (3900 sub/s), so 1 px ≈ 15 sub. Her body is ~45 px wide, so 1 CW ≈ 45 px. The two calibrations agree within ~20%.

## Not found

- No frame data or distances for base Rena commands on ElWiki. Every distance above is [obs], [est] or [ours].
- No clean, single-command footage of base Rena `XXXX` recoil. The per-arrow recoil of `X` 2 and 4 comes from Asty's memory [obs]; only the 3rd-input backflip is documented.
- A clean `>>Z` slide on its own. In the Twilight `dzx` section (0:45.37-0:45.47) X follows Z after only 6 frames, so the slide cannot be separated from the dash-through. Footage of similar slides is ~1.5-2 CW [guess]; ours is 6.50 CW [ours] because Asty asked for it to go much further than 3.80 CW.
- Night Watcher's exact `>>ZX` distance. The Twilight clip shows the same command line, but on a later job.
