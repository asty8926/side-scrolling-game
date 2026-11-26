# Side camera

How the 2.5D camera should follow the ranger, checked against Elsword footage.

This is **view only**. Nothing here is in the sim or a snapshot. Tunables live in `data/view/side_camera.tres` (`CameraParams`) and hot-reload in a debug run.

## What Elsword does

| Behaviour | Finding | Tag |
|---|---|---|
| Horizontal position | The player stays at the screen center (x ≈ 639.5 in a 1280-wide 60 fps clip). | [est] |
| Lead / lag / dead zone | During a `>>ZX` dash (Twilight comparison, 0:44–0:56) the player's screen-x moves at most about ±10 px (~0.2 CW, ~0.13 m), standard deviation ~1 px. No useful dead zone or look-ahead. | [est] |
| Room walls | The camera does not stop at a room's collision edges; the player stays centered and the scene shows something past the wall (continued floor/wall, or a door with a hint of the next room). | [obs] (Asty) and [doc] for the design intent; [est] that our previous wall clamp was unlike this. |
| Vertical | Not cleanly measured (few isolated jumps in the clip). Default is the same lock-to-center as horizontal; smoothing is tunable if a little lag is wanted. | [ours] |

Footage: [Rena (Twilight) Re:Born vs Pre-Re:Born command comparisons](https://www.youtube.com/watch?v=FqgY37BAtX4). Clips are kept on the build box under `/workspace/gamedev-ref/raw/`, not in the repo.

## Ours

| Param | Value | Tag |
|---|---|---|
| `dead_zone_half_width` | 0 m | [est] |
| `horizontal_smoothing`, `vertical_smoothing` | 0 (locked) | [est] / [ours] for vertical |
| `beyond_edge` | 16 m | [ours]; covers more than a visible half-width (~7–8 m at the default framing) |
| Door hints | on | [ours] |

The test room draws a slightly darker floor and back wall past each collision edge, and a door frame on the line itself, so a centered camera never shows the void. Collision is unchanged: the ranger still stops at the room's `left` / `right`.
