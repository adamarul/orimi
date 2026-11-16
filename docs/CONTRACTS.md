# Contracts

What every workstream builds against. Read docs/BRIEF.md first for the goal and the
definition of done; this file is the how. The lead (OKAA-1) owns this file and every file
listed under "lead" below. If a contract is wrong or missing something you need, tell the
lead with the exact change; do not work around it and do not edit another owner's files.

**The visual target is docs/STYLE_GUIDE.md.** Render, vfx, brush, gameplay (interface) and
assets all build to it. Study captures are in `.reference/` at the top level, for looking at
only.

**Levels 2 to 5, the story, and the added mechanics are in docs/LEVELS.md.**

## The game

- Title: **Orimi: The Unfaded Vale**
- Orimi: a fox folded from shrine paper, woken by the river when the colour began to drain.
  Built from rigid folded-paper segments (it is paper, so it creases rather than bends).
  Warm ivory, fold creases for interior lines, ash-grey wash on ear tips and paws, one
  vermilion cord with a gold bead at the neck, no painted body markings.
- Hazewater Vale: a misty river valley. The river is the Lull.
- The Thousand-Ring Camphor: the great tree at the head of the valley; everything living in
  the vale takes its colour from it.
- The Spill: spilled ink that soaked into the vale and drank its colour. Cursed ground is
  black ink blots under red light.
- Splotchet: a small hopping blot with two pale thumbprint eyes. Swarms; dies to a tail swipe
  or a slash.
- Reedwraith: a tall, drifting bundle of ink-black reeds wrapped in a soot veil. Nothing hurts
  it while it is veiled; a gust strips the veil, then it can be cut.
- Thorn gate: a tangle of ink thorns across a path. A slash cuts it.
- Soot bank: a wall of hanging soot across a path. A gust blows it away.
- Withered sapling: one per cursed zone, tied with a vermilion cord. Bloom restores the zone,
  but only after the zone's enemies are gone.
- Glyphs: **Bloom** (a circle), **Slash** (a horizontal line), **Gust** (a loop).

All of these names are invented for this project. Invent further names in the same spirit
and check each against existing games before using it.

## The slice, start to finish

Coordinates are metres, Y up; the player travels from south (+Z) to north (-Z).
The terrain mesh carries marker nodes with these names; gameplay reads the markers and falls
back to these numbers while the terrain does not exist yet.

| Marker | Position (x, y, z) | What |
| - | - | - |
| M_Spawn | (0, 0, 50) | Riverside shrine. Clean ground, safe. Start and first respawn point. |
| M_GateA | (-4, 0, 36) | Thorn gate across the path. Teaches Slash. |
| M_ZoneA | (-12, 0, 20), radius 16 | Reed Shallows. Cursed. Splotchets. Sapling at the centre. Teaches Bloom. |
| M_Crossing | (0, 0, 8) | Stepping stones over the Lull. |
| M_GateB | (6, 1.5, 4) | Soot bank across the ramp. Teaches Gust. |
| M_ZoneB | (14, 3, -10), radius 16 | Soot Terrace, raised 3 m. Cursed. Reedwraiths and Splotchets. Sapling at the centre. |
| M_Tree | (0, 6, -42), radius 20 | Camphor Rise. The great tree. Final wave of both enemies, then Bloom on the tree. |

Valley walls rise beyond |x| = 30; the playable strip is roughly z from -65 to 60. The river
enters from the north-east, runs between the two zones, and leaves to the south.

Flow: title screen, a short intro card, spawn at the shrine with movement and camera prompts,
thorn gate (Slash), Reed Shallows (fight, Bloom), crossing, soot bank (Gust), Soot Terrace
(Gust then Slash on Reedwraiths, Bloom), Camphor Rise (final wave, Bloom on the tree),
restoration sequence with colour sweeping the whole valley, end card, back to title.

Rules: the player has 5 health. A tail swipe is the basic attack. Dying respawns at the
shrine or the last restored zone. Ink refills slowly on its own and from defeated enemies.
Each glyph is required at least once.

## Renderer rules

Forward+ on desktop, Compatibility in the browser, one shader codebase. docs/RENDERER_NOTES.md
(from phase 0) lists what was measured in each and what to use instead where something fails.
If it is not proven in the web build it is not done. The measured rules that shape everything:

- **Colour differs between the renderers.** Colours computed in a shader come out as written on
  web and sRGB-encoded (paler) on desktop; the 3D screen texture holds sRGB values on web and
  linear values on desktop. Tune on web. Put the renderer-gated conversions in one shared include,
  `shaders/render/ink_common.gdshaderinc` (render owns it; every other shader includes it rather
  than re-deriving them). A `Palette` colour must read back within 4/255 of itself in both builds.
- **Post chain shape.** One full-screen 3D pass for everything that needs depth, then canvas
  passes separated by BackBufferCopy nodes. A second 3D screen-reading pass cannot see the first.
- **Translucent things blend darker on web.** Tune alpha on web.
- **Not available on web:** Decal nodes (they draw nothing, silently) and the normal-roughness
  texture (gate it; reconstruct normals from depth).
- **Hull outlines crack on flat-shaded meshes.** Models are exported with smooth normals and the
  toon shader makes the faceted look from screen-space derivatives.
- **Web audio** cannot report playback position in its default mode, so nothing may sync to it.
- **Cold load in the browser is about 11 s**, mostly shader compilation, so the first screen
  must not look frozen, and effects should be warmed up before they are first needed in play.
- **Shader errors only show in windowed desktop runs and in the browser**, never in
  `tools/check.sh`. A clean check is not evidence that a shader compiles.

## Who owns what

Write only inside your own paths. Anything not listed belongs to the lead.

| Workstream | Branch / worktree | Owns |
| - | - | - |
| lead | main | project.godot, export_presets.cfg, .gitignore, scripts/core/, scenes/boot.tscn, tools/ (except subfolders below), docs/BRIEF.md, docs/CONTRACTS.md, docs/TOOLCHAIN.md, docs/RENDERER_NOTES.md, README.md |
| render | ws/render | shaders/render/, scripts/render/, scenes/render/, materials/render/, assets/textures/render/, tools/textures/render/, scenes/dev/render_demo.tscn, docs/SHADERS.md |
| vfx | ws/vfx | shaders/vfx/, shaders/env/, scripts/vfx/, scripts/env/, scenes/vfx/, scenes/env/, materials/vfx/, materials/env/, assets/textures/vfx/, tools/textures/vfx/, scenes/dev/vfx_demo.tscn, docs/SHADERS_VFX.md |
| brush | ws/brush | shaders/brush/, scripts/brush/, scenes/brush/, assets/textures/brush/, tools/textures/brush/, scenes/dev/brush_demo.tscn, docs/BRUSH.md |
| gameplay | ws/game | scripts/game/ (level kit in scripts/game/kit/), scenes/game/, scenes/ui/, ui/, scenes/levels/hazewater/, scripts/levels/hazewater/, scenes/levels/example/, scenes/dev/gameplay_demo.tscn, docs/GAMEPLAY.md, docs/LEVEL_KIT.md. The registry scenes/levels/levels.json belongs to the lead. |
| assets | ws/assets | assets/characters/, assets/environment/, assets/props/, assets/textures/painted/, assets/ui/, audio/, scripts/audio/, scenes/models/, tools/blender/, tools/audio/, tools/textures/painted/, scenes/dev/assets_demo.tscn, docs/ASSETS.md |
| qa | ws/qa | tools/qa/, tests/, docs/qa/ |
| l2, l3, l4, l5 | ws/l2 .. ws/l5 | for its own level id only: scenes/levels/<id>/, scripts/levels/<id>/, assets/levels/<id>/, audio/levels/<id>/, tools/levels/<id>/, docs/levels/<id>/ (ids in docs/LEVELS.md) |

Every workstream also owns `docs/<name>/` for its evidence and `tools/<name>/` for its own
scripts, and may add further scenes named `scenes/dev/<name>_*.tscn`.

An owner may add public members to its autoloads and classes, and must list the additions in
its report. An owner never removes or renames a member this file names.

Each workstream keeps one demo scene in scenes/dev/ that shows its work on its own, with
whatever placeholders it needs, and that runs clean on desktop and in the web build
(`scene=res://scenes/dev/<name>_demo.tscn`).

## Project settings the lead has already made

**Autoloads, in load order.** Each already exists as a working stub with the full public API.
The owner replaces the body in place and keeps every public member.

| Name | File | Owner |
| - | - | - |
| Controls | scripts/core/controls.gd (registers the input actions) | lead |
| Events | scripts/core/events.gd | lead |
| Settings | scripts/core/settings.gd | lead |
| CurseField | scripts/render/curse_field.gd | render |
| Post | scenes/render/post_chain.tscn | render |
| Vfx | scripts/vfx/vfx_director.gd | vfx |
| Audio | scripts/audio/audio_director.gd | assets |
| Brush | scenes/brush/brush_layer.tscn | brush |
| Game | scripts/game/game.gd | gameplay |

The boot scene loads `res://scenes/game/main.tscn` by default once gameplay delivers it
(title screen first, then the valley); until then it loads the phase 0 probe scene.

Global classes: `Boot` (scripts/core/boot.gd, options from the command line or URL),
`Palette` (scripts/core/palette.gd), `Layers` (scripts/core/layers.gd),
`InkLook` (scripts/render/ink_look.gd, render).

**Input actions.**

| Action | Keys | Use |
| - | - | - |
| move_forward / move_back / move_left / move_right | W / S / A / D | Move, relative to the camera |
| cam_left / cam_right / cam_up / cam_down | Arrow keys | Orbit the camera without the mouse |
| jump | Space | Jump |
| attack | Left mouse button, J | Tail swipe |
| brush | Left Shift, Q, right mouse button | Hold to open the brush; release to cast |
| brush_draw | Left mouse button (pen tip) | Paint while the brush is open |
| pause | Escape, P | Pause menu |
| paper_cycle | F2, O | Cycle paper intensity |

Mouse motion orbits the camera while the mouse is captured. In the browser the mouse can only
be captured after a click, and Escape always releases it; treat a lost capture as a pause.

**Physics layers:** 1 world, 2 player, 3 enemy, 4 brush_target, 5 trigger, 6 player_hit,
7 enemy_hit. Bit constants and the brush ray mask are in `Layers`.

**Groups:** `player`, `enemy`, `brush_target`, `cursed_zone`.

**Canvas layers:** Post 5, HUD 20, Brush 30, menus and title 40, fades 50 (`Layers.CANVAS_*`).
The post chain affects the 3D world only; the HUD and menus draw above it.

**Global shader uniforms** (declared in project.godot; ask the lead to add more):

| Name | Type | Set by | Meaning |
| - | - | - | - |
| paper_intensity | float | Settings | 0 Light, 0.5 Normal, 1 Heavy |
| curse_zone_0 .. curse_zone_3 | vec4 | CurseField | xyz centre, w radius of each cursed sphere |
| curse_amount | vec4 | CurseField | per-zone curse, 0 clean to 1 cursed |
| valley_gloom | float | CurseField | valley-wide dullness, 1 until the tree is restored |
| wind | vec4 | vfx (env) | xyz direction, w strength |
| player_world_pos | vec3 | gameplay | the player's position, for foliage bending and wake effects |
| light_field, light_shade, light_tint, light_pool_0..7, light_tint_0..7 | see docs/SHADERS.md | render (`LightPools`) | light pools: lamplight that brings colour back in a drained place, and darkness pushed back by lit lamps. A level adds a `LightPools` node (scripts/render/light_pools.gd) and never sets these itself. Off by default |

## Events (scripts/core/events.gd)

| Signal | Emitted by | Typical listeners |
| - | - | - |
| brush_opened, brush_closed | brush | audio, gameplay (HUD), vfx |
| glyph_cast(glyph, info) | brush, after targets have been told | vfx, audio, gameplay |
| glyph_failed(info) | brush | audio, HUD |
| ink_changed(current, maximum) | brush | HUD |
| player_attacked(attack, origin) | gameplay | vfx (trail), audio |
| player_damaged / player_healed (hp, max_hp) | gameplay | HUD, audio, vfx |
| player_died, player_respawned(at) | gameplay | audio, HUD |
| enemy_hit(enemy, damage, at) | gameplay | vfx, audio |
| enemy_died(enemy, kind, at) | gameplay | vfx (ink splash), audio, brush (ink refill) |
| enemy_unveiled(enemy) | gameplay | vfx, audio |
| thorns_cut(target, at), soot_cleared(target, at) | gameplay | vfx, audio |
| zone_entered / zone_exited (zone_id) | gameplay | audio |
| zone_restore_started(zone_id, center, radius) | gameplay | vfx (bloom ring, petals), audio |
| zone_restored(zone_id) | gameplay | audio, HUD |
| finale_started(center), valley_restored | gameplay | vfx, audio, render (gloom is driven by gameplay through CurseField) |
| bead_awarded(level_id, color) | gameplay, when a level's bead is awarded | vfx, audio, HUD |
| player_thrown_back(at, cause) | gameplay kit: cause `water` (DeepWater, `at` on the surface), `curse` (CursedGround) or `rising` (RisingHazard, rising ink; vfx and audio treat it as `curse`) | vfx, audio |

Kit node signals other workstreams may connect to (docs/LEVEL_KIT.md has the full list):
`EnemyBase.unravel_started(duration)`, `VerseStone.woken`, `CursedGround.hurt(at)`,
`KindleTarget.kindled`, `TiePost.tied_up`, `SealedFight.fight_started` / `fight_won`,
`Pickup.picked`, `GlyphTarget.glyph_received(glyph, info)`, `Game.enemy_finished(enemy)`.
| game_state_changed(state) | gameplay | everyone |

Zone ids: `&"zone_a"`, `&"zone_b"`, `&"tree"`. CurseField slots: 0 zone_a, 1 zone_b, 2 tree.

## Brush

Autoload `Brush` (CanvasLayer, layer 30, `process_mode = ALWAYS`).

- While the `brush` action is held, and `Brush.enabled` is true, and the tree is not already
  paused: set `get_tree().paused = true`, show the mouse cursor, fade to sepia scroll paper with
  the frozen scene faintly visible, emit `Events.brush_opened`. On release: recognise, cast,
  fade back, restore the previous mouse mode, unpause, emit `Events.brush_closed`.
- Public members: `enabled`, `ink`, `ink_max`, `is_open()`, `add_ink(amount)`, `refill()`,
  `known_glyphs()`, `inject_stroke(points) -> Dictionary` (casts a stroke given in viewport
  pixels exactly as if drawn; QA and demos depend on it).
- The ink-pot meter is `scenes/brush/ink_pot.tscn`, a Control the gameplay HUD instances.
- Ink refill on `Events.enemy_died` and over time is the brush's job.

**Casting.** Candidates are every node in groups `brush_target` and `enemy` that is in front of
the camera and within 60 m. A candidate may define `glyph_anchor() -> Vector3` (world point
tested against the stroke; default its global position plus 0.8 m up) and
`glyph_radius() -> float` (world radius; default 1.0). Tests are in screen space:
bloom hits candidates whose anchor projects inside the drawn loop; slash hits candidates whose
projected disc touches the stroke; gust hits candidates inside the stroke's bounds grown by
40 px. For each hit, nearest first, call `on_glyph(glyph: StringName, info: Dictionary) -> bool`
if the node has it. Then emit `Events.glyph_cast(glyph, info)`.

**Glyph info.**

| Key | Type | Meaning |
| - | - | - |
| glyph | StringName | &"bloom", &"slash", &"gust" |
| score | float | recogniser confidence, 0..1 |
| screen_points | PackedVector2Array | the stroke, viewport pixels |
| screen_center, screen_radius | Vector2, float | stroke centroid and mean radius |
| world_points | PackedVector3Array | ray hits along the stroke (may be fewer than screen points) |
| world_center | Vector3 | ray hit under the centroid, or a point 12 m along the ray if it hit nothing |
| world_radius | float | approximate radius of the stroke on the ground |
| world_from, world_to | Vector3 | ray hits under the stroke's start and end |
| world_dir | Vector3 | start to end, flattened to the ground plane, normalised (wind direction for gust) |
| targets | Array[Node] | nodes that returned true from on_glyph, nearest first |
| ink_cost | float | ink spent |

## Render

- `InkLook` (Node): add as a child of any Node3D and every MeshInstance3D under that parent
  gets the toon material with its outline pass, taking albedo from the mesh's existing material.
  Exports: `outline_width`, `accent` (&"", &"vermilion", &"gold"), `cursable`, `wind`,
  `apply_on_ready`. Methods: `apply()`, `set_dissolve(amount)` (0 solid to 1 gone, for enemy
  deaths), `flash(color, duration)`.
- `CurseField`: `set_zone(slot, center, radius, amount)`, `restore_zone(slot, duration)`,
  `clear_zone(slot)`, `amount_at(world_pos) -> float`, `valley_gloom`,
  `set_valley_gloom(amount, duration)`. Gameplay drives it; render draws it.
- `Post`: applies the chain to the current camera with no setup elsewhere; `set_enabled(on)`;
  follows `Settings.paper_intensity`.
- A blob shadow scene, `scenes/render/blob_shadow.tscn`, that gameplay parents under characters.

**Vertex colour, glTF to shader.** R = outline width weight (0 no line, 1 full line).
G = wind sway weight (0 rigid, 1 full sway). B = dry-brush tendency (0 solid line, 1 broken line).
A unused. A glTF material whose name ends in `_sacred` keeps its colour inside cursed zones and
takes the accent treatment.

## Vfx and environment

Autoload `Vfx`: `ink_splash(at, size)`, `petal_burst(at, radius)`, `bloom_ring(center, radius)`,
`slash_ribbon(from, to)`, `gust(at, direction, strength)`, `hit_spark(at)`,
`attach_trail(node, lifetime) -> Node` (set `emitting` on the result).

The director reacts to these on its own, so gameplay must not also call it for them:
`enemy_died` (ink splash), `enemy_hit` (hit spark), `glyph_cast` (slash ribbon, gust swirl,
bloom flowers at the cast point), `zone_restore_started` (bloom ring and petals),
`valley_restored` (valley-wide petals), `thorns_cut`, `soot_cleared`, `enemy_unveiled`.
Flowers sprouting in the player's wake are also the director's job: it finds the node in group
`player` (a CharacterBody3D) and only sprouts where `CurseField.amount_at()` is near zero.

Environment pieces gameplay places in the valley: `scenes/env/sky.tscn` (sky and swirled
clouds), `scenes/env/river_water.tscn` plus a water material usable on any mesh,
`scenes/env/foliage_scatter.tscn` (camera-facing card foliage with wind), `scenes/env/mist.tscn`,
`scenes/env/soot_bank_visual.tscn`. Vfx sets the `wind` global.

## Audio

Autoload `Audio`: `play_sfx(id, at = Vector3.INF, volume_db = 0)`, `play_music(id, fade)`,
`set_brush_duck(on)`. The director chooses music from `game_state_changed`, `zone_restored`,
`finale_started` and `valley_restored`, and plays every event-driven sound itself. Gameplay
calls `play_sfx` only for things no event covers: footstep, jump, land, ui_move, ui_accept.
It follows the volumes in `Settings`.

A level adds its own music and sounds at run time: `register_music(id, source, loop = true)`,
`register_sfx(id, source, trim_db = 0, pitch_spread = 0)`, `has_music(id)`, `has_sfx(id)` and
`set_level_music(cursed, restored = &"", already_restored = false)`. Built-in ids cannot be
replaced. Details are in docs/ASSETS.md, "Level music and sounds".

Music ids: title, vale_cursed, vale_restored, finale.
Sound ids: footstep, jump, land, swipe, hit, hurt, splotchet_hop, splotchet_die,
reedwraith_moan, reedwraith_die, veil_off, brush_open, brush_close, brush_stroke, glyph_ok,
glyph_fail, bloom, slash, gust, thorns_cut, soot_clear, zone_restore, petals, tree_restore,
ink_pickup, ui_move, ui_accept.

Level-kit sound ids: kindle, tie, verse_wake, talk_open, talk_next, pickup, bead, splash,
curse_throwback, fight_seal, fight_won, unravel, clean_cut, raft, and the loop lamp_hum.
The director plays all of these itself from kit and `Events` signals except talk_next, pickup
and raft, which gameplay calls (docs/ASSETS.md says who plays which). A level that adds kit
nodes after load calls `Audio.hook_kit()`.

Level music ids, registered by each level from `audio/levels/<id>/`: `<id>_cursed` and
`<id>_restored` for tallowford, sedge_plain, mosswater and hollow_kiln, and `hollow_kiln_dregs`.

## Models

Assets delivers each model as a .glb under assets/ and a wrapper scene under scenes/models/
whose root is a Node3D with an `InkLook` child and, for animated models, an AnimationPlayer
reachable as `%AnimationPlayer`. Gameplay instances the wrapper; while a wrapper does not
exist yet (`ResourceLoader.exists`), gameplay uses a placeholder primitive.

| Wrapper scene | Animations |
| - | - |
| scenes/models/fox.tscn | idle, run, jump, fall, land, attack_1, attack_2, hurt, brush_pose |
| scenes/models/splotchet.tscn | idle, hop, attack, hurt |
| scenes/models/reedwraith.tscn | idle, drift, attack, veil_off, hurt |
| scenes/models/sapling.tscn | withered, bloom |
| scenes/models/great_tree.tscn | withered, bloom |
| scenes/models/thorn_gate.tscn, shrine.tscn, stepping_stone.tscn, rocks, reeds | none |
| scenes/models/valley_terrain.tscn | none; carries the M_* marker nodes |
| scenes/models/raft.tscn | bob (autoplays); origin at the waterline, bow along -Z; the level moves the whole wrapper |
| scenes/models/folk/*.tscn (pell and the cast) | idle, talk, walk, faded; root is `FolkPerson` with `faded`, `wake()` and the `woke` signal. Generate a cast with the folk generator, docs/ASSETS.md "Folk" |

In a web export, list resource folders with `ResourceLoader.list_directory`, never `DirAccess`,
which sees only `.remap` files there.

Animations are authored at 12 keys per second. Attack animations include a node named `Smear`
(a stretched arc of the swinging part) that is visible only on the smear frames. Gameplay plays
animations through a stepped animator that advances in 1/12 s steps, so nothing interpolates.
Characters face -Z, stand on Y = 0, and are in metres (the fox is about 1.1 m long).

## QA hooks

- Boot options (command line after `--` on desktop, URL query in the browser):
  `scene`, `paper`, `screenshot`, `shot_after`, `quit_after`, and anything else through
  `Boot.opt(key, default)`.
- Gameplay honours `warp=<marker name>` (start there), `god=1` (no damage) and `autoplay=1`
  (a scripted run of the whole slice that casts glyphs through `Brush.inject_stroke`).
- `Game.debug_snapshot()` returns plain data; `Game.qa_log(tag, data)` prints one `QA:{json}`
  line. Emit qa_log at least for: state changes, zone restored, enemy died, glyph cast, finale,
  valley restored. The browser check reads these from the console.

## Working rules

- Your worktree is `.worktrees/<name>/` on branch `ws/<name>` (names: render, vfx, brush, game,
  assets, qa). Do everything there: run every command from inside it and use paths inside it. Commit to
  your branch as often as you like. Never commit to `main`, never touch the top-level checkout
  or another worktree, and never push. (The lead pushes `main` to the project's private
  GitHub repository after each integration; nobody else pushes anything.)
- `.tools/` exists only at the top level; the scripts in `tools/` find it on their own.
  Do not write into it.
- Run `git merge main` at the start of each work session and before you report, and fix what
  it breaks. The lead merges your branch into main.
- The scripts in `tools/` are documented in docs/TOOLCHAIN.md. Within one checkout, never run
  two of them at once if either imports or exports.
- Before you report: `tools/check.sh` passes, your demo scene has a desktop screenshot
  (`tools/screenshot_desktop.sh`), and your demo scene passes the browser smoke check
  (`tools/smoke_web.sh`) from a fresh `tools/export_web.sh`. Look at both screenshots yourself.
  Put evidence under docs/ in your own area and name it in the report.
- Report what you ran and what you saw. Say what is unverified. Say what you need from another
  workstream or from the lead, with the exact change.
