---
title: Game feel - hit-stop, impact, responsive input (buffering), canceling combos into skills
system: game-feel
priority: P0
milestone: M1 (core), polish continues every milestone
status: draft
issue: 26
sources:
  - https://elwiki.net/w/Commands
  - https://elwiki.net/w/Skills
  - https://elwiki.net/w/Awakening_Mode
  - https://elwiki.net/w/Eun%27s_Power
  - https://elwiki.net/w/Status_Effects/Super_Armor
---

# Game feel: hit-stop, impact, input buffering, cancels into skills

> Tracking issue: [#26](https://github.com/asty8926/side-scrolling-game/issues/26) · Milestone epic: [#36](https://github.com/asty8926/side-scrolling-game/issues/36) · Research: [#14](https://github.com/asty8926/side-scrolling-game/issues/14)

## What it is in Elsword

**ElWiki has almost no hard data here.** The Commands page's "Hitstun", "Launch" and "Knockback" sections are empty stubs. What is documented:

- **Skill "delay" / time-stop:** Special Actives "cause delay, a small period of time-stop, followed by the image cut in of the character as the character executes the skill. If the dynamic camera is active, the camera angle will change to an epic view." (Skills page). Buffs like the old Accelerators "cause delay"; Seals do not.
- **Awakening freeze:** "Most characters... have a delay when awakening that freezes the screen (around 0.7 secs.)", later patched: "Freeze frames after the character's animation is complete adjusted to be about **0.3 seconds** for all characters" (KR 07/08/2021).
- **Hitstun intensities** exist (Commands page mentions "hitstun and its various intensities") but values are undocumented. NF explosions "do not inflict hitstun"; Rena's NF bonus hit is "non-flinching."
- **Super Armor** removes hitstun/flinch on the armored entity (see [02-kd-knockdown.md](02-kd-knockdown.md)).
- **Movement cancels:** "Can cancel all [X] inputs earlier by dashing" (NW, 2014); TR's final `Z` "can be interrupted by movement"; Rena's 2019 patch "adjusted command responsiveness to allow for less restrictive movement."
- **Skill linking (Ara):** "Ara is able to cancel certain skills by using another skill... right before the previous skill used ends. This will cancel the skill's final hit and chain directly into the next skill", with stance-specific chains unlocking "Secret Arts" (Eun's Power page). This is Elsword's documented skill-to-skill cancel.
- **Commands into skills:** In Elsword, skills (A/S/D/C...) can be used during command strings to continue a combo; this is common knowledge of play but **no rule text was found** on pages read for which frames allow it. To verify via gameplay video.
- **Hit-stop on normal hits** (the brief freeze of attacker+target on impact): **not documented** on ElWiki. Asty lists it as a top feel item, so it is a design target, not a copy.

## Why Asty loves it

He picked these three from the options: "Hit-stop and impact, Fast, responsive input, Cancels into skills."

## What our version must do (acceptance criteria)

All numbers below are **our starting proposals** (60 Hz simulation), to be tuned by playtest, not Elsword data.

**Hit-stop**
- [x] On hit, attacker and target pause for `hitstop_ticks` (per move, data; default **2 ticks** [ours]). This is a very short tick-based impact pause, not a long freeze. A long freeze in some Night Watcher footage is the Ice Eldrit weapon proc, which we do not copy. The pause is part of the deterministic simulation (counts as ticks, not `Engine.time_scale`).
- [x] During hit-stop, inputs are still read and buffered.
- [ ] Target shakes (visual offset only) during hit-stop. Camera shake on heavy hits is already in (`CameraParams.shake_amplitude`, view only; set to 0 to disable).
- [ ] Special skills: global time-stop + cut-in style flash (`skill_freeze_ticks`, proposal ~0.3 s like post-2021 Awakening) - can be disabled in options.

**Impact**
- [ ] Per-hit VFX spawn at the hitbox/hurtbox overlap point, hit sounds per hit type, knockback vector + hitstun ticks per hit (data).
- [ ] Damage numbers and combo counter.

**Responsive input**
- [ ] **Input buffer:** a press arriving up to `buffer_ticks` (proposal 8-10) before a move's cancel window opens is executed at the first frame of that window.
- [ ] Input latency target: input sampled at the start of the tick it arrived; render shows the result in the next frame (target ≤ 2 frames end-to-end at 60 fps on an M-series Mac).
- [ ] Simulation runs at a **fixed timestep** decoupled from render frame rate (determinism + net-readiness).

**Cancels**
- [ ] Each move declares cancel windows by type: `dash`, `jump`, `command` (next node in the string), `skill`, `awakening`. Windows are frame ranges, in data.
- [ ] Commands can be canceled into skills during their `skill` window (proposal: from end of active frames to end of recovery).
- [ ] Skill-to-skill linking (Ara-style) is a **later** feature (M4+), off by default.
- [ ] Debug overlay: shows the current move, frame number, and which cancel windows are open (colored bar), so tuning is visual.
- [ ] Every value above is hot-reloadable from data files without restarting the game.

## Open questions

1. Do we want Elsword's skill time-stop + cut-in on every special skill? It is iconic but interrupts co-op flow; Elsword kept it.
2. Exact buffer and hit-stop numbers: tune with Asty in M1 playtests; record final values here.
3. Is there a "skill cancel" MP or cooldown cost? Proposal: no extra cost.

## Sources

- https://elwiki.net/w/Commands (stub sections; movement)
- https://elwiki.net/w/Skills (Special Active delay, cut-in, skill categories)
- https://elwiki.net/w/Awakening_Mode (awakening freeze 0.7 s → 0.3 s)
- https://elwiki.net/w/Eun%27s_Power (Ara's Skill Linking)
- https://elwiki.net/w/Nature%27s_Force_System (non-flinching hits)
- https://elwiki.net/w/Night_Watcher (dash cancel of X inputs)

## Images

None specific on ElWiki. Recommended: capture GIFs from our own builds for before/after comparisons of hit-stop tuning, stored in `docs/images/game-feel/`.
