# The level kit

How to build a playable level for Book One without reading gameplay's code. Gameplay (ws/game)
owns the kit and this guide; a level workstream owns its own folders (docs/LEVELS.md, "How the
level workstreams work") and only uses what is described here. If the kit cannot do something
your level needs, ask gameplay for a hook rather than copying or editing kit code.

**Status.** This is the first version. It covers what exists on ws/game at step 2: the level
base, the data file, the registry, flags and objectives, people and talk, sealed fights, enemy
spawns, cursed zones with saplings, cursed ground with safe causeways, glyph obstacles
(thorns and soot), the general glyph target, verse-stones, Kindle targets, Tie posts, the
finishing stroke, curse slots, beads and the autoplay route. Also checkpoints, level exits,
camera zones and fading props, and ready-made scenes for every part under scenes/game/kit/.

The worked example is scenes/levels/example/ (example.tscn and level.json). It uses every
part that exists so far and passes its own autoplay: run it with
`tools/game/autoplay_headless.sh level=example` and
`tools/game/web_autoplay.sh level=example`.

## 1. What a level is

A level is a scene at `scenes/levels/<id>/<id>.tscn` whose root node has the script
`res://scripts/game/kit/level.gd` (class `Level`), or a script of yours in
`scripts/levels/<id>/` that extends `Level`. Beside the scene sits `level.json`, the data file:
objectives, lines, warps and the autoplay route. The registry
(`scenes/levels/levels.json`, owned by the lead) lists the levels in playing order.

When the game loads a level, the base:

1. resets the curse slots and sets the valley-wide grey to `start_gloom`;
2. reads `level.json`;
3. adds the shared sky and a sun if the scene has no WorldEnvironment / DirectionalLight3D;
4. calls `_build(progress)` (override it only if you build in code; most levels do not);
5. gives trimesh collision (layer WORLD) to every MeshInstance3D under nodes in the group
   `level_ground` that have no collision of their own;
6. reads every Node3D named `M_*` as a marker;
7. spawns Orimi and the camera at the spawn marker, facing `spawn_facing` (data) or the marker's
   -Z, and threads her beads onto her cord.

Rules:

- Everything walkable must be on the WORLD physics layer (the `level_ground` group does this for you).
- Put every kit node anywhere under the level root. Kit nodes find the level through
  `Game.level`; never reach into gameplay's scripts from yours.
- A node's scene type must match its script's base class: `GlyphObstacle` and `BloomTarget` are
  StaticBody3D; `EnemySpawn` is Marker3D; `Level`, `Person`, `SealedFight` and `CursedZone` are Node3D.
  A mismatch drops the script silently.
- Node names are how the data file and the autoplay route refer to things, so give every kit
  node a unique, readable name.

### Level exports

| Export | Type | Default | Meaning |
| - | - | - | - |
| level_id | StringName | | The id in the registry, for example `tallowford`. |
| display_name | String | | Intro card, title level list, completion banner. |
| chapter | String | | Shown under the name. |
| intro_text | String (multiline) | | The intro card when the level starts. |
| spawn_marker | String | M_Spawn | Node3D Orimi starts at. |
| data_file | path | level.json beside the scene | The data file. |
| shared_environment | bool | true | Add the shared sky and a sun when the scene has none. |
| start_gloom | float 0..1 | 1.0 | Valley-wide grey at the start (1 = drained). |
| auto_collision | bool | true | Collision for the `level_ground` group. |
| title_marker | String | | The title camera orbits this marker when this level is behind the title. |
| ground_overhead | float | 40 | `ground_at` looks for the ground from high above; a floor found more than this far above the point asked about is a roof, and the floor under the point is used instead. Indoors (a tunnel, a hall with a roof) set it to about 1. Outdoors leave 40. |

### Level signals and methods

| Signal | When |
| - | - |
| flag_changed(flag: StringName, value: bool) | Any flag set or cleared. Listen to it for scripted moments. |
| objective_completed(index: int, text: String) | An objective's flags are all set. |
| level_completed | The level is complete (rewards and the raft follow). |
| level_built | Built: ground collision made, markers read, Orimi spawned. |

| Method | Use |
| - | - |
| set_flag(flag, value = true) / get_flag(flag) / all_flags(list) | Named flags (below). |
| marker(name) -> Vector3, has_marker(name) | Marker positions (any node by name works). |
| node(name) -> Node | A node anywhere in the level by name. |
| ground_at(p, ignore = null) -> Vector3 | The ground under p (brush targets ignored). Under a roof, see `ground_overhead`. |
| ready_to_settle() | `await Game.level.ready_to_settle()` in a node's `_ready` before calling `ground_at`: it returns once the level is built (at once if it is). A node that settles earlier finds no ground, or the roof. The kit's checkpoints, people and fight rings do this. |
| show_restored() | Override: the level as the player left it (restored, no events). The title shows the first level this way once the book is finished; Hazewater's removes its gates and colours its zones and tree. |
| lines(talk_id) -> Array, has_lines(talk_id) | Conversations from the data file. |
| current_objective() -> String | Text of the first objective not yet met. |
| complete() | Finish the level now. Safe to call twice. |
| run_finale(zone) | Override for a level's big ending; called by a CursedZone with `finale = true`. The default restores the zone and completes the level. |
| apply_warp(marker) / _on_warp(marker) | QA warps (below). Override `_on_warp` for more than flags. |

## 2. The registry entry

`scenes/levels/levels.json` (the lead edits it; you send the entry):

```json
{"id": "tallowford", "name": "Tallowford", "chapter": "The Lamps of Tallowford",
 "scene": "res://scenes/levels/tallowford/tallowford.tscn",
 "bead": "lamp gold", "bead_color": "#d9a441"}
```

`levels` is the book in order; an entry whose scene does not exist yet is skipped, so the game
always runs. `dev` entries load only with `level=<id>`, give no bead, have no next level and
do not count as progress. Every new level starts under `dev` (the example stays there); the
lead moves it into `levels` once its browser autoplay passes, and from then on it is in the
title's chapter list, Continue and Pell's raft travel.

## 3. The data file (level.json)

```json
{
  "spawn_facing": "Mender",
  "complete_on_objectives": true,
  "objectives": [
    {"text": "Talk to the Mender", "flag": "talked_mender"},
    {"text": "Win the sealed fight", "flags": ["fight_knot"]}
  ],
  "lines": {
    "mender": [{"text": "Take up your brush and cut across them with a *Slash*."}],
    "mender_again": ["The Mender: The grove is past the knot."],
    "greyed_faded": [{"who": "", "text": "Sorrel stands grey and still."}]
  },
  "raft": {"talk": "pell_leaves", "card": "Pell poles the raft upriver."},
  "warps": {"M_Grove": {"flags": ["thorns_cut", "fight_knot"], "face": "Grove", "route_from": "fight_won"}},
  "hints": [
    {"id": "snare", "near": [12.5, 0, 31], "radius": 3.5, "text": "Tie them with a %s.", "glyph": "tie", "until": "caught_snare_a"},
    {"id": "pond", "flag": "fell_in_pond", "text": "Deep water sends her back to the bank."}
  ],
  "barks": {"picked_map_leaf": "leaf_found"},
  "autoplay": {"chain": [[0, 0, 26], "M_Bridge", [0, 0, -10]], "route": []}
}
```

| Key | Meaning |
| - | - |
| spawn_facing | Marker or node name Orimi faces at the start. |
| objectives | In order. Each is met when its `flag` and all its `flags` are set. Not shown on screen; `current_objective()` gives the text. |
| complete_on_objectives | Default true: the level completes when every objective is met. Set false if a finale calls `complete()` itself (Level 1 does). |
| lines | Conversations by id. A line is `{"who", "text"}` or a string `"Name: text"`. No `who`: spoken by the Person who owns the lines; `"who": ""`: narration with no name. `*word*` is shown in the accent colour. Keep lines short (one or two sentences). |
| raft | After completion: `talk` is a lines id shown as a cutscene (Pell), `card` is the travel card text. |
| end_text | The end card's heading when this level is the last in the book (BBCode; `[font_size=34]` for the title line). Without it the card shows the level name, chapter and bead. The time, kills, falls and beads follow either way, and "More of the book is still being written" only while levels.json has dev levels or book levels without a scene. |
| safe_ground | Safe shapes for each CursedGround (section 7). |
| warps | For `warp=<marker>`: `flags` to set first, a marker or node to `face`, and `route_from`, the route stage the autoplay resumes after (`level=<id> warp=<marker> autoplay=1`). Kit nodes read their own flags, so a warp needs no level script for them: a TiePost pair whose flag is set is already tied (bridge laid, pulled object in place, rope drawn, no effects), a SealedFight whose done_flag is set starts won (no knot, no ring, no rewards), and a GlyphObstacle whose cleared_flag is set is gone. |
| hints | Prompts from data. With `near` (a point) the prompt shows when Orimi comes within `radius` (4 m) and hides when she leaves or `until` is set; `flag`, if given, must be set too. Without `near` it shows once when `flag` is set. `text` is BBCode; `%s` becomes `glyph`'s name in the accent colour. `id` (default `level_hint_<n>`) names it for `hide_prompt` and for the autoplay's `expect_prompt`. In a level script, `Game.main.prompt_near(id, text, glyph)` does the same. |
| barks | Narration with no Person: flag -> lines id. When the flag is set the lines show on the panel without stopping play (after any open conversation closes; not for flags a warp sets). Lines without `who` show no name. |
| autoplay | The scripted run (section 10). |

## 4. Flags and objectives

Flags are named booleans on the level. Kit nodes set them and wait on them, so most levels
need no script at all. Flags set by the kit:

| Flag | Set by |
| - | - |
| restored_<zone_id> (or the zone's restored_flag) | CursedZone, when restored. |
| fight_<fight_id> (or done_flag) | SealedFight, when won. |
| talked_<talk_id> | Person, after the first talk while awake. |
| talked_<talk_id>_faded | Person, after a talk while faded. |
| the obstacle's cleared_flag | GlyphObstacle, when cleared. |

Kit nodes that wait on flags: CursedZone `requires_flags` (Bloom refused until set), SealedFight
`requires_flags` (the knot appears only then) and `start_flag`, Person `wake_flag`.

A level script hooks scripted moments without touching kit code:

```gdscript
extends Level

func _ready() -> void:
	super._ready()
	flag_changed.connect(func(flag: StringName, on: bool) -> void:
		if flag == &"talked_old_wick" and on:
			set_flag(&"wick_lamp_ready"))
```

Also available from anywhere: `Game.set_flag(flag)` / `Game.get_flag(flag)` (the current level's flags) and
`Game.hint(id)` (a tutorial prompt). Signals on `Game`: `level_loaded(level)`, `enemy_finished(enemy)`.

## 5. People and talk (Person)

Script `res://scripts/game/kit/person.gd`, a Node3D. Walk up and press E or Enter (the prompt says
so); the talk panel shows the lines one at a time (click, E, Enter or Space to advance). While
talking the game is in the talk state: Orimi stands still and the brush is put away.

| Export | Default | Meaning |
| - | - | - |
| display_name | | Name on the panel. |
| talk_id | node name in snake_case | Key of the lines in level.json. |
| model_scene | | A folk wrapper from `tools/assets/gen_folk.sh` (docs/ASSETS.md, "Folk"), e.g. `scenes/levels/tallowford/folk/old_wick.tscn`. |
| model_name | | Or a shared model: `scenes/models/<model_name>.tscn`, e.g. `folk/pell`. |
| robe_color, hat | | The paper placeholder used while no model exists (hat: "", "paper", "brim"). |
| faded | false | Start grey and still. |
| wake_flag | | Wake when this flag is set. |
| talked_flag / talked_faded_flag | talked_<talk_id> / talked_<talk_id>_faded | Set after a finished talk. |
| talk_radius | 2.4 | How close Orimi must be. |
| show_flag | | Shown (and talkable) only once this flag is set. |
| hide_flag | | Hidden once this flag is set. |
| talk_by_flag | {} | flag -> lines key: switches what they say. The last listed flag that is set wins; none set: talk_id. |
| bark_near | | A lines key said as a **bark** when Orimi first comes within bark_radius (again only after she has gone and come back). |
| bark_radius | 7 | |
| bark_on_flag | {} | flag -> lines key: barks when the flag is set (while shown), but not for flags a warp sets. |
| face_player, frame_camera | true | Turn toward Orimi; aim the camera at them while talking. |

A bark is a line in the talk panel that does not stop play: no talk state, nothing to press,
it goes by itself after a few seconds a line, and a real conversation replaces it.

Which lines play (for the key talk_by_flag chose, else talk_id): while faded, `<talk_id>_faded` (if the data has none, a faded person cannot be
talked to); awake, `<talk_id>` the first time and `<talk_id>_again` after (falls back to `<talk_id>`).
Signals: `talked(talk_id)`, `woken`. Methods: `talk()` (await it), `bark(key)`, `wake(instant = false)`,
`can_talk()`, `is_shown()`.
A folk model drains and wakes itself (two atlases); the placeholder is greyed through its InkLook.

### VerseStone

Script `res://scripts/game/kit/verse_stone.gd`, a **StaticBody3D**. Bloom it and it speaks its lines
(four short lines of the Ink-maker's story) on the talk panel, then sets its flag. It can be read
again. Level 1 has one beside the shrine.

| Export | Default | Meaning |
| - | - | - |
| talk_id | node name in snake_case | Key of the lines in level.json. |
| display_name | Verse-stone | Name on the panel for lines without "who". |
| read_flag | read_<talk_id> | Set after the first reading. |
| teaches | | A glyph (kindle, tie, ...): a prompt explains it once the lines end. |
| teach_text | "The stone remembers a stroke: %s." | The prompt; `%s` becomes the glyph's name. |
| model_scene | | Your own stone (default scenes/models/verse_stone.tscn, else a placeholder). |

Signal `read`. Autoplay: `{"cast": "bloom", "target": "VerseStone", "flag": "read_verse_stone"}`.

## 6. Fights

### EnemySpawn

Script `res://scripts/game/kit/enemy_spawn.gd`, a Marker3D where an enemy appears (dropped onto the ground).

| Export | Default | Meaning |
| - | - | - |
| kind | splotchet | `splotchet` or `reedwraith`. |
| enemy_scene | | Your own enemy: a scene whose root script extends `EnemyBase` (below). Overrides kind. |
| wave | 0 | Under a CursedZone: 0 at load, 1+ the zone's final wave pulses. Under a SealedFight: the fight's waves in order. |
| aggro | false | Start hunting Orimi. |
| territory_radius | 0 | Metres across the ground from the spawn point. Above 0 the enemy ignores Orimi while she is farther than this from it (an ink-spawn penned in a yard does not chase her across the level), and drops the chase when she leaves. 0: no limit. Example: `Penned` (radius 3), autoplay `{"expect_calm": "Splotchet_Penned"}`. |

On its own (not under a zone or fight) it spawns once when the level is built and roams near itself.

### SealedFight

Script `res://scripts/game/kit/sealed_fight.gd`, a Node3D at the centre of the fight, with EnemySpawn
children. A knot of black cord drifts near the centre; when Orimi touches it a ring of ink wash
and torn-paper screens rises, the waves rise one after another, and Orimi cannot leave the ring
until every enemy has fallen apart. Then the ring sinks, ink is paid, Orimi is healed, the
checkpoint moves to where she stands, and the done flag is set. If Orimi falls in the ring, the
fight resets and the knot comes back.

| Export | Default | Meaning |
| - | - | - |
| fight_id | fight | Used for the default flag. |
| radius | 5.0 | Ring radius in metres. |
| requires_flags | [] | The knot appears only when all are set. |
| done_flag | fight_<fight_id> | Set when won. |
| start_flag | | No knot; the fight starts when this flag is set (an ambush). |
| reward_ink | 30 | Ink added on the win. |
| heal_on_win, checkpoint_on_win | true | |
| knot_drift | 1.5 | How far the knot wanders. |

Signals `fight_started`, `fight_won`; properties `started`, `done`, `enemies`; method `start()`.
If done_flag is already set when the level loads, or a warp or script sets it before the fight
starts, the fight is over: no knot, no ring, no enemies and no rewards. Don't set `done` by hand.

Every enemy of the fight is held inside its ring and on its ground: it is kept within
`radius - 0.5` m of the centre (EnemyBase `confine_center` / `confine_radius`), and one that gets
more than 1.5 m below the fight node (down a slope off a hilltop) is put back up inside the ring,
so none can sit out of reach while Orimi is held in. Place the fight node on the ground at the
ring's centre. A Reedwraith fits its circling band to the ring (at most 1.2 x the held radius).
Example: `Knoll`, a fight on top of a 5 m hill with 30-degree sides (stages `knoll_ring`,
`knoll_won`).

### The finishing stroke

Every enemy at zero health unravels for 1.5 s before it falls apart (`is_defeated()` is then true).
A Slash through it in that window is a clean cut: 25 extra ink, a petal burst and
`Game.enemy_finished(enemy)`. Zones and fights wait for unravelling enemies before they count as clear.

### Your own enemy or boss

Make a scene whose root is a CharacterBody3D with a script that `extends EnemyBase` and set it as an
EnemySpawn's `enemy_scene`. Override only these:

| Override | Purpose |
| - | - |
| _model_name() -> String | Model under scenes/models/ (or return "" and build in _build_placeholder). |
| _build_placeholder() -> Node3D | A model built in code. |
| _collision_size() -> Vector2 | Capsule radius and height. |
| _think(delta) | Movement and attacks each physics frame (use `player_target()`, `flat_to()`, `velocity`, `_strike()`). |
| _on_glyph(glyph, info) -> bool | Reactions to glyphs; return true when it did something. |
| _can_be_hurt(source) -> bool, _on_blocked(source) | Armour or phases (a veil, a guard). |
| _apply_gravity(delta) | Vertical motion every physics frame, stunned or not. Default: fall when off the floor. A flyer holds its height here. |
| keeps_to_ground() -> bool | Default true: stops at ledges and drops, knockback pops it up but never off its ledge. A flyer returns false (flat knockback, no ledge checks). |
| spawn_height() -> float | Height above the ground EnemySpawn puts it at (default 0.1). |

**A flying enemy.** scenes/levels/example/hover_blot.gd (with hover_blot.tscn) hovers 4 m
over the ground (the height Level 4's Sootflit circles at), drifts after Orimi, winds up and dives, then rises: it overrides the three
movement hooks above and casts its own ray for the height under it (`_ground_y()` reaches
only 3 m down). Up in the air only a
Slash hurts it (`_can_be_hurt`); a Gust downs it for 3 s (`keeps_to_ground()` turns true and
it falls), and then a tail swipe does. It guards the example's Grove (spawn `Flyer`, stage
`flyer`). The autoplay's `fight` step Gusts any enemy whose `keeps_to_ground()` is false while
it is more than 0.5 m over the ground, before anything else and from where Orimi stands (it
never walks her off an edge after a flyer), then closes in to swipe. An enemy on another level
within 12 m, or any enemy while a ring holds Orimi in, is Slashed from where she stands instead
of walked to. Level 4's Sootflit starts from
the same hooks.

Set `kind`, `max_hp`, `hp` and `aggro_range` in `_init()`, and call `super._ready()` first if you
override `_ready`. Read
scripts/game/splotchet.gd and scripts/game/reedwraith.gd as working examples.

## 7. Cursed zones, saplings and obstacles

### CursedZone

Script `res://scripts/game/cursed_zone.gd`, a Node3D at the zone centre. The Spill is drawn over its
radius; EnemySpawn (or EnemyBase) children guard it; a Bloom on its sapling restores it once
they are gone and its required flags are set. Restoring sets the restored flag, moves the
checkpoint beside the sapling, heals Orimi and emits the zone events audio and vfx react to.

| Export | Default | Meaning |
| - | - | - |
| zone_id | zone | Unique in the level. |
| display_name | | The "colour restored" banner. |
| radius | 12 | Metres. |
| target_kind | sapling | `sapling`, `great_tree`, or `none` (give it your own BloomTarget child). |
| target_offset | (0,0,0) | Where the sapling stands, from the centre. |
| requires_flags | [] | Bloom is refused until all are set. |
| finale | false | Bloom hands over to `Level.run_finale(zone)`. |
| restored_flag | restored_<zone_id> | |
| checkpoint_on_restore, curse_light | true | |

Signals `cleared_enemies`, `restored`. The sapling is a child named `Sapling_<zone_id>` (`GreatTree` for a great tree).

### CursedGround: ground that keeps you out

Script `res://scripts/game/kit/cursed_ground.gd`, a Node3D at the centre of a cursed area. Inside its
radius the ground hurts Orimi (1 health, then the usual brief invulnerability) and throws her
back toward where she last stood safely; if she is still on bad ground after 1.6 s she is put
back there. She crosses on **safe ground**, listed as data in level.json under `safe_ground`,
keyed by the node's name:

```json
"safe_ground": {
  "Mire": [
    {"path": ["M_MireEdge", [11, 0, 3.5], "M_Island"], "width": 2.2},
    {"circle": "M_Island", "radius": 2.2},
    {"polygon": [[20, 0, 0], [22, 0, 0], [22, 0, 4]]},
    {"path": ["M_A", "M_B"], "width": 1.6, "flag": "causeway_clear"}
  ]
}
```

Safe ground has one data format, this one. In addition, anything Orimi stands on whose
collision body (or an ancestor of it) is in the group `safe_ground` is safe wherever it lies:
a Tie rope bridge is, and a level's own modelled planks can be. Points are marker or node names or [x, y, z] (only x and z count). A shape with `flag` is safe
only once that flag is set (a causeway buried in soot until a Gust clears a GlyphObstacle whose
cleared_flag it is). Open safe shapes are marked with a pale wash on the ground; turn
`show_safe` off when the level models its own causeways.

| Export | Default | Meaning |
| - | - | - |
| radius | 10 | Metres. |
| clear_flag | | The ground is clean once this flag is set (for example `restored_<zone_id>`). |
| damage | 1 | Health lost per hurt. |
| max_height | 2.5 | Orimi this far above the centre (on a bridge) is out of reach. |
| draw_curse | true | Draw the Spill over the radius. |
| show_safe | true | The pale wash on safe shapes. |

Where she is put back is a spot she stood on for at least 0.35 s (`SAFE_HOLD`) and at least
0.5 m (`SAFE_MARGIN`) inside clean ground: inside a safe shape by 0.5 m, 0.5 m outside the radius
or 0.5 m above `max_height`. A rope bridge or other `safe_ground` body counts as it is. So she is
never put back on the very edge she stepped off, nor on a spot she only brushed in a jump.

Signal `cleared`; methods `is_safe(point, margin = 0)`, `clear()`; property `hurts`. Autoplay:
`{"probe_cursed": "Mire", "toward": point}` steps off the safe ground on purpose and fails unless
it hurts and pushes Orimi back (or, in a hollow, puts her back after `CursedGround.STUCK_TIME`). The render curse is a circle, so the Spill is still drawn
under a causeway; the wash (or your own planks and stones) is what shows the way.

### Curse slots: more than four cursed areas

The renderer draws four cursed areas at a time. `CurseSlots` (scripts/game/kit/curse_slots.gd)
gives the four slots to the four cursed areas nearest Orimi and swaps them as she moves (with
6 m of hysteresis), so a level may have any number of zones. You do nothing: zones register
themselves. Keep cursed areas that must be seen together to four or fewer.

### GlyphObstacle (thorns and soot)

Script `res://scripts/game/glyph_obstacle.gd`, a **StaticBody3D**, blocks the way until its glyph
lands on it. `glyph = slash` is a thorn gate, `gust` a soot bank.

| Export | Default | Meaning |
| - | - | - |
| glyph | slash | slash or gust. |
| width, height | 6.6, 3.2 | The blocking box. |
| model_scene | | Your own look (default: thorn gate or soot bank). |
| cleared_flag | | Set when cleared. |
| hint_id / hint_text | | Prompt when Orimi comes within hint_distance; `%s` in the text becomes the glyph's name. |
| hint_distance | 10 | |
| requires_flags | [] | The glyph is refused (refuse_hint, default "not ready") until all are set. |
| clears | [] | Other nodes cleared with it (a GlyphObstacle clears as if hit; anything with clear() has it called; anything else is freed). |

Signal `cleared_by_glyph`. If cleared_flag is set some other way (a warp), it removes itself at once.

### Reach: no glyph through walls

Every kit target (GlyphTarget, GlyphObstacle, KindleTarget, VerseStone, TiePost) answers a glyph
only when no solid wall stands between the view and it (`GlyphReach.clear`): a line from the
camera, or from Orimi, to the target's glyph anchor on the WORLD layer. Only a solid wall counts.
These are looked through: the target's own colliders and children, anything the anchor sits
inside, other glyph targets, props in `camera_fade` or `ink_skip` (trees, foliage, water, soot
banks, effects), and triggers. A hit within the target's glyph radius plus 0.6 m of its anchor
counts as the target's own surroundings (soot packed in a wheel, a lamp in a niche). A refusal
logs `glyph_blocked` with the wall's name and where it was hit. So a target the player can see
is never refused, and a bellows in the next room is. Example: `HiddenBellows` behind `BlindWall`,
autoplay `{"cast_blocked": "gust", "target": "HiddenBellows", "flag": "gust_hidden_bellows"}`
(stage `glyph_blocked`).

### GlyphTarget: any glyph, your own reaction

Script `res://scripts/game/kit/glyph_target.gd`, a **StaticBody3D**. The general glyph target: it
accepts the glyphs in its list (optionally only once its required flags are set), sets its flag,
clears the nodes in `clears`, and emits `glyph_received(glyph, info)`. It does not move or vanish
by itself; your level does that on the signal or the flag. Lily buds that Bloom opens into
platforms, a bellows that Gust works (and that blows soot off a route through `clears`), a seal
that Slash breaks. GlyphObstacle is the special case that blocks the way and goes away.

| Export | Default | Meaning |
| - | - | - |
| glyphs | ["bloom"] | Any of bloom, slash, gust, kindle, tie. |
| requires_flags | [] | Refused (refuse_hint) until all are set. |
| flag | <glyph>_<node name in snake_case> | Set when it answers, e.g. `gust_bellows`. |
| once | true | Answer only the first glyph. |
| clears | [] | Nodes cleared when it answers (as for GlyphObstacle). |
| model_scene | | Its look; without one it is invisible (give it your own mesh child). |
| size | 1.2 cube | Target box; the glyph anchor is at half its height. |
| solid | false | Orimi collides with it. |
| hint_id, hint_text, hint_distance | | Prompt near it, as for GlyphObstacle. |
| refuse_hint | not_ready | Prompt when refused for a missing flag. |

Property `answered`. Autoplay: `{"cast": "gust", "target": "Bellows", "flag": "gust_bellows"}`.

### KindleTarget: lamps, braziers, lantern-fruit

Script `res://scripts/game/kit/kindle_target.gd`, a **StaticBody3D**. A Kindle dab on its wick lights
it: the flame shows, a warm light comes up, and its flag is set. The brush calls
`on_glyph(&"kindle", info)` on the target under the dab.

| Export | Default | Meaning |
| - | - | - |
| kind | lamp | `lamp`, `brazier` or `lantern_fruit` (placeholder model and wick height). |
| lit_flag | lit_<node name in snake_case> | Set when lit (cleared again by `put_out()`). |
| requires_flags | [] | Refused with the "not ready" hint until all are set (a hooded lamp). |
| model_scene | | Your own look: a node named `Flame` is shown when lit; a node named `Wick` is where the dab lands. |
| start_lit | false | |
| light_color, light_range, light_energy | warm, 7, 1.6 | The light when lit. |
| light_keep | -1 | How much of its own colour the model keeps in a dark or drained place (its InkLook's `light_keep`, 0 follows the place, 1 untouched). -1 = automatic: 0.6 for a lantern-fruit, so it still reads on its branch in the dark; lamps and braziers keep the ink look's default. Example: `IslandFruit` (stage `fruit_lit`). |

Signal `kindled`; property `lit`; methods `kindle(instant = false)`, `put_out()`. Autoplay:
`{"cast": "kindle", "target": "IslandLamp", "flag": "lit_island_lamp"}`.

### TiePost: bridges, pulls and bindings

Script `res://scripts/game/kit/tie_post.gd`, a **StaticBody3D** in the group `tie_post`. Two posts make
a pair. A Tie stroke from one post's ring to the other's draws a rope of ink between them,
sets the pair's flag and does the pair's action. The brush calls `on_glyph(&"tie", info)` on both
posts, with `info.targets` holding the two posts in stroke order; either order works.

Set `partner` on one post of the pair; the pair's settings (action, flag, pull) live on that post.

| Export | Default | Meaning |
| - | - | - |
| partner | | NodePath to the other post. |
| action | bind | `bridge`: a crossing, a walkable rope bridge between the two posts' feet (WORLD layer, safe on cursed ground). `pull`: move `pull_target` to `pull_to` (drag aside or swing free). `catch`: the rope holds out for a moving target (below). `bind`: only the flag (a level script or boss listens). |
| tied_flag | tied_<node name in snake_case> | Set when tied. |
| requires_flags | [] | Refused with the "not ready" hint until all are set (either post's list). |
| pull_target, pull_to | | pull: the node moved and the node (usually a Marker3D) whose position and turn it takes, so a jammed log fixed to a post swings free when pull_to is the log's free pose rotated about the post. |
| pull_to_ground | true | Set the pulled node down on the ground at pull_to; off for a swing, which ends exactly at pull_to. |
| bridge_width | 1.5 | bridge: deck width. |
| sag | 0.35 | How far the rope dips in the middle. |
| model_scene | | Your own post; a node named `Ring` in it is where the rope ties on. |

Signal `tied_up(other)`; property `tied`. Autoplay: `{"tie": ["PostA", "PostB"], "flag": "tied_post_a"}`.
If the pair's flag is set some other way (a warp's flags, a level script), the pair ties itself
silently: the rope is drawn, the bridge is laid and a pulled object is at pull_to at once, with
no effects, no catch and no `tied_up`.

**Catching a moving target** (`action = "catch"`). The rope holds for `catch_window` seconds
(4). The first of `catch_targets` (NodePaths; empty: any enemy not yet defeated) that comes
within `catch_radius` (0.8 m, across the ground) of the line between the rings, between 2.5 m
below and 0.8 m above them, is caught: the rope bends to hold it (at its `glyph_anchor()` if it
has one), `catch_flag` is set (default `caught_<node name in snake_case>`) and the post with the
pair's settings emits `caught(target)`. A target with `on_caught(post)` is told and does the
rest (stops, struggles, falls); an enemy without one is stunned for `catch_hold` seconds (3).
If nothing crosses in time the rope slips: the tied flag clears and the pair can be tied again,
so the player times the stroke. Example: `SnareA`/`SnareB` and the drifting kite `Drifter`
(scenes/levels/example/drifter.gd) in the example level, stage `kite_caught`, routed with
`{"tie": ["SnareA", "SnareB"], "flag": "tied_snare_a"}` then
`{"wait_flag": "caught_snare_a", "timeout": 6}`.
A bridge over a gap must be the only way across, and the posts' feet should stand at the
height of the two banks.

### Checkpoint

Script `res://scripts/game/kit/checkpoint.gd`, a Node3D. When Orimi comes within `radius` (and its
`requires_flags` are set) it becomes her respawn point, heals her and sets `flag`
(default `reached_<node name in snake_case>`). With `show_model` off it is an invisible trigger,
which is also the simplest way to turn "Orimi got here" into an objective. Signal `reached`.

### LevelExit

Script `res://scripts/game/kit/level_exit.gd`, a Node3D. When Orimi comes within `radius` and every
flag in `requires_flags` is set, it sets `flag` (default `exit_reached`) and completes the level;
before that it shows the "not ready" hint. `model_name = "raft"` puts Pell's raft there. Use it
with `complete_on_objectives: false` in the data file. Signal `used`.

### DeepWater: water too deep to wade

`res://scripts/game/kit/deep_water.gd` (a Node3D). A box of `size` around the node, its top at
the node's height: a river, a pool, a moat. When Orimi gets into it she splashes (a ring on the
surface; the audio director plays `splash` from `Events.player_thrown_back`) and is put straight back on the bank she left: the newest ground she stood on that is at least
`bank_margin` (0.8 m) from where she went in and either outside the box or `bank_height` (0.25 m)
above the surface, so a sloping shore inside the box does not count as bank down to the
waterline. She then stands still for `return_hold` (0.4 s), so a held direction walks her back in
at most every second or so instead of looping; if she is back in the moment she can move, or the
bank point is itself in the water, she is put just outside the nearest edge of the box instead.
She takes no damage.

| Export | Meaning |
| - | - |
| size | x and z across the water, y how far below the surface the box reaches |
| show_surface | draw a surface with the shared water material (off if you model your own water) |
| sink | how far below the surface her feet must go before she counts as in it (0: at once) |
| bank_margin | how far (across the ground) from where she went in the bank point must be |
| bank_height | how far above the surface ground inside the box must be to count as bank |
| return_hold | how long she stands still after being put back |
| flag | set the first time she is put back (for a hint or a route check) |

The level's ground may run under the water (a flat test field) or stop at the bank (a real
channel); either way the box decides. `returns` counts the times she was put back. Example:
`Pond` in scenes/levels/example/example.tscn, stage `pond`, routed with `probe_water`; `Shore`
(stage `shore`) is water over a ridge whose far slope runs down into it, probed with `"hold": 2`
(keep pushing in for 2 s; fail on more than one return each 0.6 s).

### RisingHazard: ink that rises without trapping

`res://scripts/game/kit/rising_hazard.gd` (a Node3D; scenes/game/kit/rising_hazard.tscn). A
surface over a `size` box (x by z) that rises from the node's height to `top_height` above it
at `rise_speed` m/s: a flooding flue, a filling vat. It starts on `start_flag`, or (with no
start flag and `start_on_enter`) when Orimi steps into the box, and stops for good on
`stop_flag`. It never traps her: once the surface is `sink` (0.25 m) over her feet she is
lifted out onto the most recent ground she stood on at least `clearance` (0.4 m) above the
surface (a foothold she climbed past), or, if there is none, just outside the box. She takes
`damage` (1) without knockback, `flag` is set the first time, and it emits `lifted(to)` and
`Events.player_thrown_back(at, &"rising")`. Death and respawn put it back to the start;
`reset()` does the same from a level script. `surface_y()`, `height`, `rising`, `lifts` and
the `risen(height)` signal are there for the level (a door that opens at a height, a camera).

Autoplay: `{"probe_rising": "Sump", "toward": point}` walks into it and fails unless she is
lifted out above the surface or out of the box. Example: `Sump` with `SumpStep` in the example
level: she jumps onto the step, the ink rises, she steps off into it and is lifted back onto the
step (stage `sump_lifted`), then jumps clear.

### Pickup: leaves, keys, keepsakes

`res://scripts/game/kit/pickup.gd` (a Node3D). Orimi takes it by touching it (within `radius`,
0.9 m): it sets its `flag`, plays `sfx` (`pickup`), plays the VFX `pickup` effect in its `color`, shows a card
(`title` and `text` under it, through the HUD banner) and goes. Without `model_scene` it is a
bobbing paper leaf with a vermilion mark. `flag` defaults to `picked_<name in snake_case>`.
With `show_flag` it is hidden and cannot be taken until that flag is set (Tamsin marking the
first leaf). A pickup whose flag is already set stays gone. `take()` hands it over from code.

Count several with the level's flags, for example
`Game.level.all_flags(["picked_leaf_1", "picked_leaf_2", "picked_leaf_3"])` on `flag_changed`.
Route it in autoplay with `go` to it and `wait_flag`. Example: `MapLeaf` on top of the
`Ledge` in scenes/levels/example/example.tscn, taken in the `ledge` stage.

### The camera indoors: CameraZone and camera_fade

The follow camera never ends inside geometry: it sweeps a small sphere from Orimi to where it
wants to be and stops 0.12 m short of anything on the WORLD layer, coming as close as 0.45 m
in tight places. Walls and ceilings therefore need collision (put them under a
`level_ground` node or give them bodies). Brush targets never push it in.

**CameraZone** (`res://scripts/game/kit/camera_zone.gd`, a Node3D; its box is `size` around it)
changes the camera while Orimi is inside. The highest `priority` zone containing her wins, and
the camera blends in and out over `blend_time` (0.6 s).

| Mode | Use | Exports |
| - | - | - |
| follow | The usual camera with overrides: closer in a corridor, looking up a shaft. | distance (0 keeps 4.9), lock_pitch + pitch_deg (negative looks down, positive looks up), lock_yaw + yaw_deg (world), pivot_raise, fov |
| fixed | A set view from a marker. | view (a Marker3D), look_at_player |
| frame | A boss arena: looks along view's -Z and backs off until Orimi and every frame_targets node fit, with margin metres to spare (also kept out of walls). | view, frame_targets, margin, max_distance (backs off no farther than this from the framed centre, so Orimi on the far side can be a little farther; 0 no limit), stay_inside (never backs out of the zone's box), max_pitch_deg (65: a view tipped steeper is held to this) |

**Roofs need colliders.** The camera only stops at what it can hit: a room's ceiling with no
collision lets the frame and follow cameras back up through it, and `stay_inside` is the only
other guard. Give every roof and ceiling a body (or put it under `level_ground`).

Example: `TunnelCam` (follow, distance 2.6, pitch locked at -6) and `KnotCam` (frame on the
sealed fight, max_distance 12, stay_inside; stages `ring_rise` and `fight_won`, whose QA
lines carry the camera's zone and distance to Orimi) in scenes/levels/example/example.tscn. For a shaft, lock the pitch at about +30
and shorten the distance so the camera looks up past Orimi.

**Fading props.** Put a prop (its body or any ancestor of it) in the group `camera_fade` and the
camera passes through it instead of being pushed in, and the prop fades through its InkLook
dissolve while it stands between the camera and Orimi (a prop without an InkLook gets one the
first time it fades; mesh transparency does nothing in the web build). The prop needs a
collision body for the camera's ray to find it. Use it for pillars, racks and low beams, not
for walls. A sealed fight's ring screens are already in the group. Example: `Pillar` beside
the tunnel in scenes/levels/example/example.tscn (stage `pillar_fade`).

**Packed arrays in scripts.** Godot 4.7.2's web export drops a saved `PackedStringArray` (or
any `Packed*Array`) export whose script default is an array literal such as `= []`
(godotengine/godot#124452): the browser build silently reads the default. Declare such exports
with a constructor, `= PackedStringArray()` or `= PackedStringArray(["bloom"])`, as the kit
scripts do. Check with a browser run, because headless and the editor are not affected.

### Signals for effects and sound

VFX and audio hook the kit through these; a level can listen too.

| Signal | When |
| - | - |
| `Events.bead_awarded(level_id, color)` | finish_level adds a level's bead (first completion only); color is the registry's bead_color |
| `Events.player_thrown_back(at, cause)` | cause `water`: DeepWater put Orimi back (at is on the surface where she went in); `curse`: CursedGround hurt her and pushes her back (at is where she stood); `rising`: a RisingHazard lifted her out (at is on its surface) |
| `EnemyBase.unravel_started(duration)` | an enemy at zero health starts unravelling (1.5 s to the finishing stroke) |
| `VerseStone.woken` | the Bloom landed and the stone starts speaking (`read` follows when the lines end) |
| `CursedGround.hurt(at)` | Orimi was hurt on the ground |
| `KindleTarget.kindled`, `TiePost.tied_up`, `SealedFight.fight_started` / `fight_won`, `Pickup.picked` | as named |

Pickup plays `Vfx.play(&"pickup", at, {"color": color})` itself (its `color` export).

## 8. Ready-made scenes

Instance these from `scenes/game/kit/` instead of adding a script to a bare node (the node types
are already right), then set their exports:

| Scene | Root | Notes |
| - | - | - |
| thorn_gate.tscn | GlyphObstacle | glyph slash |
| soot_bank.tscn | GlyphObstacle | glyph gust, 6.4 by 3.4 |
| cursed_zone.tscn | CursedZone | a sapling and two Splotchet spawns |
| sealed_fight.tscn | SealedFight | two Splotchets, then a Reedwraith in wave 1 |
| enemy_spawn.tscn | EnemySpawn | |
| person.tscn | Person | |
| verse_stone.tscn | VerseStone | |
| lamp.tscn, brazier.tscn, lantern_fruit.tscn | KindleTarget | |
| tie_posts.tscn | Node3D holding PostA and PostB | action bridge; the pair's flag is `tied_<instance name>` |
| cursed_ground.tscn | CursedGround | |
| checkpoint.tscn | Checkpoint | |
| level_exit.tscn | LevelExit | with Pell's raft |
| deep_water.tscn | DeepWater | 6 by 6, surface drawn |
| pickup.tscn | Pickup | a paper leaf with a vermilion mark |
| rising_hazard.tscn | RisingHazard | 6 by 6, rises 2 m at 0.3 m/s once entered |

Several kit nodes can share a name in different holders (two tie_posts.tscn instances both
have a PostA). Refer to them by path from the level root, for example `"Bridge/PostA"`, in the
autoplay route and in `Level.node()`.

**Changing the nodes inside an instance needs an `[editable]` line.** Setting properties on
PostA inside a tie_posts.tscn instance (its transform, action, pull_target...), or the Spawn
markers inside a sealed_fight.tscn or cursed_zone.tscn, or adding a node below one of them,
works on desktop but is silently dropped by the web export unless the scene has
`[editable path="<instance path>"]` (what the editor writes for Editable Children; Godot
#123172). A new node straight under the instance root is kept either way. Scenes written by
hand or by a script usually lack the line. `tools/game/check_scenes.sh` lists every scene
that needs one, and `tools/game/check_scenes.sh --fix` adds them. Example: `BoulderTie` in
the example level, a pull pair with overridden children and an extra marker (stage
`boulder_aside`).

## 9. Beads, ink and progress

Finishing a level for the first time adds its registry bead to Orimi's cord, raises maximum ink
by 20 (base 100) and saves progress (`user://progress.json`; in the browser also localStorage,
written before the save returns). The beads show on Orimi's cord, in the HUD, on the pause
screen and on the title. Progress also keeps the control prompts already shown (each once per
save) and each level's time, ink-spawn undone and falls. Pell's raft (the `raft` data) carries
Orimi to the next level.

The title's first button names its level ("Continue: Sedge Plain"); Chapters lists every level
with its chapter, its bead once earned, and the locked ones greyed. Once the whole book is
finished it reads "Book One complete: Chapters" over the first level shown restored.

The end card shows after the last level (and after a dev level played with `level=`): the
level's `end_text`, or its name, chapter and bead without one. The card grows with its text
(and the text shrinks from 22 to 16 points if it must), so four paragraphs fit at 1280x720.
The numbers are the whole book's once every level is finished, otherwise this level's, and are
labelled so. The "more of the book" footer shows only for a book level with no `end_text`
while the book is unfinished.

Boot options for testing: `level=<id>` (straight into a level; with `autoplay=1` only that level),
`warp=<marker>`, `fresh=1` (forget progress), `god=1`, `completed=<id>,<id>` (a save that has
finished those levels), `end_card=1` (with `level=` and `autoplay=1`: straight to the level's
end card), `beads_check=1` (with `level=` and `autoplay=1`: shots of the beads in the HUD, on
the cord and on the pause screen), `fight_shots=1` (with `autoplay=1`: a stage `<fight>_ring` as
each sealed fight starts, where the route names no `start_stage`).

## 10. The autoplay route

`autoplay=1` plays the book; with `level=<id>` it plays just that level, from arrival to completion, through
the real systems (Orimi steered by AI inputs, real swipes, glyphs drawn as strokes through the
brush). Each level supplies `autoplay.route`, a list of steps run in order, and optionally
`autoplay.chain`, an ordered list of points (markers, node names or [x, y, z]) the walker follows
between places, needed when straight lines would hit walls or cliffs.

A point is a marker name, a node name, or [x, y, z].

| Step | Does |
| - | - |
| {"go": point, "before": m, "from": point, "required": true} | Walk there (stop m metres short, on the side facing "from"). |
| {"talk": "Person"} | Walk up and talk; waits for the panel to close. |
| {"cast": glyph, "target": "Node", "before": m, "flag": f, "attempts": 4, "after": 0.6} | Draw a glyph over the target until "flag" is set (or the target is cleared). "until": "cutscene" waits for a cutscene instead. |
| {"tie": ["PostA", "PostB"], "flag": f} | A Tie between two posts. |
| {"fight": "Zone or Fight", "finish": true} | Fight until clear (touching a knot first); "finish" requires one finishing stroke. |
| {"bloom_zone": "Zone"} | Bloom a zone's sapling and wait for the restore. |
| {"wait_flag": f, "timeout": 20} | Wait for a flag. |
| {"expect_flag": f} | Fail if the flag is not set. |
| {"wait": s} | Wait. |
| {"stage": "name"} | A QA stage line and, in the browser run, a screenshot. |
| {"probe_cursed": "Ground", "toward": point} | Walk off the safe ground; fail unless it hurts and pushes back. |
| {"probe_rising": "Hazard", "toward": point} | Walk into a risen hazard; fail unless she is lifted out above its surface or out of its box. |
| {"probe_water": "Water", "toward": point, "hold": s} | Walk into deep water; fail unless she is put back on the bank within 3 m of where she went in, unhurt. "hold": keep pushing in for s seconds after and fail if she loops. |
| {"death_test": true} | Die and check the respawn at the checkpoint. |
| {"expect_prompt": id, "timeout": 3} | Fail unless the prompt `id` (a level hint or a kit node's) shows within the timeout. |
| {"expect_bark": key, "timeout": 3} | Fail unless a bark (a Person's or level narration) is on the panel within the timeout. |
| {"expect_calm": "Enemy"} | Fail if that enemy is hunting Orimi (outside its territory). |
| {"cast_blocked": glyph, "target": "Node", "flag": f} | One stroke over a target behind a wall; fail if it answers (f gets set). |
| {"expect_height": "Node", "y": y} | Fail unless the node stands within 0.3 m of height y (set down on the floor, not the roof). |
| {"expect_above": y} | Fail unless Orimi is above height y. |
