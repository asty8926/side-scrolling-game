# Reference and feel checks

Asty judges feel by playing. Agents can't, so every move that moves the character is checked against a written reference and a test.

## Files

- [camera.md](camera.md): how the side camera follows the ranger, and what was measured from Elsword footage.
- [rena-combo-movement.md](rena-combo-movement.md): per-hit displacement of Rena's strings. Lists what ElWiki documents, what was estimated from footage, and what we chose.
- [hitboxes.md](hitboxes.md): ranger and dummy box sizes versus footage, and the standing-kick reach tradeoff left for Asty.
- `test/replay/test_feel_displacement.gd`: asserts each chain step's direction and rough distance, using the ranges in that table.

## Adding or retuning a move

1. **Reference first.** Add a row to the move's table: the ElWiki command text (cite the URL), the video and timestamp you measured, and the value. Tag each number [doc], [obs], [est] or [ours]. Measure in CW (character widths, 600 sub) and ticks, not pixels.
2. **Data.** Put the motion in the move's `root_motion` (sub-units per tick) and, for pass-throughs, in `pass_overshoot`, in `data/characters/*.tres`. Hot reload lets Asty try values live.
3. **Test.** Add the step to `test_feel_displacement.gd` with a range about ±30% around the reference. It should catch "doesn't move", "wrong way" and "twice as far", not a 10% tune.
4. **Replays.** If movement changed, re-bake the golden fixtures on purpose and list the hash change and its cause in the PR:
   - `godot --headless -s res://tools/make_example_replay.gd`
   - `godot --headless -s res://tools/rebake_replay.gd -- res://test/replay/fixtures/recorded_keyboard_10s.tres`
5. **Playtest.** Asty plays it. His verdict beats the table: update the table with his numbers and tag them [obs].

## Measuring footage (optional)

Download a short clip, then measure on a fixed-camera or camera-tracked training room. With yt-dlp, pick ≤720p. Cut the seconds you need with ffmpeg and read the background pan per frame. Character width and walk speed give the scale. Keep clips out of the repo (copyright); cite the URL and timestamp instead.
