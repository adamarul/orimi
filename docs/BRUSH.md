# Brush

The ink brush: hold a key, the world freezes and turns into a sepia underpainting on scroll
paper, paint one stroke, release, and the stroke is recognised as a glyph and cast into the
world. Owner: brush workstream (`ws/brush`). Contract: docs/CONTRACTS.md, "Brush".

## Files

| Path | What |
| - | - |
| scenes/brush/brush_layer.tscn, scripts/brush/brush_layer.gd | The `Brush` autoload: open/close, input, ink, recognition hand-off, casting |
| scripts/brush/brush_stroke.gd (`BrushStroke`) | Input cleaning, centripetal Catmull-Rom smoothing, resampling, width/taper rules, stroke triangles |
| scripts/brush/brush_stroke_view.gd (`BrushStrokeView`) | The live stroke: incremental smoothing and a geometry cache so long strokes stay cheap |
| scripts/brush/brush_glyphs.gd (`BrushGlyphs`) | Glyph shapes, the $1 recogniser, geometric gates, the dab and tie checks |
| scripts/brush/brush_tie_hints.gd (`BrushTieHints`) | Ink rings round the tie posts while the brush is open |
| scripts/brush/brush_ink_canvas.gd (`BrushInkCanvas`) | Draws finished strokes (ink pot, glyph card) |
| shaders/brush/brush_view.gdshader | Sepia underpainting on paper, vignette, ragged fade |
| shaders/brush/ink_stroke.gdshader | Black ink, wet edge, dry bristle streaks, failure break-up |
| scenes/brush/ink_pot.tscn, scripts/brush/ink_pot.gd | The ink-pot meter Control for the HUD |
| scenes/brush/glyph_card.tscn, scripts/brush/glyph_card.gd | A torn-paper card showing one glyph (`glyph`: bloom, slash, gust, kindle, tie) |
| scenes/dev/brush_demo.tscn, scripts/brush/brush_demo.gd, scripts/brush/demo_target.gd | Demo (sapling, thorns, soot, a lamp and two tie posts), scripted draws and the headless self test |
| scenes/dev/brush_recognition_test.tscn, scripts/brush/recognition_test.gd | Confusion-table test |
| tools/brush/test_recognition.sh, tools/brush/selftest.sh, tools/brush/web_brush.sh (.cjs) | Test runners and the browser proof |

## How it works

**Opening.** `_unhandled_input` sees the `brush` action pressed (Left Shift, Q, right mouse). It refuses
when `enabled` is false or the tree is already paused. Otherwise it pauses the tree, remembers the
mouse mode and `Input.use_accumulated_input`, turns accumulation off (every motion event is
kept, so a 30 fps frame still gets every pointer sample), shows the mouse with a brush-tip
cursor, and emits `Events.brush_opened`.

**Closing.** Polled every frame rather than trusted to a single release event: as soon as
`Input.is_action_pressed(&"brush")` is false the brush closes and casts, whatever order the keys
and buttons came up in (holding Shift and right mouse together keeps it open until both are up).
It also closes, without casting, on Escape/P (`pause`, consumed so the pause menu does not also
open), on application focus loss, if `enabled` turns false, or if something else unpauses the tree.
Closing restores the cursor, the mouse mode and input accumulation at once (pointer lock has to
be requested while the browser still counts the last click as a user gesture), casts, fades the
paper out over 0.3 s with the world still frozen, then unpauses and emits
`Events.brush_closed`. `is_open()` is true from opening until the unpause. Quitting with the brush
open does not leak: the cursor is an Image, cleared on exit.

**Pointer lock.** In the browser, leaving pointer lock is asynchronous: `Input.mouse_mode` keeps
reading captured until Chrome has released it. A stroke cannot start until then, because
pointer positions are not real while the lock is held. Measured in Chrome 157 (headless): lock
is gone 250 ms after the key goes down, and is taken back when the brush closes (see "Browser
proof").

**Strokes.** One stroke per cast: a new press of the brush button while the brush is open
starts a fresh stroke (the previous one's ink stays spent). Raw points closer than 0.3 %H are
dropped, the rest go through a centripetal Catmull-Rom spline sampled every 0.4 %H. Width comes
from speed: measured over the last 80 ms of frames (event timestamps and Godot's pointer
velocity both bunch up or lag in the browser), mapped from fat and wet when slow to thin and dry
when fast, then eased along the stroke over 5 %H so the line swells rather than steps. Pen
pressure, when the pointer reports any, scales width by 0.3 to 1.3 and adds dryness when light.
Both ends taper (the lift-off taper is longer for fast strokes); the live tip has a short taper
while the brush is down. The ink shader adds a slightly darker wet edge, and dry bristle
streaks sized in pixels that eat the edges first, then the middle.

**Ink.** 100 units. Painting costs 20 units per viewport height of stroke length (measured: a bloom
around a target 9 to 16, a slash 5 to 9, a gust 7 to 12). A Kindle costs a flat 3 on top (a dab has
almost no length, and lighting should not be free); a Tie costs 4 on top of its length (the rope),
so a post-to-post line across a third of the screen costs about 11, between a slash and a bloom.
The extra is taken when the glyph is recognised; if the pot cannot cover it the cast fails with
`no_ink` and the stroke's own ink stays spent. When the pot runs
dry mid-stroke the stroke stops there. Refills 2.5 per second while the tree is unpaused, and
15 on `Events.enemy_died`. `Events.ink_changed` is emitted on every change of half a unit or more,
always on `add_ink` and at empty and full.

**Recognition.** `BrushGlyphs.recognise(points, height, duration, posts)` takes the smoothed stroke, how
long the tip was down, and the tie posts on screen. A dab (see "Kindle and Tie") is decided first.
Then, shorter than 6 %H: rejected as `too_short`. With posts on screen, the Tie check runs next. Otherwise it computes geometric features on 96 evenly spaced points and runs each
glyph's gate, then a $1 template match (implemented from the Wobbrock, Wilson and Li 2007 paper:
resample to 64 points, rotate so the centroid-to-first-point angle is zero, scale, centre, and
golden-section search over plus or minus 45 degrees for the best mean point distance). One
deliberate change: scaling is uniform (larger side to 250) instead of to a square, so a line stays
a line. A stroke is a glyph only if that glyph's gate passes and its best template score reaches
the minimum; everything else is `unrecognised`. Templates are generated in code: circles both ways,
slightly oval and slightly overshot; a straight and two bowed lines; cycloid loops at two loop
sizes, mirrored and reversed.

| Gate | Rules |
| - | - |
| Bloom | Larger side at least 7 %H; every self-crossing is a closing overlap (the bits outside it are at most 20 % of the length together); with no crossing, the end is within 17 % of the length of the start; total turning 285 to 470 degrees; radius spread (std/mean about the centroid) at most 0.24; no corner (at most 75 degrees of turning inside any twelfth of the stroke); $1 score at least 0.80 |
| Slash | Length at least 12 %H; no self-crossing; chord/length at least 0.86; within 30 degrees of horizontal, either direction (this is what stops the $1 rotation step from accepting a vertical line); $1 score at least 0.80 |
| Kindle | Larger side of the bounding box at most 2.5 %H; path length at most 3 %H after re-cleaning the stroke at 1 %H spacing (so a pen trembling in place adds nothing, a small loop still does); press at most 0.8 s (longer is rejected with detail "closest kindle: held X s"). No template |
| Tie | Only when tie posts are on screen. Length at least 6 %H; no self-crossing; no point further from the chord than 10 % of the chord; the start within a post's projected radius plus 40 px and the end within a different post's; $1 line score at least 0.75 at any angle. When any of this fails the stroke goes on to the three shape glyphs exactly as without posts |
| Gust | Larger side at least 8 %H; exactly one self-crossing (crossings closing knots shorter than 5 % of the length are ignored, and crossings within 4 % of each other merged); each tail outside the loop at least 5 % and both at least 20 % of the length; the loop at least 22 %; turning inside the loop at least 200 degrees and overall at least 150 (rejects figure eights); $1 score at least 0.72, scored with each tail cut to at most the loop's own length (`GUST_MAX_TAIL`, see "Long tails") |

`Brush.last_result` holds the full result of the last stroke (glyph, score, reason, which gate
failed, every $1 score, the features and input statistics including `input.duration`), for
readouts and QA.

### Kindle and Tie

**Kindle (`&"kindle"`)** is a dab: a short press with almost no travel. The thresholds come from
measuring dabs and the strokes they must not be confused with, in the recognition test's input
model (mouse: 1 to 4 events within 3 px, 0.05 to 0.25 s; pen: the tip slips up to 1.2 %H while it
lands, 120 to 240 Hz with 0.7 px jitter, 0.05 to 0.5 s):

| class | bounding box %H (min / median / max) | path length %H | press time s |
| - | - | - | - |
| kindle, mouse | 0.00 / 0.32 / 0.77 | 0.00 / 0.30 / 0.56 | 0.05 / 0.14 / 0.25 |
| kindle, pen | 0.01 / 0.71 / 1.35 | 0.02 / 0.66 / 1.40 | 0.05 / 0.24 / 0.50 |
| start of a slash | 4.36 / 6.68 / 9.93 | 4.50 / 6.79 / 10.10 | 0.12 / 0.12 / 0.22 |
| tiny bloom loop | 1.22 / 2.60 / 3.99 | 0.17 / 8.04 / 12.26 | 0.12 / 0.12 / 0.30 |
| long press | 0.00 / 0.65 / 1.30 | 0.00 / 0.59 / 1.19 | 1.00 / 1.66 / 1.98 |

Box 2.5 %H and length 3 %H sit about twice the largest pen dab and well under the shortest slash
start; a tiny loop has a dab-sized box but several times a dab's length, so length separates it.
Between 3 and 6 %H of length nothing is cast at all (`too_short`), a dead band on both sides.
In the browser run the scripted dabs measured 0.16 to 0.17 s down. 0.8 s is three times the
longest mouse tap and well under a deliberate hold. The one test miss is a loop drawn in 0.12 s
at 30 Hz that arrived as four events in a 2 %H box; at that size and rate it is a dab.
Hit test: the dab's centre, with the same ray as the other glyphs (one ray, under the centre),
and the same 40 px tolerance: a candidate is hit when its projected anchor is within its
projected `glyph_radius()` plus `Brush.KINDLE_MARGIN` (40 px) of the dab. Targets answer through
`on_glyph(&"kindle", info)`. On screen a dab is drawn as a short slanted teardrop of wet ink.

**Tie (`&"tie"`)** joins two tie posts: nodes in the `tie_post` group (`Brush.GROUP_TIE_POST`),
projected the same way as brush targets (`glyph_anchor()` / `glyph_radius()`, in front of the
camera, within 60 m). When the stroke is a Tie, both posts are called with `on_glyph(&"tie", info)`
in stroke order (the post the stroke started on first) and `info.targets` is `[start post, end
post]` whatever they answer; `info.tie_anchors` holds their two world anchors in the same order.
Tie posts are not brush targets, so other glyphs do not touch them. A stroke that is not a Tie is
judged exactly as if there were no posts: a near-horizontal line between two posts that bows too
much is still a Slash, and so is one that starts on a post and ends elsewhere.
Straightness uses the furthest point from the chord (10 % of the chord at most) rather than
chord/length, because chord/length falls with sensor jitter on slow strokes at high input rates;
the test's bowed lines (18 to 25 % of the span) are all refused.

**Feedback while drawing.** While the brush is open every tie post on screen gets a faint, dry,
thin ink ring (`BrushTieHints`, the ink stroke shader, slightly open like a brush circle). When a
stroke starts on a post its ring goes dark, wet and thick; when the stroke's end comes within
reach of a second post that ring goes dark too, so both dark rings mean the Tie will land.


**Casting.** Exactly as CONTRACTS.md specifies. The glyph info dictionary has every key in the
table. `screen_points` is the smoothed stroke; `screen_center` and `screen_radius` are the mean and mean
distance of 64 evenly spaced points. 40 rays along the stroke, plus rays under the centroid and
the two ends, use `Layers.BRUSH_RAY_MASK` and also hit areas on those layers; a ray that hits nothing
lands 12 m along. `world_radius` is the mean ground-plane distance from `world_center` to the ray hits
(or the screen radius scaled by distance when nothing was hit). `world_dir` is start to end on the
ground plane (camera forward if the two coincide). Candidates are nodes in `brush_target` and
`enemy`, de-duplicated, not behind the camera, within 60 m; anchor and radius from
`glyph_anchor()`/`glyph_radius()` or the defaults. Bloom: anchor inside the stroke polygon.
Slash: projected disc within reach of the stroke (radius plus half the slow stroke width).
Gust: anchor inside the stroke bounds grown by 40 px. Kindle: anchor within the projected radius
plus 40 px of the dab's centre. Tie: see "Kindle and Tie". Hits are told nearest first; nodes that
return true are in `targets`. Then `Events.glyph_cast`. A failure emits `Events.glyph_failed` with
`reason`, `screen_points`, and also `detail`, `score` and `ink_cost`.

**inject_stroke(points).** The same ink rules (it is cut short where the ink runs out; empty ink
gives `no_ink`), the same smoothing, recognition and casting code as a drawn stroke. It does not
pause or open the brush; it shows the stroke on screen for 0.7 s. Autoplay should call
`Brush.refill()` before a scripted cast if it does not want to depend on the ink level.

**Ray queries while paused.** Measured in the self test (physics engine setting `DEFAULT`):
rays hit bodies normally while the tree is paused. A body moved or added while paused is not
seen in the same frame (transforms reach the physics server at the end of the frame), but is
seen on the next frame without any physics step. The brush always casts at least a frame after
pausing, so this only matters to something that moves a body and casts in the same frame.

## The brush view

A canvas pass on layer 30 after a BackBufferCopy, so it sees the 3D frame, the post chain and
the HUD. The canvas screen texture and canvas output are sRGB in both renderers, so no renderer
gating; desktop and web screenshots match by eye. The frame is softly blurred, its luminance
pulled toward the middle (contrast 0.8) and mapped onto a three-stop ramp from brown-black ink
through sepia to paper, then mixed toward bare paper (scene strength 0.62). Paper tooth is a
relief built from the slope of a noise height field lit from the upper left, plus large soft
stains and a darker warm vignette. The paper bleeds in from the corners with a ragged front as
it fades. Shaders and the paper are drawn once, fully transparent, at start-up so the first
opening does not stall on shader compilation. The brush layer also shows its own ink pot (top
left) while open, since the HUD below is covered.

Every uniform of the two brush shaders is listed in the next two sections.

## `brush_view.gdshader` (the brush layer's View, canvas, after a BackBufferCopy)

`shaders/brush/brush_view.gdshader`, on the `View` ColorRect in `scenes/brush/brush_layer.tscn`.
Colours are plain `vec3` sRGB values (canvas shaders see sRGB in both renderers).

| Uniform | Type | Range | Default | Meaning | Set by |
| - | - | - | - | - | - |
| `screen_tex` | `sampler2D` | hint_screen_texture | | The frozen frame (3D, post chain and HUD) the underpainting is made from; sampled with a soft 9-tap blur. | engine |
| `fade` | `float` | 0..1 | 0 | 0 closed, 1 fully open; the paper bleeds in from the corners with a ragged front. | `brush_layer.gd` every frame while opening and closing (0.18 s in, 0.3 s out) |
| `scene_strength` | `float` | 0..1 | 0.62 | How much of the scene shows through: 0 bare paper, 1 the full ink-to-paper tonal range. | default |
| `contrast` | `float` | 0.2..1.5 | 0.8 | Contrast of the scene's luminance around mid grey before it is mapped to sepia (1 unchanged). | default |
| `paper_colour` | `vec3` | sRGB | (0.925, 0.878, 0.776) | Brightest stop of the tone ramp and the colour of bare paper. | default |
| `sepia_colour` | `vec3` | sRGB | (0.596, 0.463, 0.322) | Middle stop of the tone ramp (mid-grey luminance maps here). | default |
| `ink_colour` | `vec3` | sRGB | (0.180, 0.125, 0.082) | Darkest stop of the tone ramp, a brown-black. | default |
| `vignette` | `float` | 0..1 | 0.5 | Warm darkening toward the edges. | default |
| `tooth` | `float` | 0..0.2 | 0.07 | Strength of the paper tooth relief (noise height field lit from the upper left). | default |
| `tooth_cell` | `float` | px at 720p, about 2..8 | 3.5 | Size of one tooth cell; scales with the viewport height. | default |

## `ink_stroke.gdshader` (every brush stroke: live stroke, glyph cards, ink pot, tie rings)

`shaders/brush/ink_stroke.gdshader`, on `BrushStrokeView` (the live and injected stroke) and every
`BrushInkCanvas` (glyph cards, the ink pot, the tie-post rings). Per vertex it reads `UV.x` (arc
length in px), `UV.y` (-1..1 across the stroke), `COLOR.r` (dryness 0..1), `COLOR.g` (stroke
width in px / 64) and `COLOR.a` (opacity of that vertex; the tie rings use 0.45 when idle).

| Uniform | Type | Range | Default | Meaning | Set by |
| - | - | - | - | - | - |
| `ink_colour` | `vec3` | sRGB | (0.106, 0.102, 0.110) | The ink, near black (`Palette.INK`). | default |
| `opacity` | `float` | 0..1 | 1 | Whole-stroke opacity, for fading a cast stroke out with the paper and the 0.7 s afterimage of an injected stroke. | `brush_stroke_view.gd` `set_opacity` |
| `decay` | `float` | 0..1 | 0 | 0 intact, 1 gone: a failed stroke breaks up along its bristle streaks while the paper fades. | `brush_stroke_view.gd` `set_decay` |
| `dry_bias` | `float` | 0..1 | 0 | Dryness added on top of the per-vertex value, for texture on small static strokes. | `glyph_card.gd` (0.3) through `BrushInkCanvas.set_param` |
| `streak_length` | `float` | px, about 20..200 | 70 | Length of a dry streak along the stroke. | default |
| `bristle_spacing` | `float` | px, about 1..8 | 2.6 | Spacing of the bristle streaks across the stroke, in pixels whatever the width. | default |

## Tuning constants

| Constant | Default | Meaning |
| - | - | - |
| Brush.OPEN_TIME / CLOSE_TIME | 0.18 s / 0.3 s | Paper fade in / out |
| Brush.INK_PER_HEIGHT | 20 | Ink per viewport height of stroke |
| Brush.INK_REFILL_PER_SECOND | 2.5 | Refill while the world runs |
| Brush.INK_PER_ENEMY | 15 | Refill per `enemy_died` |
| Brush.SPEED_WINDOW / SPEED_SMOOTHING | 0.08 s / 0.5 | Speed measurement |
| Brush.WIDTH_EASE | 5 %H | Width easing along the stroke |
| Brush.CAST_RANGE | 60 m | Candidate distance |
| Brush.RAY_COUNT / RAY_LENGTH / MISS_DISTANCE | 40 / 250 m / 12 m | Rays |
| Brush.GUST_MARGIN | 40 px | Gust bounds growth |
| Brush.KINDLE_MARGIN | 40 px | Kindle reach beyond a candidate's projected radius |
| Brush.KINDLE_INK / TIE_INK | 3 / 4 | Extra ink for a Kindle / a Tie |
| BrushGlyphs.DAB_MAX_SIZE / DAB_MAX_LENGTH / DAB_SPACING / DAB_MAX_TIME | 2.5 %H / 3 %H / 1 %H / 0.8 s | Kindle |
| BrushGlyphs.TIE_MARGIN / TIE_MIN_LENGTH / TIE_MAX_BOW / TIE_MIN_SCORE | 40 px / 6 %H / 0.1 / 0.75 | Tie |
| BrushGlyphs.GUST_MAX_TAIL | 1.0 | Gust tails kept for the template score, in loop lengths |
| Brush.AFTERIMAGE_TIME / INJECT_SPEED | 0.7 s / 1.2 H/s | Injected stroke display |
| BrushStroke.WIDTH_SLOW / WIDTH_FAST | 2.6 %H / 0.75 %H | Width at slow and fast speed |
| BrushStroke.SPEED_SLOW / SPEED_FAST | 0.6 / 2.6 H per s | Speeds for those widths |
| BrushStroke.DRY_FROM / DRY_TO | 1.1 / 3.0 H per s | Wet to dry |
| BrushStroke.PRESSURE_MIN / MAX | 0.3 / 1.3 | Pen pressure width factor |
| BrushStroke.TAPER_START / TAPER_END_SLOW / TAPER_END_FAST / TAPER_LIVE | 3 / 4 / 10 / 1.2 %H | Tapers |
| BrushStroke.MIN_RAW_SPACING / SAMPLE_SPACING | 0.3 / 0.4 %H | Input cleaning and smoothing |
| BrushGlyphs gate constants | see the gate table | Recognition |

## What a pen does and does not do

A pen (Windows Ink on desktop, Pointer Events with pointerType pen in the browser) arrives as a
mouse with pressure: the tip is the left button, so it paints with `brush_draw`. Pressure scales
width (0.3x to 1.3x of the speed width) and light pressure adds dryness. Tilt is ignored
(the browser does not pass it to Godot; RENDERER_NOTES). The eraser end is not used. Without
pressure (every mouse) width comes from speed alone. Verified only with synthetic Chrome pen
events (CDP, force 0.25 to 0.95: pressure 0.25 to 0.95 arrived and widths ranged 3 to 23 px).
No real pen was tested on either platform.

## Recognition test

`tools/brush/test_recognition.sh` (headless, deterministic seed, about 3 s) generates noisy
variants and runs them through the same pipeline as live input: hand wobble (1 to 5 % of the size
as a low-frequency sideways drift), sensor jitter (0.7 px), sizes from 9 to 30 %H half-extent, and
sampling as input events arrive at 30, 60 and 144 Hz along an ease-in/ease-out speed profile at
0.5, 1.5 and 3 viewport heights per second. Glyph variants: circles from 0.9 to 1.12 turns (a gap
or an overshoot), aspect 0.75 to 1.25, any start, both directions; lines within 20 degrees of
horizontal, bowed up to 10 %, both directions; loops with loop size d/r 1.6 to 3, tails trimmed
up to 15 % at each end, any rotation, mirrored and reversed. Kindle variants: mouse and pen dabs as in the
table above. Tie variants: lines between two posts (radius 8 to 30 px) 10 to 60 %H long at any
angle, bowed up to 3 %, with 0.5 to 3 px of hand wobble, ends anywhere within the post's radius
plus 28 px. Every other stroke also has two tie posts at random places on screen; they draw from a
separate random generator so the bloom, slash and gust strokes are the same ones as before Kindle
and Tie existed. Negatives added for the two glyphs: `long_press` (a dab held 1 to 2 s),
`slash_start` (a slash 4 to 10 %H long), `tiny_loop` (a circle 1.2 to 4 %H across), and three
near-Ties that must be judged as if there were no posts (`tie_one_end`: a steep line from a post
to nowhere; `tie_curved`: an arc between two posts; `tie_overshoot`: a line over the second post
and well past it). For those three, "correct" means the same answer as with no posts, which is
why 5 `tie_curved` arcs count as correct Slashes. `gust_long_tails` (last, so every row above it
keeps its strokes) is the gust generator with tails 1.5 to 2 arches long instead of 1.3, where
the tails start to curl into the next loop. Output in docs/brush/recognition.txt:

BRUSH_TEST confusion table (rows: what was drawn; columns: what the recogniser said)

| drawn | n | bloom | slash | gust | kindle | tie | rejected | correct |
| - | - | - | - | - | - | - | - | - |
| bloom | 300 | 299 | 0 | 0 | 0 | 0 | 1 | 99.7% |
| slash | 300 | 0 | 300 | 0 | 0 | 0 | 0 | 100.0% |
| gust | 300 | 0 | 0 | 286 | 0 | 0 | 14 | 95.3% |
| kindle | 300 | 0 | 0 | 0 | 300 | 0 | 0 | 100.0% |
| tie | 300 | 0 | 0 | 0 | 0 | 299 | 1 | 99.7% |
| scribble | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| zigzag | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| open_arc | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| vertical | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| diagonal | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| spiral | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| figure8 | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| double_loop | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| square | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| triangle | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| check | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| wave | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| long_press | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| slash_start | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| tiny_loop | 40 | 0 | 0 | 0 | 1 | 0 | 39 | 97.5% |
| tie_one_end | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| tie_curved | 40 | 0 | 5 | 0 | 0 | 0 | 35 | 100.0% |
| tie_overshoot | 40 | 0 | 0 | 0 | 0 | 0 | 40 | 100.0% |
| gust_long_tails | 40 | 0 | 1 | 31 | 0 | 0 | 8 | 77.5% |

BRUSH_TEST overall 2234 / 2260 correct (98.8%), 2260 strokes in 5359 ms (2.37 ms per stroke)

Accuracy of the drawn glyphs (bloom, slash, gust, tie) by drawing speed and input rate:

| speed | rate | bloom | slash | gust | tie |
| - | - | - | - | - | - |
| fast | 030 Hz | 34 / 34 | 34 / 34 | 22 / 34 | 34 / 34 |
| fast | 060 Hz | 33 / 33 | 33 / 33 | 32 / 33 | 33 / 33 |
| fast | 144 Hz | 33 / 33 | 33 / 33 | 33 / 33 | 33 / 33 |
| medium | 030 Hz | 34 / 34 | 34 / 34 | 33 / 34 | 34 / 34 |
| medium | 060 Hz | 33 / 33 | 33 / 33 | 33 / 33 | 33 / 33 |
| medium | 144 Hz | 33 / 33 | 33 / 33 | 33 / 33 | 33 / 33 |
| slow | 030 Hz | 34 / 34 | 34 / 34 | 34 / 34 | 34 / 34 |
| slow | 060 Hz | 33 / 33 | 33 / 33 | 33 / 33 | 33 / 33 |
| slow | 144 Hz | 32 / 33 | 33 / 33 | 33 / 33 | 32 / 33 |

Dab measurements (%H for size and length, seconds for time): min / median / max. A dab must be within
size 2.5 %H, length 3.0 %H (re-cleaned at 1.0 %H) and 0.8 s.

| class | n | bounding box | path length | press time |
| - | - | - | - | - |
| kindle (mouse) | 95 | 0.00 / 0.32 / 0.77 | 0.00 / 0.30 / 0.56 | 0.05 / 0.14 / 0.25 |
| kindle (pen) | 205 | 0.01 / 0.71 / 1.35 | 0.02 / 0.66 / 1.40 | 0.05 / 0.24 / 0.50 |
| long_press (mouse) | 14 | 0.00 / 0.13 / 0.67 | 0.00 / 0.13 / 0.56 | 1.00 / 1.66 / 1.98 |
| long_press (pen) | 26 | 0.19 / 0.65 / 1.30 | 0.06 / 0.59 / 1.19 | 1.06 / 1.66 / 1.96 |
| slash_start | 40 | 4.36 / 6.68 / 9.93 | 4.50 / 6.79 / 10.10 | 0.12 / 0.12 / 0.22 |
| tiny_loop | 40 | 1.22 / 2.60 / 3.99 | 0.17 / 8.04 / 12.26 | 0.12 / 0.12 / 0.30 |

Most common reasons for wrong answers:
- bloom: unrecognised closest bloom: has a corner x1
- gust: unrecognised closest gust: 0 crossings x5, unrecognised closest slash: too steep x4, unrecognised closest slash: not straight x2, unrecognised closest gust: loop turns 156 deg x1
- tie: unrecognised closest slash: too short x1
- tiny_loop: accepted as kindle x1
- gust_long_tails: unrecognised closest gust: loop too small x5, unrecognised closest slash: not straight x2, accepted as slash x1, unrecognised closest slash: too steep x1

Compared with the table before Kindle and Tie, bloom (299), slash (300) and gust (286) are
unchanged on the same strokes. The negative rows now come after the Kindle and Tie rows, so they
are different random strokes than before and not directly comparable (before: one scribble read
as gust, one wave as slash; now none). The remaining gust misses are loops drawn fast or at a
low input rate (12 fast at 30 Hz, one fast at 60 Hz, one medium at 30 Hz): every one arrived as
4 to 8 input events (most as 4 or 5, a whole gust in 0.12 to 0.16 s), and the loop is simply not
in the data. The fast 30 Hz gust
cell is 22 / 34. Treating a close approach as a crossing was tried (reach 5 to 30 % of the
stroke's size) and recovered none of them; at 30 % it broke slashes, so it was removed. The
brush turns input accumulation off while open, so the browser's own event rate (60 Hz or more
for a mouse) applies, not the frame rate; 30 Hz is the worst case.

### Long tails (QA F-011)

A one-loop cycloid with tails 1.75 arches long passed the Gust gate but scored 0.720 against the
templates (QA saw 0.717; the threshold is 0.72), because every template has tails one arch long.
Three fixes were measured on the test set with the `gust_long_tails` row added:

| Change | gust (300) | gust_long_tails (40) | false gusts in the negatives |
| - | - | - | - |
| none | 286 | 30 | 0 |
| tails cut to 1 loop length before the template score only (chosen) | 286 | 31 | 0 |
| templates with 1.6-arch tails added | 286 | 31 | 0 |
| tails cut before the gate as well, 1.0 / 0.8 / 0.6 loop lengths | 286 / 282 / 279 | 36 / 36 / 35 | 2 / 3 / 6 (scribble, zigzag) |
| longer-tail templates and the loop gate lowered to 15 % | 287 | 36 | 1 (scribble) |

Cutting the tails before the score is chosen: it fixes the reported shape with the same result as
extra templates, works for any tail length, and changes no other row (every row above
`gust_long_tails` is identical to the table before). QA's shape (loop d/r 2.2, tails 1.75 arches)
now scores 0.824. Cutting before the gate too, or loosening the loop gate, recovers more long-tail
loops but lets scribbles and zigzags through as Gust, so the gate is unchanged. Still refused: a
small loop (d/r 1.6) with tails 1.75 arches or more fails the gate as "loop too small" (the loop is
under 22 % of the stroke), and a large loop with tails a full two arches (half a second loop on
each side) scores 0.67. Of the 9 long-tail misses, 4 arrived as 4 to 6 input events.

## Evidence

- Self test: `tools/brush/selftest.sh` -> docs/brush/selftest.txt (40 checks: each glyph hits exactly
  its target, every info key present, vertical line rejected, a real Kindle press lights the lamp
  and the same press held 1.2 s does not, the Kindle 40 px tolerance (hit at radius + 30 px, missed
  at radius + 55 px), Kindle and Tie ink costs, Tie telling both posts in stroke order both ways,
  the post-to-post line with no posts and a line from one post to nowhere both Slash, a Tie
  without ink for the rope failing with no_ink, both key-release orders, refusals,
  closing on focus loss / disable / outside unpause / Escape, world frozen while open, rays while
  paused, ink drain, cut-off, no_ink, refill over time and on enemy_died).
- Desktop (Forward+, windowed): docs/brush/desktop_*.png from
  `tools/screenshot_desktop.sh <png> scene=res://scenes/dev/brush_demo.tscn demo_draw=<glyph> demo_hold=3 shot_after=2.8`.
- Browser (Compatibility, WebGL 2): `tools/brush/web_brush.sh --pointer mouse|pen` after
  `tools/export_web.sh` -> docs/brush/web/ (console logs and half-size JPEG screenshots of each glyph
  open and after).
- Lead's smoke check on the demo: docs/brush/smoke_web.png, docs/brush/smoke_web_console.txt.

## Browser proof

`tools/brush/web_brush.cjs` serves build/web, opens the demo in the installed Chrome (headless,
real GPU through ANGLE D3D11), and drives it only with CDP input events: a left click to capture
the mouse (the demo requests capture on click, like the game), then for each glyph it holds a
brush key (Left Shift for bloom, Q for slash, right mouse for gust, Shift for kindle, Q for tie,
then Shift again for a bloom with the key held 6 s after the stroke), paints the glyph over its
target at real speed (about 65 events a second, a 0.9 s circle and loop, a 0.16 s flick for the
slash, a 0.15 s dab on the lamp's wick, which is two points 1 px apart for the mouse and a
4 px slip with tremble for the pen, and a 0.45 s line from post A to post B), releases the button and then
the key, and reads the demo's `BRUSH_DEMO` console lines. Pass needs, per glyph: brush opened
with the tree paused, the orbiting ring did not move while open (checked every 0.25 s), the
glyph recognised, its target's `on_glyph` returned true and reacted, the tree unpaused on close,
the ring moving again, and no console or page errors. For the Tie, both posts must react, post A
told first (`order` 0) and post B second. `--pointer pen` sends the same strokes
as pointerType pen with force rising from 0.25 to 0.95 and back.

Result (both mouse and pen passed, Chrome 157, all six runs each including Kindle and Tie): pointer lock released within 250 ms of the
key going down, the mouse mode was visible while painting and captured again after closing,
and `document.pointerLockElement` was set again 0.5 s after closing in every run, including
the one with the key held 6 s after the last click. Caveat: CDP-dispatched input is what
headless Chrome treats as user activation here; a real person holding the key for a long time
was not tested, and if the browser refuses the lock the mouse is left visible and the game's
"lost capture is a pause" rule applies.

Web renderer note: the first browser run stalled for more than 5 s right after a Kindle, because
the demo lamp created its light and a new emissive material when it lit, and the Compatibility
renderer compiled shaders on the spot. The lamp now builds its flame and light (unlit) up front.
Anything that reacts to a glyph on the web should do the same.

## Additions beyond the contract

Public members and info fields added for Kindle and Tie, beyond docs/CONTRACTS.md:

- `BrushGlyphs.GLYPHS` now has `&"kindle"` and `&"tie"`; `BrushGlyphs.SHAPE_GLYPHS` (bloom, slash, gust:
  the template-matched ones); `NAMES` has Kindle and Tie.
- `BrushGlyphs.recognise(points, height = 720, duration = 0.0, posts = [])`: posts are
  `[{"pos": Vector2, "radius": float px}]`; a Tie result has `tie: [start index, end index]`.
- `BrushGlyphs.is_dab(points, height)`, `BrushGlyphs.post_at(point, posts, except = -1)`, and the
  `DAB_*` and `TIE_*` constants.
- `Brush.KINDLE_MARGIN`, `Brush.KINDLE_INK`, `Brush.TIE_INK`, `Brush.GROUP_TIE_POST` (`&"tie_post"`).
- `info.duration` (seconds the tip was down; 0 for `inject_stroke`), and for a Tie
  `info.tie_anchors` (PackedVector3Array: start post anchor, end post anchor). `info.targets` for a
  Tie is the two posts in stroke order.
- `Brush.last_result.input.duration`.
- `BrushStroke.dab(centre, width)` (the dab's ink geometry, used by the live view and the card).
- `BrushTieHints` (internal to the brush layer).
- `inject_stroke`: one point, or a few within a dab's size, is a Kindle (press time 0).
