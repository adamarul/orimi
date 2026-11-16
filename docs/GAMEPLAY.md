# Gameplay: Orimi, The Unfaded Vale

Owner: gameplay (ws/game). This covers the game loop, the player, camera and enemies, the
interface, and the QA hooks. Contracts (markers, events, autoloads) live in docs/CONTRACTS.md.

## Flow

`scenes/game/main.tscn` (script `scripts/game/main.gd`) owns the screens:

1. **Title.** The valley builds behind a paper wash (`Valley.build_async`, with progress text),
   then the camera drifts slowly over the shrine. Any key or click starts. `Brush.enabled` is
   false.
2. **Intro card.** One paper card of story. Any key or click dismisses it.
3. **Valley.** Orimi spawns at `M_Spawn`, with movement and camera prompts.
   - Thorn gate at `M_GateA`: **Slash** across it.
   - Reed Shallows (`M_ZoneA`, Splotchets): fight, then **Bloom** on the sapling. This restores
     the zone and makes it the checkpoint.
   - Crossing (`M_Crossing`, stepping stones; the river can be waded) and the soot bank at
     `M_GateB`: **Gust** through it.
   - Soot Terrace (`M_ZoneB`, Reedwraiths and Splotchets): Gust strips a Reedwraith's veil,
     then Slash or tail swipes kill it. Bloom on the sapling.
   - Camphor Rise (`M_Tree`): a final wave in two pulses of both enemies, then Bloom on the
     great tree.
4. **Finale.** A cinematic camera, then `finale_started` and colour sweeping across the valley
   (render's CurseField, driven from gameplay), then `valley_restored` and a wide shot.
5. **End card.** Stats (time, kills, deaths). Any key returns to the title, and the run resets.

Death: the petals empty, Orimi folds up, and after 1.6 s she respawns at the last restored zone
(the shrine before that) with full health. Restored zones stay restored.

State lives in the `Game` autoload (`scripts/game/game.gd`): `state` (title, cutscene,
playing, paused, ended), `restored_zones`, `checkpoint`, `deaths`, `kills`. `Game.set_state`
emits `game_state_changed` and sets `Brush.enabled = (state == playing)`.

## Controls

| Action | Keys |
|---|---|
| Move | W A S D |
| Camera | mouse (captured) or arrow keys |
| Jump | Space |
| Tail swipe | left click or J; press again during the swipe for the second swipe |
| Brush | hold Shift, Q or right mouse, then draw with the left button |
| Pause | Esc or P (in the browser, Esc releases the pointer and that pauses) |
| Paper intensity | F2 or O |

Mouse capture: the first left click in play captures the pointer and is consumed; that is the
only click main.gd consumes. Losing capture during play pauses, except while `Brush.is_open()`
and for 0.6 s after the brush closes, because the brush releases and retakes the pointer itself.
Nothing in gameplay marks the `brush` action as handled.

## Tuning

Player (`scripts/game/player.gd`): run 6.4 m/s, acceleration 40 and deceleration 48 m/s²
(air 16 and 6), turn rate 16, jump 8.2 m/s with gravity 23 rising and 34 falling, a 0.45 cut
on early release, 0.12 s coyote time and 0.14 s jump buffer. 5 HP, 1.1 s of invulnerability
after a hit, 0.3 s hurt stun. Knockback from a hit is 7 m/s, cut to 1.5 m/s when the path
behind her drops off a ledge.

Swipes take their timing from the fox model's animations: attack_1 is 8 frames at 12 fps with
the smear on frames 2 and 3, and attack_2 is 10 frames with the smear on 2 to 4. A press during
attack_1 queues attack_2, which starts as soon as attack_1's active frames end. Moving during
the follow-through cancels it. Damage is 1 per swipe. Knock is 4.5 and 9.0, and the lunge is
3.5 and 4.5 m/s. Soft aim assist turns the swipe toward an enemy within 3.6 m and 1.2 rad.

Camera (`scripts/game/game_camera.gd`): distance 4.9 m (1.4 m minimum when something is in
the way), pivot 0.95 m above the feet, FOV 57, default pitch -16 degrees (range -62 to 14). Follow
rates are 9 horizontal and 5 vertical, and it recentres behind Orimi after 2 s without camera
input. The collision probe (0.22 m sphere) ignores brush targets and enemies, and ignores
geometry it starts inside. Spawn, respawn and warps snap the camera to its framing at once, so
it does not swing in. At this framing the fox is about 15 to 18% of the screen height.

Enemies (`scripts/game/enemy_base.gd` and its two kinds):
- Splotchet: 2 HP. Hops at 4.4 m/s and lunges at 8.5 m/s from 2.8 m after a 0.45 s windup. Two
  swipes or one Slash kill it, and a Gust bowls it over.
- Reedwraith: 2 HP. Veiled, it ignores every blow until a Gust strips the veil and stuns it for
  2.8 s. It drifts between 4.8 and 8.5 m from Orimi, and lashes at 13 m/s from 3 to 7 m after a
  0.7 s windup.
- Both keep to their ground. They never walk down a slope steeper than about 40 degrees or off
  a ledge, and knockback is cut so they land before the edge. Attack tokens let at most two
  enemies strike at once.

Zones (`scripts/game/cursed_zone.gd`): Bloom is refused, with a prompt, while enemies live.
Restoring takes 2.6 s, emits `zone_restore_started` and `zone_restored`, and moves the
checkpoint.

## QA hooks

Boot options, given on the command line after `--` or in the web URL query:

| Option | Effect |
|---|---|
| `warp=M_<Marker>` | Skip the title and intro and start at a marker. At `M_Zone*` Orimi stands 6 m back toward the previous marker, facing in; at a gate she stands 4 m on the near side. |
| `god=1` | Orimi takes no damage. |
| `autoplay=1` | `AutoplayDirector` plays the whole slice through the real systems: AI inputs, real swipes, and glyphs drawn as strokes through `Brush.inject_stroke` (after `Brush.refill()`). It logs a QA line per stage and a summary. |
| `shots=<dir>` | Desktop autoplay saves a screenshot per stage. |
| `autoplay_quit=1` | Quit when autoplay ends; exit code 1 on failure. |

Scripts:
- `tools/game/autoplay_headless.sh` runs the full headless loop. The log goes to
  `build/game/autoplay_headless.log`, and the exit code is the result.
- `tools/game/web_autoplay.sh [--out DIR] [--timeout S]` runs the same loop in Chrome on
  build/web (run `tools/export_web.sh` first). It writes console.txt, qa.jsonl,
  NN_<stage>.png and summary.json.
- `tools/screenshot_desktop.sh <png> warp=M_ZoneA god=1 shot_after=6` takes a desktop shot.
- `scenes/dev/gameplay_demo.tscn` is the player, camera, enemy and brush sandbox. Its
  `selftest=1` prints `demo_selftest`.

QA lines are `QA:{"tag":..., "data":...}`. Tags: stage, wave, prompt, enemy_died,
glyph_cast, autoplay_cast, autoplay_skip_waypoint, autoplay_fail, autoplay_end, title_ready,
play_started, valley_restored, end_card.

## Evidence

`docs/game/` holds the latest run. web/ has the browser autoplay (20 stage shots,
qa.jsonl, console.txt, summary.json) and a 6 s browser shot at `warp=M_ZoneA god=1`. desktop/
has desktop shots at each route stage. headless_autoplay_qa.jsonl has the QA lines of the last
headless run.

## Known weak spots

- Camphor Rise's west flank is a steep slope. Walking off it leaves the player in the
  lowland, and the only way back up is the long walk round through the crossing and the gate B
  ramp.
- Fights are tough for a player who does not dodge: autoplay reaches the end of the Soot
  Terrace on 1 or 2 petals. Reedwraith lashes from outside swipe range are the main cause.
- West of the gate B ramp there is a pocket at river level whose walls are a steep ridge. A
  player in it has to walk back out to the river and take the ramp from its north end.

## Environment pieces

The valley places vfx's `scenes/env/` sky, mist and foliage scatter when they exist. The soot
bank uses `scenes/env/soot_bank_visual.tscn`, and `ModelKit.soot_bank` (inked dark puffs) is
the fallback when that scene is missing. The assets river mesh
(`scenes/models/river_surface.tscn`) gets vfx's shared `materials/env/water.tres`. A wading
floor sits 0.22 m below the surface because the river bed is 2 m deep.
