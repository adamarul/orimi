# Vfx and environment shaders

Owner: vfx. This file lists every uniform of every vfx and environment shader and the channel
layout of every texture in `assets/textures/vfx/`. The shared rules (colour handling, curse,
globals) live in render's `shaders/render/ink_common.gdshaderinc` and docs/SHADERS.md; these
shaders include it through `shaders/vfx/vfx_common.gdshaderinc` and keep no private copy.

## Rules every shader here follows

- **Colour.** Every `source_color` uniform is read through `ink_in()`, colour maths happens in
  sRGB display values, and `ALBEDO` is written through `ink_out()`. No shader writes `EMISSION`.
  The painted textures carry data rather than colour (see the table at the end), so they are
  sampled without `source_color`. Vertex and instance `COLOR` tints are multiplied in as sRGB.
- **Curse.** `ink_curse_amount_at()` from the include (sky at the camera, water per pixel,
  foliage and mist per instance origin). Nothing re-derives zone maths.
- **Gloom.** The `valley_gloom` global drains the sky, water and foliage.
- **Paper fade.** `ink_paper_fade(dist, fade_start, fade_end) * fade_max` toward `INK_PAPER`, with
  the toon's defaults (35 m, 140 m, 0.85), in the sprite, ribbon, foliage and water shaders.
- **Wind.** Foliage sway is `ink_wind_offset()` with the `wind` global (the same sway the toon
  body uses). Vfx sets `wind` (xyz direction, w strength) every step and adds gusts to it.
- **Time.** Shaders animate on a per-material `vfx_time` uniform, never on `TIME`. The `Vfx`
  director advances it in 1/12 s steps (one step per frame at most) and pushes it to every
  registered material, so the value is already quantised the way `ink_stepped_time(TIME, 12)`
  would be. `TIME` keeps running while the tree is paused, and the brush pauses the tree, so
  `ink_stepped_time(TIME, …)` would keep effects moving under the brush. `vfx_time` stops, and
  the demo checks this (`VFX_PAUSE_CHECK … frozen=true`). One-shot sprites and ribbons carry
  their animation in instance data that the director also writes once per step.
- **Fog.** All shaders here use `fog_disabled`; the post chain owns atmosphere.
- **ink_skip.** Layers, ribbons, the sky dome, foliage cards and soot clumps are in group
  `ink_skip` so an InkLook parent never replaces their material.

## Effects (shaders/vfx/)

### fx_sprite.gdshader / fx_sprite_flat.gdshader (body: fx_sprite.gdshaderinc)

One-shot sprites drawn by `VfxLayer` (one MultiMesh per layer) and the soot bank.
`fx_sprite` is an opaque cut-out that writes depth, so the crease pass inks its edge.
`fx_sprite_flat` is the same body in the transparent pass with alpha exactly 1 and
`depth_draw_never`, so it gets no outline (petals).

Per instance: transform origin and X/Y scale = size; `INSTANCE_CUSTOM` = (atlas frame, +64
flips V; erode 0..1; rotation in radians, or lean for upright cards; stroke head 0..1);
`COLOR` = (tint rgb, stroke tail 0..1).

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `atlas` | texture | black | Atlas of data cells (layout below). |
| `atlas_grid` | columns, rows | (4, 2) | Atlas grid, row-major, top row first. |
| `align` | 0..3 | 0 | 0 billboard; 1 placed by the transform (flat on the ground); 2 upright card rooted at the origin, turning about Y; 3 billboard whose X axis follows the transform's X on screen. |
| `look` | 0..4 | 0 | How channels become colour: 0 ink, 1 petal, 2 flower, 3 stroke, 4 soot (see below). |
| `color_a` | colour | INK 1b1a1c | Main colour (ink, petal pink, stroke white, soot black). |
| `color_b` | colour | 6b6661 | Second colour (second pink, flower stem green, soot pale grey). |
| `color_c` | colour | white | Third colour (petal edge light, flower centre gold). |
| `cutoff` | 0.05..0.95 | 0.5 | Mask threshold; below it the pixel is discarded. |
| `pivot_y` | 0..0.5 | 0 | 0.5 roots the quad at its bottom edge (upright cards), 0 centres it. |
| `fade_start`, `fade_end` | metres | 35, 140 | Distance fade toward paper. |
| `fade_max` | 0..1 | 0.85 | How far toward paper the farthest sprites go. |

Looks: **0 ink**: R mask, G soak order, discarded where G < erode (splats soak away from the
thin edges inward). **1 petal**: R mask minus 0.45 × erode, B picks `color_a` or `color_b`, G
lifts toward `color_c`. **2 flower**: mask is the max of the three channels; the instance tint
is the blossom, G picks the stem colour `color_b`, B the centre `color_c`. **3 stroke**: R mask, G
arc parameter; only the part between tail (`COLOR.a`) and head (`INSTANCE_CUSTOM.w`) draws.
**4 soot**: R mask, G tone between `color_a` and `color_b`, discarded where B < erode.

Materials the director builds: InkGround (ink_splats, look 0, align 1), InkAir (ink_splats,
look 0, align 3), Petals (petals, flat shader, look 1, PETAL / PETAL_DEEP / fffaf4), Flowers
(flowers, look 2, align 2, stem 6e9a55, centre GOLD, pivot_y 0.5, cutoff 0.45), Strokes (curls,
grid 2×4, look 3, align 3, f7f3ea, cutoff 0.4), Soot (soot, look 4, CURSE_INK / 6a6560). The soot
bank builds its own soot material (CURSE_INK / 5f5a55, cutoff 0.5).

### fx_glow.gdshader

Sparkles and the hit spark. Translucent `blend_mix`, billboard only, same instance layout as
fx_sprite; `COLOR.rgb` tints the halo and `COLOR.a` is the overall fade.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `atlas` | texture | black | sparks.png. |
| `atlas_grid` | columns, rows | (4, 1) | Atlas grid. |
| `core_color` | colour | fffcf2 | Solid core colour (where R > about 0.5). |
| `halo_color` | colour | ebcb7a | Halo colour; the director sets GOLD_PALE. |
| `halo_strength` | 0..1 | 0.35 | Alpha of the soft halo (G). Kept low because translucent blends read darker on web. |

### fx_ribbon.gdshader

Dry-brush ribbons (slash glyph, tail swipe, attached trails), built by `VfxRibbon` as a world
strip: `VERTEX` = centre-line point, `NORMAL` = tangent, `UV` = (u along the stroke, side 0/1),
`UV2.x` = arc parameter, `COLOR` = (half width in metres, erode 0..1, head 0..1, tail 0..1). It
widens toward the camera so the full width always shows. Opaque cut-out.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `ribbon_tex` | texture | white | ribbon.png. |
| `fill_color` | colour | f4efe3 | Body of the stroke (pale paper white). |
| `streak_color` | colour | a39f99 | Darker bristle streaks (G). |
| `edge_color` | colour | 4a4745 | Ink edge along the leading side. |
| `cutoff` | 0..1 | 0.32 | Bristle-load threshold; erode raises it toward 1 so the stroke dries out. |
| `streak_amount` | 0..1 | 0.5 | Strength of the streak lines. |

Paper fade is fixed at 35 / 140 m and 0.85.

## Environment (shaders/env/)

### sky.gdshader (scenes/env/sky.tscn, materials/env/sky.tres)

Flat pale wash with drifting clouds drawn as long torn-edged wash bands under one tapering
dry-brush ink tail (no curls), on a dome centred on the camera in the vertex shader. Drains
toward bare paper with `valley_gloom` and while the camera is inside a cursed zone. `Sky` (scripts/env/sky.gd) exports and forwards `cloud_count`,
`drift_speed`, `cloud_seed`, `gloom_strength` and `dome_radius`.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `vfx_time` | seconds | 0 | Director time (12 fps steps). |
| `dome_radius` | metres | 350 | Dome size; keep it inside the camera's far plane. |
| `zenith_color` | colour | b3c9cf | Wash at the top. |
| `horizon_color` | colour | ece8db | Wash at the horizon. |
| `drained_color` | colour | e8e0cf | Wash when drained by gloom or curse. |
| `cloud_fill` | colour | f6f4ed | Cloud body. |
| `cloud_ink` | colour | 6b6b6e | Cloud outline ink. |
| `clouds_tex` | texture | black | clouds.png (2×2 atlas). |
| `noise_tex` | texture | white | noise.png, for wash variation. |
| `cloud_count` | 0..16 | 14 | Clouds around the horizon. |
| `cloud_min_elev`, `cloud_max_elev` | radians | 0.05, 0.5 | Elevation band of the clouds. |
| `cloud_size` | 0.1..2 | 0.75 | Cloud width in radians of azimuth (shrinks with elevation). |
| `drift_speed` | radians per second | 0.006 | Cloud drift. |
| `wash_variation` | 0..0.2 | 0.05 | Blotchy brightness variation of the wash. |
| `gloom_strength` | 0..1 | 0.85 | How far `valley_gloom` drains the sky (a curse at the camera drains it fully). |
| `cloud_seed` | any | 3 | Picks cloud placement and frames. |

### water.gdshader (scenes/env/river_water.tscn, materials/env/water.tres)

Flat river wash with white calligraphic ripple arcs that draw on and off, and a faint network
of bright cell lines drifting with the flow. Maps in world XZ, or in mesh UV with `use_uv`. No
reflection or refraction. `RiverWater` forwards `flow_direction` and `flow_speed`.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `vfx_time` | seconds | 0 | Director time. |
| `wash_color`, `deep_color` | colour | 7fa0a6, 6b8d95 | Wash, mixed by the B noise of water_cells. |
| `line_color` | colour | f6f5ef | Ripple arcs and cell lines. |
| `cursed_color` | colour | 333133 | Water inside a cursed zone. |
| `ripple_tex` | texture | black | ripples.png (4×4 atlas). |
| `cells_tex` | texture | black | water_cells.png. |
| `flow_direction` | vec2 in XZ | (0, 1) | Downstream direction. |
| `flow_speed` | metres per second | 0.6 | Ripple drift; the cells drift at 0.55× and 0.85× of it. |
| `use_uv`, `uv_scale` | bool, vec2 | false, (1, 1) | Map by mesh UV instead of world XZ. |
| `cell_scale` | per metre | 0.11 | Cell network frequency. |
| `cell_strength` | 0..1 | 0.35 | Cell line brightness. |
| `ripple_spacing` | metres (across, along) | (2.4, 3.2) | Ripple grid. |
| `ripple_density` | 0..1 | 0.55 | Fraction of grid cells with a ripple. |
| `ripple_size` | 0.2..1 | 0.85 | Ripple size within its cell. |
| `ripple_cycle` | seconds | 2.5 | Draw-on / draw-off cycle of one ripple. |
| `gloom_drain` | 0..1 | 0.45 | Desaturation by `valley_gloom`. |
| `fade_start`, `fade_end`, `fade_max` | metres, 0..1 | 35, 140, 0.85 | Paper fade. |

### foliage.gdshader (scenes/env/foliage_scatter.tscn, materials/env/foliage.tres)

Camera-facing card foliage (reeds, grass, bush and tree fans), one MultiMesh per scatter.
Per instance: transform (root position, X scale = width, Y scale = height),
`INSTANCE_CUSTOM` = (atlas frame, random 0..1, sway weight 0..1, tint -1..1). Sways with
`ink_wind_offset`, bends away from the `player_world_pos` global (set by gameplay), drains with
`valley_gloom`, and turns to black ink silhouettes inside cursed zones. Cut-out.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `vfx_time` | seconds | 0 | Director time (drives sway). |
| `atlas`, `atlas_grid` | texture, (4, 2) | | foliage.png. |
| `light_color`, `dark_color` | colour | 9eb880, 5c7854 | Leaf tones, mixed by G. |
| `ink_color` | colour | INK 1b1a1c | Ink accent strokes (B). |
| `drained_tint` | colour | 999985 | Tint of the gloom-drained grey. |
| `cursed_color` | colour | 171618 | Silhouette colour inside a zone (lifted slightly by G). |
| `cutoff` | 0.05..0.95 | 0.45 | Coverage threshold. |
| `sway_amount` | 0..1 | 0.22 | Sway amplitude (× `wind.w`, sway weight and height²). |
| `bend_radius` | metres | 1.6 | Player bend reach. |
| `bend_amount` | 0..1.5 | 0.7 | Player bend strength. |
| `gloom_drain` | 0..1 | 0.75 | Drain by `valley_gloom`. |
| `fade_start`, `fade_end`, `fade_max` | metres, 0..1 | 35, 140, 0.85 | Paper fade. |

### mist.gdshader (scenes/env/mist.tscn, materials/env/mist.tres)

Low drifting mist bands in paper colour. Each band is a card that turns about Y to face the
camera, rooted at its bottom edge. Per instance: transform (X scale = length, Y scale =
height), `INSTANCE_CUSTOM` = (u offset, drift factor, opacity 0..1, V flip 0/1). Translucent
`blend_mix`. Forward+ blends in linear space, which lifts a pale overlay more than the web's sRGB
blend, so under `INK_LINEAR_PIPELINE` alpha is remapped (`1 - (1 - a)^0.6`, then × 0.75) to match
the web. `Mist` forwards `opacity` and `drift_speed`.

| Uniform | Range | Default | Meaning |
|---|---|---|---|
| `vfx_time` | seconds | 0 | Director time. |
| `band_tex` | texture | black | mist.png. |
| `mist_color` | colour | INK_PAPER efe6d2 | Mist colour. |
| `cursed_color` | colour | 8f8585 | Mist inside a zone (mixed at 0.7 × curse). |
| `opacity` | 0..1 | 0.7 | Overall opacity. |
| `drift_speed` | U per second | 0.02 | Drift along the band. |
| `u_repeat` | | 1 | Texture repeats along one band. |
| `near_fade_start`, `near_fade_end` | metres | 2, 9 | Fades bands out near the camera. |

## Level-kit effects (scripts/vfx/vfx_kit.gd)

Every effect draws into the director's pooled layers (one new layer, Ripples, the fx_sprite
stroke look with ripples.png laid flat on the ground) and a pool of four rope ribbons using
fx_ribbon with ink colours (fill INK, streaks INK_SOFT, edge CURSE_INK, cutoff 0.2). Both new
materials are built at start-up and drawn in `warm_up()`; no effect creates a light, a material
or a node when it plays. Each can be played by name: `Vfx.play(name, at, params)`, with the
names in `Vfx.effects()`. Each prints `VFX_FX <name>` when it plays.

| Name | Triggered in game by | params |
|---|---|---|
| kindle_catch | KindleTarget `kindled` (at its wick) | kind: lamp, brazier, lantern_fruit |
| tie_rope | TiePost `tied_up` (once per pair, between the two rings, the pair's sag) | to, sag |
| unravel | polls EnemyBase `unraveling` (1.5 s, follows the enemy) | node, duration |
| clean_cut | `Game.enemy_finished` | |
| knot_drift | polls SealedFight `knot` while it shows and the fight has not started | node, duration |
| knot_burst, fight_ring_rise | SealedFight `fight_started` | radius (ring) |
| fight_ring_fall | SealedFight `fight_won` | radius |
| verse_wake | polls VerseStone `reading` turning on (the Bloom landed) | |
| cursed_throwback | polls CursedGround `hurts` going up (at Orimi) | |
| bead_award | no hook yet: play by name, at a point above Orimi | color |
| pickup | no hook yet: play by name | color |
| water_throwback | no hook yet: play by name, at on the water surface | |
| raft_wake | no hook yet: `Vfx.attach_wake(node, water_y)` / `detach_wake(node)` | node, water_y |

The kit nodes are found by their groups (kindle_target, tie_post, sealed_fight, verse_stone,
enemy, cursed_ground) every half second; their signals are connected once (meta
`vfx_hooked`). `scenes/dev/vfx_demo.tscn` with `set=kit` plays all of them.

## Textures (assets/textures/vfx/)

Painted by `tools/textures/vfx/gen_vfx_textures.py` (run `tools/textures/vfx/gen_vfx_textures.sh`).
All RGB, sampled as data (no `source_color`), mipmapped, uncompressed. Atlases are row-major
from the top left.

| File | Size, grid | R | G | B | Cells |
|---|---|---|---|---|---|
| ink_splats.png | 1024×512, 4×2 | ink mask | soak order (low soaks first) | 0 | 0–3 splats, 4–5 streaks, 6 drop, 7 shard |
| petals.png | 512×256, 4×2 | petal mask | white edge highlight | second-pink choice (0/1 per cell) | 8 petals |
| flowers.png | 1024×512, 4×2 | blossom mask | stem and leaf mask | blossom centre mask | blossom, bell, daisy, buds, twice; stem at bottom centre |
| foliage.png | 1024×512, 4×2 | coverage | tone (0 dark, 1 light) | ink accent strokes | reeds, grass, bush, tree, twice; rooted at bottom centre |
| curls.png | 1024×1024, 2×4 | mask | arc parameter (1/255 start, 1 end) | 0 | 0–3 heavy curls, 4–7 light |
| ripples.png | 1024×512, 4×4 | mask | arc parameter | 0 | 16 ripple arcs |
| ribbon.png | 512×128 | bristle ink load (threshold to erode) | darker streak lines | noise | U along the stroke (0 head, 1 tail), V across |
| sparks.png | 512×128, 4×1 | solid core | soft halo | 0 | star, ticks, ring, star |
| soot.png | 1024×512, 4×2 | coverage | tone (0 black, 1 pale grey) | soak order | 8 clumps |
| clouds.png | 1024×512, 2×2 | fill mask | ink line mask | 0 | 4 wash-band clouds |
| water_cells.png | 512×512, tileable | thin bright cell lines | second, finer cell network | soft wash noise | |
| noise.png | 256×256, tileable | broad blotches | mid detail | streaks along U | |
| mist.png | 1024×256, tileable in U | density with ragged top and bottom | streaky detail | 0 | |
