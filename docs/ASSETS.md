# Assets and audio

Every model, painted texture, sound effect and music track in this project is generated from
scripts in this repository. Nothing is hand-edited after generation, nothing comes from a sample
library or asset store, and all of it is original work made for this game. Re-running the scripts
reproduces the files: models, textures and plots come out byte-identical, and the OGG files decode
to identical samples (only the random Ogg stream serial in the header changes).

## Regenerate

```
tools/assets/gen_all.sh        # everything below, in order, then the triangle report
tools/check.sh scene=res://scenes/dev/assets_demo.tscn
```

| Step | Command | Writes |
| - | - | - |
| Models and painted textures | `tools/assets/gen_models.sh [model ...]` (Blender headless, then the venv painter) | `assets/characters/*.glb`, `assets/props/*.glb`, `assets/environment/*.glb`, `assets/textures/painted/*.png` |
| Sound effects, music, level reports, plots | `tools/assets/gen_audio.sh` | `audio/sfx/*.ogg`, `audio/music/*.ogg`, `docs/assets/audio/*` |
| Godot import settings | `tools/assets/import_assets.sh` (import, `godot_import.py`, re-import, `godot_import.py --check`) | `*.import`, external materials `assets/*/materials/m_*.tres` |
| Demo scene | `python tools/assets/make_demo.py` | `scenes/dev/assets_demo.tscn` (embeds `tools/assets/assets_demo.gd`) |
| Provenance manifests | `python tools/assets/write_provenance.py` (run by gen_models.sh and gen_audio.sh) | `provenance.json` in each asset folder: path, sha256, generator, command (checked by `tools/qa/qa.sh provenance`) |
| Triangle report | `python tools/assets/tri_count.py [--markdown]` | stdout; fails above 5,000 per model |

Model names for `gen_models.sh`: fox, splotchet, reedwraith, sapling, great_tree, thorn_gate,
shrine, stepping_stone, rocks, reeds, raft, terrain (terrain also writes `river_surface.glb`).

### Where things live

- `tools/blender/inklib.py`: shared Blender helpers (loft, tube, cone, ico, vertex colours,
  `chain_taper` for outline taper, UV atlas, paint-map dump, stepped NLA export).
- `tools/blender/make_fox.py`, `make_splotchet.py`, `make_reedwraith.py`, `props.py` with
  `make_<prop>.py`, `valley_layout.py` (markers, river, path, height field), `make_terrain.py`.
- `tools/textures/painted/inkpaint.py` (washes, blotches, strokes), `paint_models.py` (one recipe
  per model), `paint_terrain.py`.
- `tools/audio/synth.py` (plucked string, flute, bell, pad, drums, wood, reverb, OGG writer),
  `sfx.py`, `music.py`, `plots.py`.
- `scenes/models/<name>.tscn`: the wrappers gameplay loads. Each instances the glTF and adds an
  `InkLook`; animated ones expose `%AnimationPlayer`.
- `scripts/audio/audio_director.gd`: the `Audio` autoload.

## Conventions

- Rigid parts, no skinning. Animations are 12 fps stepped keys (glTF STEP), one NLA track per clip.
- Vertex colour R is outline weight, G wind sway, B dry-brush tendency (see CONTRACTS.md). Outline
  weight runs along each limb as a brush stroke: thick at the root, thin at the tip
  (`inklib.chain_taper`), so ears, legs, tail, trunks, branches, thorns and reeds taper.
- Materials whose names end in `_sacred` keep their colour in cursed zones.
- Orimi, the Splotchet and the Reedwraith use `line_style = &"character"` and `cursable = false`.
- Hidden parts sit at scale 0.01, not 0, because a zero basis makes Godot log quaternion
  errors. Parts that grow in later (canopy, blossoms) are also parked 1.5 m below the ground while
  hidden, because the outline keeps a screen-space width and would draw them as black dots.
- Orimi is shaped for the camera behind and above: broad chest and haunches, ears splayed so
  they show from behind, a folded plume tail that rises and sweeps to the right of the body, and
  the vermilion cord knotted on the nape with trailing ends and the gold bead on the knot.
- Colliders are glTF `-col`, `-convcol` or `-convcolonly` pieces; the terrain ground is one
  `Terrain-col` mesh that Godot turns into a `StaticBody3D` on layer 1 with a concave shape.
- The terrain height field is built on a 1.2 m grid (23,562 triangles) and decimated to 4,350 so
  the whole model, ridges included, is under 5,000. The generator prints the height error
  against the field: mean 0.08 m, 95th percentile 0.29 m, worst 3.4 m on cliff faces; every
  route marker is within 0.1 m.
- Textures import as lossy WebP with mipmaps; no LODs and no shadow meshes.

## Models

| Model | Triangles | Largest piece | Mesh nodes | Vertex colours | Materials | Animations |
| - | - | - | - | - | - | - |
| assets/characters/folk/folk_dyer.glb | 588 | 160 | 8 | yes | M_folk_folk_dyer | idle (2.00s STEP), talk (1.33s STEP), walk (0.67s STEP), faded (1.00s STEP) |
| assets/characters/folk/folk_lampmaker.glb | 544 | 148 | 8 | yes | M_folk_folk_lampmaker | idle (2.00s STEP), talk (1.33s STEP), walk (0.67s STEP), faded (1.00s STEP) |
| assets/characters/folk/folk_mapmaker.glb | 552 | 148 | 8 | yes | M_folk_folk_mapmaker | idle (2.00s STEP), talk (1.33s STEP), walk (0.67s STEP), faded (1.00s STEP) |
| assets/characters/folk/pell.glb | 502 | 148 | 8 | yes | M_folk_pell | idle (2.00s STEP), talk (1.33s STEP), walk (0.67s STEP), faded (1.00s STEP) |
| assets/characters/fox.glb | 552 | 196 | 14 | yes | M_bead_sacred, M_cord_sacred, M_fox | idle (2.00s STEP), run (0.67s STEP), jump (0.50s STEP), fall (0.33s STEP), land (0.50s STEP), attack_1 (0.67s STEP), attack_2 (0.83s STEP), hurt (0.50s STEP), brush_pose (1.00s STEP) |
| assets/characters/reedwraith.glb | 984 | 300 | 6 | yes | M_reedwraith, M_reedwraith_veil | idle (2.00s STEP), drift (1.00s STEP), attack (1.33s STEP), hurt (0.50s STEP), unravel (1.50s STEP), veil_off (1.00s STEP) |
| assets/characters/splotchet.glb | 572 | 320 | 8 | yes | M_splotchet | idle (1.00s STEP), hop (0.67s STEP), attack (1.00s STEP), hurt (0.50s STEP), unravel (1.50s STEP) |
| assets/environment/river_surface.glb | 258 | 258 | 1 | yes | M_river | none |
| assets/environment/valley_terrain.glb | 4782 | 4350 | 4 | yes | M_ridges, M_terrain, M_walls | none |
| assets/props/great_tree.glb | 4188 | 1432 | 16 | yes | M_great_tree, M_tree_cord_sacred | withered (1.00s STEP), bloom (3.00s STEP) |
| assets/props/raft.glb | 572 | 308 | 6 | yes | M_raft | bob (2.00s STEP) |
| assets/props/reeds.glb | 280 | 256 | 2 | yes | M_reeds | none |
| assets/props/rocks.glb | 240 | 80 | 3 | yes | M_rocks | none |
| assets/props/sapling.glb | 536 | 300 | 8 | yes | M_sapling, M_sapling_cord_sacred | withered (1.00s STEP), bloom (2.00s STEP) |
| assets/props/shrine.glb | 248 | 72 | 6 | yes | M_shrine, M_shrine_gold_sacred, M_shrine_posts_sacred | none |
| assets/props/stepping_stone.glb | 62 | 62 | 1 | yes | M_stepping_stone | none |
| assets/props/thorn_gate.glb | 1356 | 1356 | 1 | yes | M_thorn_gate | none |

Extra markers in `valley_terrain` beyond the contract: `M_Stone_1` to `M_Stone_5` (stepping
stone positions across the river at `M_Crossing`, perpendicular to the flow, stone top at y = 0)
and `M_Shrine` (-3.2, 0.04, 55). The river surface is its own model,
`scenes/models/river_surface.tscn`, with the water at y = -0.35 and the bed at -1.8.

Ways up and down in Level 1 (`tools/blender/valley_layout.py`): RAMP1 (the gate B ramp, 0 to 3 m),
RAMP2 (terrace to Camphor Rise, 3 to 6 m) and RAMP3 (the way back up the Rise's west flank, from
the lowland at (-9, -22) to (-11, -37), 0 to 6 m, about 22 degrees, with a flared foot so it can be
entered from the side). West of RAMP1 the ground that stood above the ramp is cut down to it and
a round shore bank rises onto the ramp at t = 0.36, short of the soot bank at `M_GateB` (t = 0.5),
so a player on the shore can climb back below the gate but cannot walk round it. Above the gate
the drop to the shore stays steep on purpose. RAMP3 does let a player reach the Rise from the
lowland without passing gate B, which is what the "way back up" asks for; gameplay decides whether
the tree's wave needs zone B restored first.

Walkability probe: `"$GODOT" --headless --path . -- scene=res://scenes/dev/assets_terrain_probe.tscn`
ray-casts the imported terrain collision along each route and fails if any floor is steeper than
the player's 48 degrees (`ORIMI_TERRAIN_PROBE PASS`). Last run: rise_west_ramp 22.4,
west_strip_to_ramp_foot 27.8, gate_b_shore_bank 46.1, gate_b_ramp 42.0, terrace_ramp_to_rise 26.2.

**Enemies, second pass.** Both are judged from the gameplay camera with the demo's
`view=enemies` (57 degrees, 4.9 m behind Orimi at -16 degrees; near row idle, windup and unravel,
then idle at 15 m and attack at 30 m; `curse=1` for cursed ground).

- Splotchet (572 tris): 0.8 m across and 0.75 m to the tips of a splash crown that breaks the
  round silhouette and bristles on the windup; slanted thumbprint eyes with ink pupils show
  where it looks; the blot is painted with broad sheen strokes and dry highlights, not a flat
  fill. `attack` (1.0 s): frames 0 to 6 are the windup (crouch, eyes narrow, crown bristles,
  a two-frame quiver), matching gameplay's 0.55 s WINDUP, then the lunge from frame 7.
- Reedwraith (984 tris): a dark hood in the reeds above the veil with two pale split-seed eyes,
  and two long whip reeds that read as arms at range. `attack` (1.33 s): frames 0 to 10 are the
  windup (it rears back, the reeds spread, the eyes flare), matching gameplay's 0.9 s, then the
  lash on frames 11 and 12.
- Both have `unravel` (1.5 s, 18 frames, not looping, holds its last frame), for the finishing
  stroke window: the Splotchet loses its shape and spreads into a puddle with its eyes sliding
  down; the Reedwraith comes undone, its reeds splaying and drooping as it sinks. Gameplay's
  `EnemyBase._unravel` currently plays `hurt` plus a wobble; it should play `unravel` (the
  stepped animator ignores names a model lacks, so the call is safe for every enemy).
- Animation names are unchanged: idle, hop, attack, hurt (Splotchet); idle, drift, attack, hurt,
  veil_off (Reedwraith); plus unravel on both.

Captures (browser, 960x540 JPEG): `enemies_before_clean_web.jpg`, `enemies_before_cursed_web.jpg`,
`enemies_after_clean_web.jpg`, `enemies_after_cursed_web.jpg`, `reedwraith_face_web.jpg`,
`splotchet_windup_web.jpg`.

**Raft** (`scenes/models/raft.tscn`): Pell's pole raft for arrivals and departures in every level.
Seven lashed logs, two battens, a stern post with a paper lantern; 2.8 m long, 1.5 m wide. The
origin is at the waterline (put it at the water height), the bow points along -Z, and the deck
top is at y = 0.17, where Pell and Orimi stand. `bob` (2 s, stepped) autoplays on the wrapper and
moves only the deck; `RaftCollider` is a static convex box under the deck, so a moving raft needs
the level to move the whole wrapper (or replace the collider with its own AnimatableBody3D). Pell
carries the pole (the folk `pole` prop); the raft has none of its own.

## Folk

Paper people for every level, in Orimi's folded-paper language: rigid folded segments with
crease lines, no faces beyond a nose fold, one painted atlas each. A level describes its cast in a
JSON spec and runs one command; it never models people by hand.

### Make a cast

1. Write a spec, for example `tools/levels/tallowford/folk.json`:

   ```json
   {
    "models": "assets/levels/tallowford/folk",
    "textures": "assets/levels/tallowford/folk",
    "scenes": "scenes/levels/tallowford/folk",
    "people": {
     "old_wick": {"size": "elder", "build": "slim", "garment": "robe", "hat": "cap", "prop": "lantern", "palette": "ochre", "seed": 4},
     "marrow": {"size": "adult", "build": "stout", "garment": "apron", "hat": "scarf", "prop": "bucket", "palette": "madder", "colours": {"hat": "#4a5d7a"}},
     "bean": {"size": "child", "garment": "tunic", "prop": "basket", "palette": "persimmon"}
    }
   }
   ```

2. Generate, import and check:

   ```
   tools/assets/gen_folk.sh tools/levels/tallowford/folk.json        # or: ... folk.json marrow
   tools/assets/import_assets.sh
   tools/check.sh
   ```

3. Look at the cast under the real materials, woken in front and faded behind:
   `tools/screenshot_desktop.sh out.png scene=res://scenes/dev/assets_demo.tscn view=folk folk_dir=res://scenes/levels/tallowford/folk dist=3.4 shot_after=3`
   (add `folk_anim=talk` or `walk` for the front row, `wake_after=1` to wake the back row).

Each person gives `<models>/<name>.glb`, `<textures>/<name>.png` and `<name>_faded.png`
(512 px), a wrapper `<scenes>/<name>.tscn`, an entry in `<models>/godot_import.json` (which
`tools/assets/godot_import.py` reads for materials, loops and texture settings) and entries in
the `provenance.json` of the model and texture folders. A person is about 500 to 600 triangles.

### Parameters

| Key | Values | Default |
| - | - | - |
| size | adult (1.66 m), elder (1.54 m, stooped), child (1.06 m) | adult |
| build | slim, average, stout | average |
| garment | robe (to the ankles), tunic (to mid-thigh, trousers), apron (tunic and a front apron) | tunic |
| hat | none, paper_boat, wide_brim, scarf, cap | none |
| prop | none, lantern, pole, bucket, basket, scroll (held in the right hand) | none |
| palette | indigo, madder, ochre, moss, ash, persimmon | indigo |
| colours | overrides by part: garment, trim (sash, apron), legs, hat, prop, skin, hair, shoe, lamp | {} |
| seed | brush-stroke variation in the painted atlas | 1 |

Palettes and sizes live in `tools/blender/folk_style.py`; the model in
`tools/blender/make_folk.py`; the painter in `tools/textures/painted/paint_folk.py`.

### In the game

The wrapper root is a `FolkPerson` (`scenes/models/folk/folk_person.gd`) with an `InkLook`
child (`line_style = &"character"`, `cursable = false`) and `%AnimationPlayer`.

- `person.faded = true` (also settable in the inspector): drained grey paper, holding the still
  `faded` pose. `person.wake()`: colour returns in one step with a warm flash, the idle loop
  starts and the `woke` signal fires. `person.faded = false` switches without the flash.
- How the switch works with `InkLook`: `InkLook` has no per-object colour drain (its curse
  response is positional, driven by `CurseField` zones), so folk carry two atlases and
  `FolkPerson` swaps `albedo_tex` on its own `InkLook` materials. It first calls
  `InkLook.set_dissolve(0.0)`, which gives this person private copies of the shared materials,
  so waking one villager never repaints another. `cursable` is off so a cursed zone does not
  drain a woken villager a second time; set it on in a level that wants zone draining instead.
- Animations, stepped at 12 fps and all looping: `idle` (2 s), `talk` (1.33 s, nods and a
  raised right hand), `walk` (0.67 s), `faded` (a still, bowed pose). Play only `faded` while a
  person is faded.
- Pell is `scenes/models/folk/pell.tscn` (a child in an indigo tunic, a folded paper-boat hat
  and a ferry pole). The examples `folk_lampmaker`, `folk_dyer` and `folk_mapmaker` show the
  range; their spec is `tools/assets/folk_cast.json`.

## Painted textures

| Texture | Size | Bytes |
| - | - | - |
| fox.png | 1024x1024 | 310723 |
| great_tree.png | 1024x1024 | 430669 |
| reeds.png | 512x512 | 73305 |
| reedwraith.png | 1024x1024 | 310842 |
| rocks.png | 512x512 | 116666 |
| sapling.png | 512x512 | 140067 |
| shrine.png | 512x512 | 110820 |
| splotchet.png | 1024x1024 | 158424 |
| stepping_stone.png | 512x512 | 76124 |
| terrain.png | 1024x2048 | 1307129 |
| terrain_walls.png | 1024x1024 | 296419 |
| thorn_gate.png | 512x512 | 40648 |

## Audio

All sounds are synthesised in Python (no recordings, no samples), mono for effects and stereo for
music, OGG Vorbis at quality 0.75. Levels are measured from the decoded files. Loop-step ratio is
the sample jump across the loop seam divided by the typical sample-to-sample step; under 1 means
the seam is no louder than ordinary signal. Plots: `docs/assets/audio/music_*.png` and
`sfx_overview.png`; full figures in `docs/assets/audio/sfx_levels.json` and `music_levels.json`.

| Music | Seconds | Loops | Peak dBFS | RMS dBFS | Bytes | Loop-step ratio (decoded) |
| - | - | - | - | - | - | - |
| title | 58.18 | yes | -1.1 | -16.1 | 657025 | 0.28 |
| vale_cursed | 66.21 | yes | -1.2 | -17.2 | 716130 | 0.13 |
| vale_restored | 53.33 | yes | -0.9 | -15.0 | 605992 | 0.05 |
| finale | 62.84 | no | -1.3 | -16.7 | 660695 | - |

| Sound | Seconds | Peak dBFS | RMS dBFS | Bytes |
| - | - | - | - | - |
| footstep | 0.16 | -9.0 | -26.8 | 5834 |
| jump | 0.32 | -5.6 | -18.9 | 7344 |
| land | 0.30 | -6.5 | -22.8 | 7790 |
| swipe | 0.30 | -4.8 | -17.0 | 6527 |
| hit | 0.45 | -3.1 | -21.8 | 6780 |
| hurt | 0.50 | -4.3 | -25.1 | 10882 |
| splotchet_hop | 0.18 | -8.1 | -20.5 | 4640 |
| splotchet_die | 0.80 | -3.6 | -21.2 | 10887 |
| reedwraith_moan | 1.80 | -6.0 | -22.1 | 14460 |
| reedwraith_die | 1.40 | -3.2 | -23.8 | 13946 |
| veil_off | 1.00 | -4.5 | -25.8 | 15936 |
| brush_open | 1.10 | -5.2 | -19.9 | 10814 |
| brush_close | 0.90 | -5.9 | -23.1 | 8605 |
| brush_stroke | 0.55 | -9.4 | -24.9 | 8642 |
| glyph_ok | 1.50 | -3.9 | -18.8 | 12839 |
| glyph_fail | 0.60 | -5.3 | -25.3 | 7712 |
| bloom | 1.80 | -3.3 | -20.2 | 17034 |
| slash | 0.42 | -3.6 | -21.3 | 7466 |
| gust | 1.30 | -3.5 | -23.2 | 13597 |
| thorns_cut | 0.80 | -3.3 | -21.6 | 12452 |
| soot_clear | 1.60 | -3.2 | -18.0 | 24259 |
| zone_restore | 3.40 | -2.0 | -17.6 | 24490 |
| petals | 1.40 | -6.2 | -20.5 | 17308 |
| tree_restore | 5.50 | -1.4 | -14.2 | 32337 |
| ink_pickup | 0.50 | -5.9 | -23.4 | 5995 |
| ui_move | 0.09 | -10.4 | -23.2 | 4291 |
| ui_accept | 0.60 | -6.2 | -25.2 | 6399 |
| kindle | 1.50 | -4.4 | -23.3 | 16828 |
| tie | 1.30 | -4.1 | -22.1 | 13431 |
| verse_wake | 2.80 | -2.9 | -15.4 | 23997 |
| talk_open | 0.45 | -7.9 | -27.6 | 8241 |
| talk_next | 0.12 | -14.0 | -28.4 | 4563 |
| pickup | 0.90 | -5.7 | -23.1 | 9928 |
| bead | 2.60 | -2.1 | -16.4 | 23511 |
| splash | 1.10 | -4.2 | -21.0 | 12038 |
| curse_throwback | 1.00 | -4.1 | -20.2 | 10742 |
| fight_seal | 2.20 | -3.0 | -17.0 | 14495 |
| fight_won | 2.60 | -2.9 | -18.4 | 19389 |
| unravel | 1.55 | -3.6 | -19.9 | 23660 |
| clean_cut | 0.90 | -2.2 | -23.1 | 9800 |
| raft | 1.90 | -4.8 | -26.6 | 18404 |
| lamp_hum | 2.00 (loop) | -12.0 | -23.4 | 16395 |

Totals: sound effects 531 KB (the level-kit sounds from kindle on add 220 KB), music 2578 KB.

### Who plays which sound

The director (scripts/audio/audio_director.gd) plays every sound it can see a signal for. Gameplay
must not also play these, or they double:

| Sound | Played by the director on |
| - | - |
| kindle | `KindleTarget.kindled`, at the target |
| tie | `TiePost.tied_up`, once per pair, between the posts |
| verse_wake | a `VerseStone` starting to read (`reading` turning true) |
| fight_seal, fight_won | `SealedFight.fight_started`, `fight_won`, at the fight |
| unravel | `Events.enemy_hit` that leaves the enemy at `hp <= 0` (the start of the 1.5 s unravel) |
| clean_cut | `Game.enemy_finished(enemy)`, at the enemy |
| talk_open | `Events.game_state_changed(&"talk")` |
| bead | `Events.bead_awarded(level_id, color)` |
| splash, curse_throwback | `Events.player_thrown_back(at, cause)`: cause `&"water"` splashes, any other is the curse |
| lamp_hum | looped while a lit `KindleTarget` of kind lamp or brazier is within 9 m (one voice for all lamps) |

Kit nodes are hooked by group when `Game.level_loaded` fires; a level that adds kit nodes later
calls `Audio.hook_kit()`. The two `Events` signals are connected only when they exist.

Gameplay plays these itself, with `Audio.play_sfx(id, at)`: footstep, jump, land, ui_move and
ui_accept as before; `talk_next` for each new line on the talk panel (instead of ui_move);
`pickup` from `Pickup` (its `sfx` default); `raft` when Pell's raft pushes off.

### Audio autoload

Contract members: `play_sfx(id, at, volume_db)`, `play_music(id, fade)`, `set_brush_duck(on)`.
Added: `current_music` (the id playing, or `&""`), `MUSIC_IDS`, `SFX_IDS`, `LOOP_SFX` (built-in
sounds that loop: lamp_hum, played by the director only), `is_ducked()`, `is_humming()`,
`hook_kit()`, and the level registration calls below (`register_music`, `register_sfx`,
`has_music`, `has_sfx`, `set_level_music`).
Web-safe by design: no bus effects or reverb at runtime (reverb is baked), no reliance on playback
position, and positional sounds are attenuated by distance in script (5 m to 45 m).
Headless self-test: `"$GODOT" --headless --path . -- scene=res://scenes/dev/assets_audio_test.tscn`
prints `ORIMI_AUDIO_TEST PASS`. It also covers the level registration below and the kit hooks
(fake kit nodes in the kit's groups). In the browser: `tools/export_web.sh`, then `tools/smoke_web.sh --hold 8
scene=res://scenes/dev/assets_audio_test.tscn` (passes, 98 checks; the four refusal checks that
print warnings on purpose run on desktop only, and the scene does not quit on the web).

### Level music and sounds

A level keeps its own tracks and sounds under `audio/levels/<id>/` and registers them from its
level script when the level loads. Built-in ids cannot be replaced; registering a level id again
(the level reloading) replaces it, so there is nothing to unregister.

```gdscript
const AUDIO_DIR := "res://audio/levels/tallowford/"

func _ready() -> void:
	Audio.register_music(&"tallowford_cursed", AUDIO_DIR + "tallowford_cursed.ogg")
	Audio.register_music(&"tallowford_restored", AUDIO_DIR + "tallowford_restored.ogg")
	Audio.register_sfx(&"tallowford_lamp", AUDIO_DIR + "lamp.ogg", -2.0, 0.05)
	Audio.set_level_music(&"tallowford_cursed", &"tallowford_restored", false)

func _exit_tree() -> void:
	Audio.set_level_music(&"")
```

- `register_music(id, source, loop = true) -> bool`: `source` is a `res://` path or an
  `AudioStream`. The loop flag is set on a private copy of the stream, so the file's import
  settings do not matter (level OGGs import with loop off, and that is fine). Use OGG Vorbis.
- `register_sfx(id, source, trim_db = 0.0, pitch_spread = 0.0) -> bool`: a one-shot sound (a
  looping file is played once), with a trim in dB and a random pitch spread (0.05 is plus or
  minus 5 %). Play it with `Audio.play_sfx(id, at)` like any other sound.
- `has_music(id)`, `has_sfx(id)`. Both register calls return false with a warning when the path
  does not load or the id is built in.
- `set_level_music(cursed, restored = &"", already_restored = false)`: while the game is playing,
  the director plays the level's cursed track, switches to the restored one while Orimi stands
  in a restored zone, and keeps it for good after `valley_restored`, exactly as it does with the
  vale tracks. `restored = &""` keeps one track throughout; `already_restored = true` starts
  restored (re-entering a finished level). `set_level_music(&"")` and the title screen return to
  the vale tracks. Unregistered ids are refused with a warning. A level can still call
  `play_music(id)` directly for a scripted moment (a sealed fight); the director takes over again
  at the next zone or state change.

Name ids `<level id>_<name>` so levels never collide. A 60 s stereo track is about 650 KB.

### Composing a level theme

The four tracks share one theme; a level's pair should sound like part of the same score. Start
from `tools/audio/level_theme_example.py`, copy it to `tools/levels/<id>/music_<id>.py` (it finds
`tools/audio` from any folder in the project) and change it, then render into the level's folder:

```
../../.tools/venv/Scripts/python.exe -I -B tools/levels/<id>/music_<id>.py audio/levels/<id>
```

It imports the score kit from `tools/audio/music.py` (`Score`, `arp`, `pads`, `THEME`,
`CHORDS_BRIGHT`, `CHORDS_DARK`, `drain`, `write_piece`); `Score` plays the instruments in
`tools/audio/synth.py` (pluck, flute, pad, bell, drum, wood, shaker). What keeps it related:

1. The same instruments, baked reverb and loudness: render with `Score` and write with
   `write_piece`, which normalises to -1 dBFS, writes OGG at the shared quality and prints the
   measured levels and the loop-seam ratio (keep it under 1). The example pair measures -17.2 and
   -16.2 dBFS RMS against the vale's -17.2 and -15.0.
2. The theme's opening figure (THEME bars 1 and 2, A B D B A F# E) as the level's first phrase,
   moved to the level's key, then an answer of the level's own.
3. The same cursed/restored relation as the vale pair: the cursed track is the restored one
   drained with `drain()` (the bright degrees a semitone down), slower (about 60 against 72 to
   76 bpm), every fourth note dropped, muted low strings and a heartbeat drum.
4. One signature colour per level (the example uses a bell lead and an off-beat wood click), so
   it is a sibling and not a copy. 16 bars of 4/4 gives loops of 50 to 65 s, like the vale.

All note data must be original: no melody, harmony or rhythm taken from anywhere else. Render
looping tracks with `render(loop=True)`, which wraps the ringing tail onto the start so the
seam is continuous.

### The level themes (levels 2 to 5)

`tools/audio/level_music.py` renders the five levels' music into `audio/levels/<id>/` (run by
`tools/assets/gen_audio.sh`; one file per piece, `PIECES` at the bottom). Every track loops
whole: the loop runs from 0 to the end of the file (`register_music` sets loop on with offset 0),
and the ringing tail is already wrapped onto the start. The vale tracks render bit-exactly as
before (the score kit only gained a `wind` voice: band-swept pink noise with a swell).

| Id | Level folder | Seconds | Peak dBFS | RMS dBFS | Bytes | Loop-step ratio (decoded) |
| - | - | - | - | - | - | - |
| tallowford_cursed | tallowford | 64.00 | -1.0 | -16.7 | 669467 | 0.13 |
| tallowford_restored | tallowford | 58.18 | -0.8 | -14.8 | 639353 | 0.04 |
| sedge_plain_cursed | sedge_plain | 53.33 | -1.3 | -16.5 | 568337 | 0.11 |
| sedge_plain_restored | sedge_plain | 43.64 | -1.1 | -14.5 | 492210 | 0.12 |
| mosswater_cursed | mosswater | 64.00 | -1.2 | -17.2 | 644794 | 0.34 |
| mosswater_restored | mosswater | 58.18 | -1.1 | -14.5 | 620742 | 0.09 |
| hollow_kiln_cursed | hollow_kiln | 57.14 | -1.3 | -16.9 | 620281 | 0.10 |
| hollow_kiln_restored | hollow_kiln | 54.86 | -0.9 | -14.9 | 629659 | 0.01 |
| hollow_kiln_dregs | hollow_kiln | 46.15 | -1.4 | -15.7 | 535159 | 0.07 |

Total 5.42 MB (5,420,002 bytes); with the level-kit sounds above the addition to the build is
5.64 MB. Full figures in `docs/assets/audio/level_music_levels.json`.

What each is, all built on the vale theme's opening figure in the level's key, then an answer of
the level's own, with the cursed track derived from the restored one (drained, slower, notes
dropped, muted strings, a heartbeat drum):

- **Tallowford** (A major, 66 bpm; cursed 60): dusk and lamps. A slow quarter-note lute under a
  low flute, a soft lamp bell at the end of every other bar, warm pads.
- **Sedge Plain** (E major, 88 bpm; cursed 72): open and walking. Drums on the walking beats, a
  shaker and an off-beat wood click, open fifths instead of full chords, gusts of wind across the
  stereo field.
- **Mosswater Wood** (G major, low, 66 bpm; cursed 60): dark and close. Low dull plucks doubling
  the flute, a shorter room, drips of high bell scattered through it; the cursed drips are fewer
  and drained.
- **The Hollow Kiln** (C, low): the cursed track is the vale theme itself (bars 1 to 8) bent out
  of shape: stretched into 5/4 with the third and fourth beats pushed late, drained, the fifth
  flattened to a tritone in every other bar and every fourth chord root slid down a semitone, in
  a 4 s hollow reverb (84 bpm). The restored track is the same theme put straight again, whole
  and in 4/4, low and warm (70 bpm).
- **The Dregs** (`hollow_kiln_dregs`, 104 bpm, 20 bars): the boss fight. A driving dark arp,
  a doubled heartbeat drum and ticking wood under the opening figure drained and broken off,
  a falling line in the middle (it is not cruel, it only keeps), the opening once more low and
  whole, then a climb back to the start. Play it with `Audio.play_music(&"hollow_kiln_dregs")`
  on `SealedFight.fight_started`; the director goes back to the level pair at the next zone or
  state change, or call `set_level_music` again after `fight_won`.

A level registers its own, for example in Tallowford:

```gdscript
const AUDIO_DIR := "res://audio/levels/tallowford/"
Audio.register_music(&"tallowford_cursed", AUDIO_DIR + "tallowford_cursed.ogg")
Audio.register_music(&"tallowford_restored", AUDIO_DIR + "tallowford_restored.ogg")
Audio.set_level_music(&"tallowford_cursed", &"tallowford_restored")
```

## Demo

`scenes/dev/assets_demo.tscn`. Boot options: `view=row|terrain|closeup`, `model=<name>`,
`anim=<name>`, `yaw=`, `dist=`, `terrain_cam=persp` (with `cam=x,y,z look=x,y,z`), `audio_tour=1`. Keys: Left/Right to pick a
sound and Enter or Space to play it, M next music, N music off, B duck, T terrain, 1 to 9 close-ups.

## Evidence

Gameplay-camera captures (`warp=<marker> god=1 shot_after=7`), JPEG, under `docs/assets/play/`:
`before_desktop_<marker>.jpg` (before the second pass), `after_desktop_<marker>.jpg` (Forward+) and
`after_web_<marker>.jpg` (browser, Compatibility) for M_Spawn, M_ZoneA, M_ZoneB and M_Tree, with
`web_console_summary.txt` (no console errors at any warp).

Model and terrain captures with the render workstream's InkLook: `fox_front.jpg`,
`fox_brush_pose.jpg`, `thorn_gate.jpg`, `shrine.jpg`,
`great_tree_withered_to_bloom.jpg` (withered, bloom at 0.5, 1.0, 1.5 and 3.0 s, and the withered
sapling), `terrain_clean_persp.jpg` (restored colours, no curse), `terrain_top_markers.jpg`.
The demo's `anim_at=<seconds>` option holds an animation at one time for such frame captures.
Browser logs from the first pass: `web_demo_row_console.txt` (the audio tour reaching `finale`
and `tour_done`) and `web_game_console.txt`.

Third pass, under the real materials (`view=folk`, woken row in front, faded row behind):
`folk_desktop.jpg` and `folk_web.jpg` (desktop Forward+ and browser), and
`folk_desktop_woken.jpg` and `folk_web_woken.jpg` (the same with `wake_after`, after `wake()` has
run on the faded row: every person back in colour). `raft.jpg` (close-up),
`terrain_rise_west_ramp.jpg` (the new ramp up Camphor Rise's west flank, from the lowland) and
`game_gate_b_bank.jpg` (gameplay camera at `warp=M_GateB`, the shore bank west of the ramp).
