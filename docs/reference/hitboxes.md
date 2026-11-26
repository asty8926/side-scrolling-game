# Hitboxes versus Elsword footage

A quick size check of the ranger and dummy boxes against Rena in training-room footage. **No sizes were changed in this pass.** Asty asked whether the hitboxes were large enough; this is the comparison and a recommendation, left for him to decide.

Footage: [Rena (Twilight) Re:Born vs Pre-Re:Born command comparisons](https://www.youtube.com/watch?v=FqgY37BAtX4), idle and the first `ZZ` kick (~2.3–3.3 s). The clip is 1280-wide, 60 fps. Clips stay on the build box under `/workspace/gamedev-ref/raw/`, not in the repo. ElWiki has no box sizes.

Offsets are the center of the box, forward from the fighter's feet. 1 CW (character width) = 600 sub = the ranger's hurtbox width. 1 m = 1000 sub.

## Character boxes

In the clip, Twilight Rena is about 45 px wide and about 90–100 px tall [est]. Walk speed in the same clip is about 234 px/s. The sim walk is 65 sub/tick at 60 ticks per second, or 3900 sub/s, which gives a rough scale of 1 px ≈ 17 sub (3900 / 234 ≈ 16.7). Comparing the 45 px width to our 600-sub hurtbox gives about 13 sub/px, so the two estimates differ. All of those are [est].

| Box | Ours | Footage [est] | Notes |
|---|---|---|---|
| Ranger hurtbox | 600 × 1400 (ratio 2.33) | ~45 × 90–100 px, about 0.6 × 1.2–1.5 m at that scale | Close enough. Height is in the same band as the sprite. |
| Ranger movement `half_width` / `height` | 300 / 1400 | — | Matches the hurtbox. |
| Dummy hurtbox | 700 × 1500 | The training mushroom looks shorter than the ranger, not taller | Flag only. The dummy is a placeholder; leave it until we replace the mushroom. |

## Attack reach

`overlaps` is an AABB around those centers, so a kick's far edge is `offset_x + width/2`, and the farthest dummy center it can graze is that edge plus the dummy's half-width (350).

| Move | `offset_x` | `width` × `height` | Far edge | Max dummy-center range | Notes |
|---|---|---|---|---|---|
| `Z` 1 | 800 | 900 × 700 | 1250 (2.08 CW) | 1600 (2.67 CW, 1.60 m) | Lengthened in #64 (was 550 / 700, max 1.25 m). |
| `Z` 2 | 650 | 800 × 700 | 1050 | 1400 (1.40 m) | Lengthened in #64 (was 550 / 700, max 1.25 m). |
| `Z` 3 | 600 | 750 × 700 | 975 | 1325 | Unchanged in #64. |
| `Z` 4 | 650 | 800 × 800 | 1050 | 1400 | Unchanged in #64. |
| `>>Z` | 450 | 800 × 500 | 850 | 1200 | Slide kick. |
| `>>ZX` | 200 | 900 × 900 | 650 | 1000 | Slash-through; the box sits around her body as she passes. |
| `>>ZZ` | 550 | 750 × 700 | 925 | 1275 | |

The first `ZZ` spark in the clip sits close to her torso, almost body-to-body, not a poke two character-widths out [est]. The second kick of the same `ZZ` also lands close to the body, not out at `Z` 2's 1.40 m max range [est]; I did not get a separate pixel reach for it. Our current `Z` 1 can still hit a dummy whose center is 1.60 m away, which is a bit long versus that picture. Body-to-body still connects (touching centers are 650 sub apart; `Z` 1's half-widths still overlap).

`Z` 1 and `Z` 2 were lengthened in #64 so the standing `WWW` follow-up still lands after a 2.5 CW `>>WX` (the dummy is pushed away as she passes). Shortening them back without also ending the pass closer would make that follow-up miss again.

Arrow projectile boxes (500 × 120, or 600 × 150 on the knockdown shot) were not the question here and were left alone.

## Recommendation

**Do not change sizes in this pass.** The ranger's own box is close to the footage. The standing first kick reaches a bit farther than Elsword's looks, but that length is what keeps `WWW` connected after the longer Night Watcher-style pass. The dummy being taller than the mushroom is a placeholder issue.

Asty's call:

1. Keep the longer standing `W` kicks, and accept that they reach a little past what the clip shows.
2. Shorten `Z` 1 / `Z` 2 toward the pre-#64 boxes (or tighter), and also end `>>WX` closer so the follow-up still lands.
3. Leave the dummy as-is, or shrink it later when the mushroom (or a real enemy) replaces the placeholder.

Until he picks, the boxes in `data/characters/ranger_moves.tres`, `ranger.tres` and `dummy.tres` stay as they are.
