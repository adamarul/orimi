# Trailer

A 45 to 60 second gameplay trailer for posting on X, made only from the real game: every shot
is the game running under Godot's Movie Maker, with Orimi driven through the real player
controller and every glyph drawn live through the brush's real input path and recognised by
it. The music is one of the game's own tracks; the sound effects are the ones the game played
in each shot. Owner: trailer (`tools/trailer/`, `scripts/trailer/`, `scenes/trailer/`,
`docs/trailer/`).

## Rebuild from nothing

```
tools/trailer/build.sh
```

It downloads ffmpeg into `.tools/ffmpeg/` if it is missing, captures every shot (one Godot window
at a time, about 25 to 30 minutes on this PC while other agents were also running), then cuts,
mixes, encodes and checks. `tools/trailer/build.sh --edit` redoes only the edit from the clips
already captured (about 5 minutes). Recapture one shot with `tools/trailer/capture.sh <shot id>`.

Output (git-ignored):

| File | What |
| - | - |
| `build/trailer/orimi_trailer_x_1080p.mp4` | The trailer: 1920x1080, 60 fps, H.264 High, yuv420p, 12 Mbps target (about 10.5 Mbps measured), AAC stereo 48 kHz, faststart |
| `build/trailer/orimi_trailer_x_1080p_music_only.mp4` | The same picture with the music only, no game sound effects |
| `build/trailer/orimi_trailer_x_720p.mp4` | Fallback: 1280x720 at about 5 Mbps, full mix |
| `build/trailer/report.txt` | ffprobe facts, loudness, silence check and the cut list with times |
| `docs/trailer/contact_sheet.jpg` | One frame per second of the 1080p file (tracked, small) |

Scratch: `.userdata/trailer/clips/<shot>.avi` and `.log` (captures), `.userdata/trailer/edit/`
(intermediates), `.userdata/trailer/review/` (review sheets).

## How it works

**Capture.** `tools/trailer/capture.sh <shot>` runs the game with
`--rendering-method gl_compatibility --fixed-fps 60 --write-movie <shot>.avi` and the boot options
`scene=res://scenes/trailer/director.tscn shot=<shot>`. The Compatibility renderer is the one the
browser build uses, and Movie Maker works with it. Movie Maker renders every frame and the
game's audio mix whatever the machine load, so the clips are smooth and in sync even though the
PC records at a fraction of real time. Movie Maker records at the window size the project gives
at start-up (`--resolution` does not change it), so while a capture runs the script writes an
untracked `override.cfg` (Godot's per-folder settings override) setting a 1920x1080 window and
MJPEG quality 0.95, and deletes it afterwards. The game's stretch base stays 1280x720, so the
interface is scaled as a player at 1080p sees it. The script retries a shot whose casts or route
failed, and kills its own Godot if it runs past a time limit.

**Director** (`scripts/trailer/director.gd`, `scenes/trailer/director.tscn`). Boots
`scenes/game/main.tscn` under itself with `autoplay=1 god=1 fresh=1` set in `Boot.options` (so the
game never captures the mouse, never pauses on lost focus and never shows the click hint) and
`_autoplay_started` set on main, so the game's own autoplay run does not start. It opens the
shot's level from the title, applies the warp and flags, runs the shot's preparation, then prints
`TRAILER_IN frame=<n>` and plays the steps, then `TRAILER_OUT frame=<n>` and quits. While a shot
rolls it shows the HUD (`hud`: on, off, or auto, which hides it in cutscenes), hides tutorial
prompts and the talk panel's "click, E or Enter" footer, and paces talk lines on the game clock.
A shot can use the gameplay camera or a placed camera with keyframes (`camera.keys`). Card shots
draw a text card on the game's paper (`UiKit` theme and `PaperPanel`, as on the title screen).
The shot list is data: `scripts/trailer/shots.json`.

**Actor** (`scripts/trailer/trailer_actor.gd`). Extends the game's `AutoplayDirector` and reuses
its route steps (`go`, `cast`, `fight`, `bloom_zone`, `talk`, `wait_flag`, ...), with two
changes. Time is the game clock, so pacing on film does not depend on how fast the PC renders.
Every glyph is drawn: the actor presses the `brush` action with `Input.parse_input_event`, puts
the left mouse button down and moves the pointer along the stroke over several frames (about
0.85 screen heights a second), lifts it and releases the brush. The brush stills the world,
paints, recognises and casts exactly as for a player. Each cast is logged as
`TRAILER_CAST {...}` with the glyph the brush recognised and whether it hit its target.

**Edit** (`tools/trailer/edit.py`, the cut list in `tools/trailer/cut.json`). Each segment is
in and out seconds from a shot's `TRAILER_IN` mark. It cuts the segments frame-accurately,
converts the full-range MJPEG to TV range, joins them, builds the music bed, mixes it with the
captured effects, normalises both mixes to -14 LUFS integrated with a -2.0 dBTP ceiling (two-pass
`loudnorm`, linear), encodes the three files and writes the report and the contact sheet.

Other tools: `tools/trailer/review.sh <shot> [step]` writes a sheet of frames every step seconds
from a shot's mark, for choosing in and out points. `tools/trailer/music_profile.py` prints a
per-second level plot of music tracks, used to choose the bed. `tools/trailer/setup_ffmpeg.sh`
fetches ffmpeg.

## ffmpeg

ffmpeg and ffprobe 9.0.2, the "essentials" static build for Windows x64 by Gyan Doshi
(`ffmpeg-9.0.2-essentials_build.zip` from https://github.com/GyanD/codexffmpeg/releases/tag/9.0.2),
checked against the SHA-256 GitHub publishes for the asset. The build is licensed GPLv3 (it
includes libx264); its LICENSE file is copied into `.tools/ffmpeg/`. It is a tool only: nothing
from it is in the repository or the game.

## Music

The bed is `audio/music/finale.ogg` (the game's own finale track) from its start. Measured with
`music_profile.py`: about 11 s quiet (-25 to -31 dBFS RMS a second), then a sharp rise at
12.55 s (from -24 to -11 dBFS within 0.1 s) to a sustained -15 to -17 dBFS until a natural end at
about 57 s. The cut puts the colour returning to the great camphor on that rise. The other
candidates were `title.ogg` (rise at 29 s, too late), `vale_restored.ogg` and
`tallowford_restored.ogg` (level all through), `vale_cursed.ogg` (no rise). Tracks of the
unfinished levels were not considered.

## Shot list

See `build/trailer/report.txt` for the times of the latest build. In order:

| Time (s) | Length | Shot | What happens |
| - | - | - | - |
| 0.0 | 2.6 | vale_open | Placed camera, slow push: the grey vale, Orimi small on the shrine path. No HUD. |
| 2.6 | 2.4 | card_lost | Card: "The vale has lost its colour." |
| 5.0 | 4.3 | run_slash | Orimi runs (gameplay camera, HUD); the brush stills the world to paper at 6.5 s, a Slash is drawn across the thorn gate and the thorns are cut. |
| 9.3 | 1.4 | card_draw | Card: "Draw it back." |
| 10.7 | 7.0 | tree_finale | A Bloom circle is drawn round the Thousand-Ring Camphor; colour floods out from it on the music's rise (12.55 s); the game's own finale camera swings round the tree. |
| 17.7 | 3.0 | tree_finale | The finale crane ends over the green valley (framed lower in the edit). |
| 20.7 | 2.2 | zone_a | A finishing Slash through an unravelling Splotchet. |
| 22.9 | 2.2 | zone_b | A Gust strips a Reedwraith's veil. |
| 25.1 | 3.3 | zone_a | Bloom on the Reed Shallows sapling; the zone turns green. |
| 28.4 | 6.0 | tf_trim | Dusk Tallowford; a Kindle dab lights Old Trim's lamp, the warm pool spreads, he wakes: "Hm? Who let my lamp go out?" |
| 34.4 | 2.5 | tf_sealed | Orimi steps onto the jetty square and the torn-paper screens rise round it; a Slash. |
| 36.9 | 1.0 | tf_sealed | A Splotchet lunges and is struck. |
| 37.9 | 2.6 | tf_sealed | The Reedwraith unravels into threads, the screens fall, petals. |
| 40.5 | 2.4 | tf_finale | Tallowford lit, the ford-lamp over the river (the level's own finale camera). |
| 42.9 | 5.0 | title | "Orimi: The Unfaded Vale" / "A living-ink adventure you play in your browser." / "In development". |

Captured but not in the cut: `gust_soot` was dropped from the list (the soot bank sits at the top
edge of the frame); the Tallowford finale's own Gust and Kindle strokes (the camera looks at
blank ground while they are drawn); Hazewater's raft departure (after the merge of main c4f8ff8 the
raft departure camera sits inside the terrain for about six seconds, with Pell's line over it).

## Level 1 playthrough

`tools/trailer/playthrough.sh` films Hazewater Vale as one unbroken take and encodes it:
`build/trailer/orimi_level1_playthrough_1080p.mp4` (H.264 High, yuv420p, about 8 Mbps, AAC 48 kHz
stereo, faststart), `build/trailer/orimi_level1_playthrough_720p.mp4` (about 4 Mbps),
`build/trailer/level1_playthrough_report.txt` (ffprobe facts, loudness, and every route stage and
cast with its time in the video) and `docs/trailer/level1_playthrough_sheet.jpg` (one frame every
five seconds). `tools/trailer/playthrough.sh hazewater --encode` re-encodes the last take without
capturing again.

The capture is `tools/trailer/capture.sh` with the boot option `playthrough=hazewater` instead of a
shot, at MJPEG quality 0.8 so the AVI stays well under its 4 GB limit (about 2 GB for the take).
The director boots the real game at its title screen with `fresh=1` and the game's own music and
sound. `PlaythroughActor` (`scripts/trailer/playthrough_actor.gd`) runs the game's autoplay
(`AutoplayDirector._run`) through the gameplay camera, with the HUD, hint panels and talk panels as a
player sees them, every glyph drawn live and the game clock for time. It differs from the QA run in
three ways:
- It skips the route's `death_test` step, a check that kills Orimi on the spot.
- It holds the title screen and the level's opening card for 3 s each.
- The director paces talk lines for reading (2.4 s, or 0.045 s a character for longer lines). Time
  with a talk panel open does not count against the route's waits.

The only edit is trimming the head and tail: the video runs from the frame the title is ready to the
end of the level. The game's sound is turned down only as far as keeping the true peak under -1
dBTP after AAC; it is not loudness-normalised. In the book, Hazewater Vale has no end card. After
the bead, Pell's raft leaves, the screen fades to paper and Tallowford opens at once, so the take
ends on that fade. When the level filmed is the book's last, it ends 3 s into the end card.

## Known limits

- In the Level 1 playthrough the cut to the raft (about 113.5 s) swoops from the valley view to
  the bank in about 0.4 s, after the screen has already faded to paper and back. On one or two
  frames of that swoop a grassy slope fills most of the frame. Gameplay owns that camera
  (`RaftTrip._frame` in scripts/game/kit/raft_trip.gd).
- Weak frames: the valley crane (17.7 s) still has a pale haze in its top-left corner and grey
  cliffs on the right, though the green valley fills most of it; in the sealed fight the screens rise
  in about a quarter of a second and the Reedwraith unravels small, at the back of the square.
- Tie is not in the trailer: neither Hazewater Vale nor Tallowford has tie posts (Tie first
  appears in Sedge Plain, which may not be shown).
- Nobody has listened to the mix. Loudness, true peak, silence and clipping are measured, not
  heard. The music-only file is there in case the effects sound wrong.
- The brush's stroke width depends on drawing speed measured on the wall clock; under Movie
  Maker the PC renders slower than real time, so strokes are drawn at a slower apparent speed and
  come out a little heavier than a quick player's.
- Real mouse movement over the capture window while a stroke is being drawn would add to the
  stroke; a capture that loses a cast is retried. Godot windows appear on the desktop during
  capture.
