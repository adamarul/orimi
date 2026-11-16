# Shaders (render workstream)

Every shader in `shaders/render/`, every uniform it has, what it means, its range and default,
and which preset or script sets it. Owner: render. Vfx documents its own shaders in
`docs/SHADERS_VFX.md`; brush in `docs/BRUSH.md`.

All of these run in both renderers (Forward+ on desktop, Compatibility / WebGL 2 in the browser)
and were checked in both: `docs/render/` holds the evidence.

## The shared include: `shaders/render/ink_common.gdshaderinc`

Every Orimi shader includes it (`#include "res://shaders/render/ink_common.gdshaderinc"`) instead
of re-deriving renderer differences. It declares no samplers and no varyings, so including it
costs nothing. It is guarded, so including it twice is harmless.

**Colour rule.** Do colour maths in display (sRGB) values, the numbers `Palette` holds:

| You have | Do | Why |
| - | - | - |
| A colour you computed (constant, mix, vertex colour) and write to spatial `ALBEDO` / `EMISSION` | `ink_out(c)` | Forward+ encodes linear to sRGB on output; the web writes values as they are but crushes values below 56/255 a little per 3D pass, which `ink_out` pre-compensates (measured, see below). |
| A `source_color` uniform or texture sample in a spatial shader | `ink_in(c)` | Forward+ hands you linear values; the web hands you sRGB. |
| The 3D screen texture (`hint_screen_texture` in a spatial shader) | `ink_in(c)` | Linear on desktop, sRGB on web. |
| Anything in a `canvas_item` shader, including its screen texture | nothing | sRGB in both renderers. Use plain `vec4` colour uniforms there (no `source_color`). |
| The alpha of a dark translucent overlay in a spatial shader | `ink_alpha(a)` | The web blends in sRGB space, desktop in linear, so the same alpha looks darker on web. `ink_alpha` makes desktop match web (exact for black). |
| Textures you author as painted colour | sample **without** `source_color` and treat as sRGB, then `ink_out` | Raw values are the same in both renderers. |

Proof: `scenes/dev/render_probe.tscn` (add `ramp=1` for a grey ramp) draws Palette patches through
the toon material, through `ink_out` constants, and through the whole post chain, reads the
viewport back and prints one line per patch. Desktop: 56 of 56 exact
(`docs/render/probe_desktop.txt`). Web: 56 of 56 within 1/255 (`docs/render/probe_web.txt`).
Before the dark compensation the web crushed `#0d0c0e` to `#080709` and, through the post
chain, `#1b1a1c` to `#151417` (both outside 4/255).

**Contents.**

| Name | Kind | Meaning |
| - | - | - |
| `paper_intensity` | global uniform | 0 Light, 0.5 Normal, 1 Heavy (Settings). |
| `curse_zone_0`, `curse_zone_1`, `curse_zone_2`, `curse_zone_3` | global uniforms | xyz centre, w radius of each cursed sphere (CurseField). |
| `curse_amount` | global uniform | Per-zone curse, 0 clean to 1 cursed (CurseField). |
| `valley_gloom` | global uniform | Valley-wide dullness, 1 until the tree is restored (CurseField). |
| `wind` | global uniform | xyz direction, w strength (vfx). |
| `INK_LINEAR_PIPELINE` | define | 1 in Forward+ / Mobile, 0 in Compatibility. |
| `INK_PAPER`, `INK_PARCHMENT`, `INK_SEPIA`, `INK_BLACK`, `INK_CURSE_RED`, `INK_CURSE_INK`, `INK_VERMILION`, `INK_GOLD` | `const vec3` | Palette colours as sRGB values (same numbers as `scripts/core/palette.gd`). |
| `ink_srgb_to_linear`, `ink_linear_to_srgb` | `vec3 -> vec3` | Exact piecewise sRGB transfer. |
| `ink_out(srgb)` | macro, `vec3 -> vec3` | Shader-made colour to spatial `ALBEDO`: applies the light pools (`ink_light`), then `ink_encode`. Call it in `fragment()`. |
| `ink_encode(srgb)` | `vec3 -> vec3` | The output encoding alone (sRGB to linear on desktop, dark lift on web). |
| `ink_in(c)` | `vec3 -> vec3` | `source_color` value or 3D screen texture to sRGB. |
| `ink_alpha(a)` | `float -> float` | Translucent dark overlay alpha, desktop matched to web. |
| `ink_luma(c)` | `vec3 -> float` | Rec. 601 luma. |
| `ink_view_pos(depth, uv, INV_PROJECTION_MATRIX)` | `-> vec3` | Depth texture sample to view-space position, NDC gated per renderer. |
| `ink_hash12`, `ink_hash13`, `ink_noise2`, `ink_noise3` | noise | Hashes and value noise, 0..1. |
| `ink_stepped_time(t, fps)` | `float` | Time quantised to fps steps (stepped re-seed). |
| `ink_paper_fade(dist, start, end)` | `float` | 0 near to 1 at `end`, smooth; fade toward `INK_PAPER`. |
| `ink_wind_offset(world_pos, weight, height, wind, TIME, amount)` | `vec3` | World offset for sway (the toon body and its outline both use it). |
| `INK_CURSE_FRONT(r, a)` | macro | Radius of the clean disc in a zone of radius r at amount a: `(1 - a) * (1.25 r + 2)`. `CurseField.front_radius()` is the same formula. |
| `ink_curse(world_pos, rag, rim_world, out inside, out wall, out rim, out front_edge)` | `void` | All four zones: inside (drained interior, 0..1: it fades out above and below the zone, see `ink_curse_reach`), wall (opaque black band just inside the boundary), rim (feathered crimson just outside), front_edge (dark lip of a moving restoration front). `rag` is a 0..1 noise sample that tears the edges; `rim_world` is the rim width in metres. |
| `ink_world_per_screen_h(dist, PROJECTION_MATRIX[1][1])` | `float` | Metres covered by one screen height at a view distance (uses `abs`, because Forward+ flips Y in the projection). Multiply by a %H fraction to get a screen-constant width in metres. |
| `ink_curse_reach(world_pos, zone, out vert)` | `float` | Horizontal distance from the zone's centre (zones are upright cylinders, like the wall ring). `vert` is 1 up to half a radius above or below the centre, fading to 0 over max(0.3 r, 4 m), so a tall trunk or cliff fades out of a zone instead of carrying a band where a sphere's shell would cross it. `CurseField.amount_at()` uses the same rule. |
| `ink_curse_edge(world_pos, width)` | `float` | 1 at the boundary of the cursed zone the position is in, falling to 0 by `width` metres inside; 0 outside every zone. Drives the red light that pools near the black mass. |
| `ink_curse_amount_at(world_pos)` | `float` | Soft 0..1 curse at a position without tearing, for sky / water / particles. Matches `CurseField.amount_at()`. |

## `ink_toon.gdshader` (set by `InkLook`)

Unshaded with its own fixed light, so it looks the same in both renderers and needs no light in
the scene. Faceted from screen-space derivatives (meshes keep smooth normals for the hull).

| Uniform | Range | Default | Meaning | Set by |
| - | - | - | - | - |
| `albedo_color` | colour | ivory `#efe6d2` | Flat fill colour, multiplied by the texture. | InkLook, from the source material's `albedo_color` |
| `albedo_tex` | texture | white | Painted albedo, sampled raw (treated as sRGB). | InkLook, from `albedo_texture` |
| `use_texture` | bool | false | Whether `albedo_tex` is used. | InkLook |
| `has_vertex_color` | bool | false | The mesh has a colour attribute (G drives wind). | InkLook, from the surface format |
| `light_dir` | world vector | (-0.45, 0.8, 0.4) | The fixed light for the three bands (upper left, toward the camera). | default |
| `band_high_cut` | -1..1 | 0.55 | N·L above which the highlight band starts. | default |
| `band_low_cut` | -1..1 | 0.0 | N·L below which the shadow band starts. | default |
| `band_high` | 0.8..1.3 | 1.03 | Highlight multiplier (barely lifts). | InkLook style: world 1.03, character 1.02 |
| `band_low` | 0.5..1 | 0.88 | Shadow multiplier (about 10 % darker). | InkLook style: world 0.88, character 0.9 |
| `shadow_tint` | rgb | (0.97, 0.985, 1.03) | Slightly cool shadow band. | default |
| `facet` | 0..1 | 1 | 1 = faceted from derivatives, 0 = smooth normals. | default |
| `fade_start` | metres | 35 | Distance where the fade to paper begins. | default |
| `fade_end` | metres | 140 | Distance where the fade is complete. | default |
| `fade_max` | 0..1 | 0.85 | How far toward paper the farthest things go. | default (probe sets 0) |
| `wind_enabled` | bool | false | Sway from vertex-colour G and the `wind` global. | InkLook `wind` export |
| `wind_amount` | metres per metre of height | 0.12 | Sway amplitude, scaled by `wind.w`, G and height above the origin. | default |
| `dissolve` | 0..1 | 0 | 0 solid, 1 gone; ragged ink edge eats through the body. | `InkLook.set_dissolve()` |
| `dissolve_edge` | 0..0.3 | 0.07 | Width of the black ink edge at the dissolve front. | default |
| `flash_color` | colour, alpha = amount | white, 0 | Hit flash; alpha tweens 0.85 to 0. | `InkLook.flash()` |
| `noise_tex` | texture | white | `assets/textures/render/ink_noise.png` (dissolve, blots, tearing). | InkLook |
| `cursable` | bool | true | Whether curse and gloom drain this surface. | InkLook `cursable` export |
| `sacred` | bool | false | Keeps its colour in curse; glows with the accent inside or near a zone. | InkLook, material name ending `_sacred` |
| `accent_color` | colour | vermilion `#d5402b` | Accent for sacred / interactive objects. | InkLook `accent`: vermilion or gold |
| `accent_strength` | 0..1 | 0 | Stepped edge-on accent wash. | InkLook: 0.35 with an accent, 0.2 for sacred without |
| `curse_rim_h` | %H fraction | 0.018 | Crimson rim width on the ground at the zone boundary (1.8 %H at any distance). | default |
| `curse_light` | rgb multiplier | (1.3, 0.72, 0.68) | The red light on the drained grey inside a zone. | default |
| `curse_light_amount` | 0..1 | 0.8 | Strength of that red light at the rim. | default |
| `curse_light_floor` | 0..1 | 0.3 | Share of `curse_light_amount` that reaches the middle of the zone, so the whole interior sits under red light. | default |
| `curse_light_width` | metres | 6 | How far in from the rim the red light fades to its interior level (`ink_curse_edge`). | default |
| `blot_scale` | 1/metres | 0.12 | World frequency of the pooled ink blots (larger pools at a quarter of it, grit at 3.7×). | default |
| `blot_cut` | 0..1 | 0.6 | Noise threshold for a blot; higher means fewer, smaller pools. | default |
| `curse_silhouette` | 0..1 | 0.45 | Near-vertical faces inside a zone go toward black (trunks and posts read as silhouettes); faces flatter than about 60° from vertical are untouched, so rocks stay grey. The toon shader also drops the black ground band, the crimson rim and the pooled blots on faces steeper than about 35° (fully past 55°), so the zone's edge never draws a horizontal band across a trunk and slopes at the edge do not turn into black slabs. | default |
| `gloom_desaturate` | 0..1 | 0.38 | Desaturation at `valley_gloom` = 1. | default |
| `gloom_darken` | 0..1 | 0.1 | Darkening at `valley_gloom` = 1. | default |
| `restored_saturation` | 1..1.5 | 1.12 | Saturation boost at `valley_gloom` = 0 (restored is livelier). | default |
| `light_keep` | 0..1 | 0 | How much of its own colour the model keeps against LightPools' drained and darkness (passed to `ink_light` through `INK_LIGHT_KEEP`). | InkLook `light_keep` |

## `ink_outline.gdshader` (the toon material's `next_pass`, set by `InkLook`)

Inverted hull extruded in clip space. Width in fractions of screen height (0.01 = 1 %H):
`width_h × width_scale × R × thick-thin noise × (1 ± wobble) × one-sided term × distance scale`,
clamped to `[min_h, max_h]`.

| Uniform | Range | Default | Meaning | Set by |
| - | - | - | - | - |
| `line_color` | colour | `#1b1a1c` | Near line colour. | InkLook style: world `#1b1a1c`, character `#2e2826` |
| `far_line_color` | colour | (0.42, 0.41, 0.40) | Line colour at `fade_end` (greyer with distance). | InkLook style: world `#6b6863`, character `#6a625c` |
| `width_h` | %H fraction | 0.022 | Base width. | InkLook style: world 0.02, character 0.014 |
| `min_h` | %H fraction | 0 | Lower clamp (0 lets lines taper to nothing). | default |
| `max_h` | %H fraction | 0.04 | Upper clamp. | InkLook style: world 0.04, character 0.012 |
| `width_scale` | ≥ 0 | 1 | Per-object multiplier. | InkLook `outline_width` export |
| `has_vertex_color` | bool | false | Use the mesh's R (width), G (sway), B (dry brush). | InkLook |
| `default_weight` | 0..1 | 1 | R used when the mesh has no colours. | default |
| `default_dry` | 0..1 | 0.25 | B used when the mesh has no colours. | InkLook style: world 0.25, character 0.2 |
| `brush_light_view` | view vector | (-0.35, 1.0, 0.3) | The fixed "brush light": up and toward the camera's left. | default |
| `one_sided` | 0..1 | 0.95 | How much the line thins on the lit side (1 = to nothing). | InkLook style: world 0.8, character 0.4 |
| `lit_cut` | -1..1 | 0.55 | Facing at and above which the line is thinnest. | default |
| `shade_cut` | -1..1 | -0.35 | Facing at and below which the line is full width. | default |
| `thick_thin_scale` | 1/metres | 0.55 | Frequency of the slow world-space thick-thin noise. | default |
| `thick_thin_min`, `thick_thin_max` | multipliers | 0.5, 1.4 | Range of that noise. | InkLook style: world 0.5..1.4, character 0.85..1.15 |
| `wobble_fps` | 0..12 | 7 | Re-seeds per second of the wobble and dry-brush pattern (stepped). | default |
| `wobble_amount` | 0..0.3 | 0.15 | Wobble as a fraction of the local width. | InkLook style: world 0.15, character 0.12 |
| `wobble_scale` | 1/metres | 2.3 | Frequency of the wobble noise. | default |
| `streak_tex` | texture | white | `assets/textures/render/dry_streak.png`. | InkLook |
| `dry_amount` | 0..1 | 0.55 | Gap threshold per unit of vertex-colour B. | InkLook style: world 0.55, character 0.3 |
| `dry_low_weight` | 0..1 | 0.35 | Extra gaps where the line is thin (tapers, lit side). | default |
| `streak_along`, `streak_across` | per screen height | 2.5, 28 | Streak frequency along and across the stroke. | default |
| `near_dist` | metres | 32 | Within this distance the width is not reduced. | default |
| `far_scale_min` | 0..1 | 0.45 | Smallest width multiplier with distance (`near_dist / dist`, clamped). | default |
| `fade_start`, `fade_end`, `fade_max` | metres, 0..1 | 35, 140, 0.85 | Line goes to `far_line_color` then toward paper. | default |
| `depth_pull` | clip units | 0 | Pulls the hull toward the camera (unused; for ground-contact experiments). | default |
| `wind_enabled`, `wind_amount` | | false, 0.12 | Same sway as the body so the hull follows. | InkLook |
| `dissolve`, `dissolve_edge`, `noise_tex` | | 0, 0.07, white | The hull dissolves slightly ahead of the body. | InkLook |
| `light_keep` | 0..1 | 0 | Same as the body's, so the line follows the model. | InkLook `light_keep` |

## `post_ink3d.gdshader` (Post pass 1, the full-screen 3D quad)

| Uniform | Range | Default | Meaning | Light / Normal / Heavy |
| - | - | - | - | - |
| `screen_tex`, `depth_tex` | hints | | Screen and depth textures. | |
| `kuwahara_radius` | 0..3 | 2 | Kuwahara radius in pixels (samples: (2r+1)²). | 2 / 2 / 3 |
| `kuwahara_mix` | 0..1 | 0.8 | Blend of the Kuwahara result over the original. | 0.5 / 0.85 / 0.9 |
| `crease_strength` | 0..1 | 0.75 | Opacity of the interior crease lines. | 0.7 / 0.85 / 0.9 |
| `crease_normal_cut` | 0..1 | 0.22 | Normal difference (1 - cos) where a crease starts (fully at 2×). | default |
| `crease_depth_cut` | 0..1 | 0.09 | Relative second difference of depth where a crease starts (fully at 3×). | default |
| `crease_step_px` | 0.5..3 | 1.5 | Sample spacing, which sets the crease width (about 0.2 to 0.4 %H at 720p). | default |
| `crease_color` | colour | `#4a3424` | Slightly brown ink. | default |
| `crease_break` | 0..1 | 0.45 | Share of the crease removed by screen noise (not quite closed). | default |
| `crease_wobble_px` | 0..4 | 1.2 | Stepped jitter of the sample position (wobbly lines). | default |
| `crease_fps` | 0..12 | 7 | Re-seeds per second of the jitter and breaks. | default |
| `crease_fade_end` | metres | 90 | Creases fade out by this view distance. | default |
| `far_depth` | metres | 900 | Beyond this (sky) no creases. | default |
| `debug_creases_only` | bool | false | Shows only the creases (demo `creases=only`). | |

## `post_watercolour.gdshader` (Post pass 2, canvas)

| Uniform | Range | Default | Meaning | Light / Normal / Heavy |
| - | - | - | - | - |
| `screen_tex` | hint | | Canvas screen (the 3D frame after pass 1). | |
| `stain_tex`, `noise_tex` | textures | | `paper_stain.png`, `ink_noise.png` (blotches). | scene |
| `edge_darken` | 0..3 | 1.2 | Pigment pooling on the dark side of edges (density change). | 0.6 / 1.2 / 1.6 |
| `edge_radius_px` | 0.5..6 | 2.5 | Radius of the ring the edge test compares against. | default |
| `blotch_strength` | 0..0.5 | 0.12 | Density variation of the wash, fixed to the screen. | 0.03 / 0.1 / 0.18 |
| `blotch_scale` | per screen height | 1.3 | Blotch frequency. | default |
| `strength` | 0..1 | 1 | Mix of the whole pass (probe sets 0). | default |

## `post_paper.gdshader` (Post pass 3, canvas after a BackBufferCopy)

| Uniform | Range | Default | Meaning | Light / Normal / Heavy |
| - | - | - | - | - |
| `screen_tex` | hint, mipmapped | | Canvas screen; mips feed the glow. | |
| `tooth_tex`, `stain_tex`, `fibre_tex` | textures | | `paper_tooth.png`, `paper_stain.png`, `paper_fibres.png`. | scene |
| `tooth_strength` | 0..0.3 | 0.05 | Luminance shift of the embossed tooth. | 0.025 / 0.07 / 0.15 |
| `tooth_cells_per_h` | cells | 200 | Tooth cells per screen height (cell about 0.5 %H). | default |
| `tooth_light` | screen vector | (-0.7, -0.7) | Emboss light direction (upper left). | default |
| `stain_strength` | 0..0.5 | 0.08 | Large warm staining, stronger toward the corners. | 0 / 0.24 / 0.45 |
| `stain_scale` | per screen height | 0.7 | Stain frequency (blotches 15 to 30 % of the screen). | default |
| `stain_tint` | rgb | (0.88, 0.8, 0.68) | Warm stain colour (multiplied). Kept low in chroma so heavier staining does not raise saturation (QA F-007). | default |
| `fibre_strength` | 0..1 | 0 | Sparse dark and pale fibres. | 0 / 0 / 1.0 |
| `fibre_scale` | per screen height | 1.2 | Fibre tiling. | default |
| `grain_strength` | 0..0.1 | 0.012 | Per-pixel grain. | 0.006 / 0.012 / 0.022 |
| `grain_fps` | 0..24 | 12 | Grain re-seeds per second. | default |
| `vignette_strength` | 0..1 | 0.25 | Warm parchment vignette. | 0 / 0.35 / 0.7 |
| `vignette_start`, `vignette_end` | 0..1.5 | 0.45, 1.05 | Vignette radii (aspect-corrected). | default |
| `vignette_color` | rgb | (0.7, 0.63, 0.53) | Vignette colour (multiplied), a sepia-grey for the same reason. | default |
| `saturation` | 0..1.5 | 1 | Overall saturation, applied last (after stain and vignette). Mean HSV saturation of the M_Spawn view on desktop falls Light 0.154, Normal 0.147, Heavy 0.140 (QA's `imgstats.py paper`). | 1 / 0.75 / 0.55 |
| `glow_strength` | 0..1 | 0.22 | Soft wide glow on bright areas (screen blend). | 0.15 / 0.22 / 0.25 |
| `glow_threshold` | 0..1 | 0.72 | Luminance where the glow starts. | default |
| `glow_lod` | 0..8 | 4 | Mip level of the blur (plus the next level). | default |
| `luma_floor` | 0..1 | 0.08 | Below this luminance the paper vanishes (ink black stays black). | default |
| `strength` | 0..1 | 1 | Mix of the whole pass (probe sets 0). | default |

## `blob_shadow.gdshader` (`scenes/render/blob_shadow.tscn`)

| Uniform | Range | Default | Meaning | Set by |
| - | - | - | - | - |
| `shadow_color` | colour | `#0d0c0e` | Near black. | default |
| `strength` | 0..1 | 0.75 | Darkness at the centre (70 to 80 %). | `blob_shadow.gd` `strength` export |
| `feather` | 0..1 | 0.18 | Width of the soft edge as a fraction of the radius. | default |
| `raggedness` | 0..0.3 | 0.08 | Slight irregularity of the outline. | default |
| `fade` | 0..1 | 1 | Fades with height above the ground. | `blob_shadow.gd` each physics frame |

## `curse_wall.gdshader` (built by `CurseField`, one per zone)

A ring of quads whose foot follows the terrain: `CurseField` raycasts each segment's foot onto
the lowest world surface under it when a zone changes (height = 0.1 × radius clamped to 0.9..2.0 m,
8 segments per metre of radius clamped to 64..192). Two-sided, no depth write. The top is torn at
three noise scales (big swells around the ring that sink almost to the ground between them, so
the wall reads as broken mounds rather than a band; mid billows; fine rag); below the top it is opaque ink, the
upper `feather` share thins through crimson, and a glow sits above it. It shrinks to
`inside_scale` while the camera or the player is inside the zone, flattens with camera distance
so far zones read as a stain with a red edge, and sinks as the restoration front reaches the rim.

| Uniform | Range | Default | Meaning | Set by |
| - | - | - | - | - |
| `player_world_pos` | global uniform | | Player position (also declared by `shaders/env/foliage.gdshader`); inside the zone the wall shrinks. | gameplay |
| `slot` | 0..3 | 0 | Which `curse_zone_N` / `curse_amount` component it follows. | CurseField |
| `height` | metres | 2 | Maximum height of the mass above the ground. | CurseField: 0.1 × radius, 0.9..2.0 |
| `mass` | 0..1 | 0.8 | Height of the billows as a share of `height`. | default |
| `feather` | 0..1 | 0.3 | Share of the local height that thins from ink through crimson at the top. | default |
| `rim_h` | %H fraction | 0.02 | Minimum crimson feather and glow thickness (2 %H at any distance). | default |
| `creep_speed` | per second | 0.04 | How fast the billows and rim creep. | default |
| `inside_scale` | 0..1 | 0.2 | Height multiplier while the camera or player is inside the zone. | default |
| `far_start`, `far_end` | metres | 8, 45 | Camera distance outside the rim over which the mass flattens. | default |
| `far_scale` | 0..1 | 0.25 | Height multiplier at `far_end` and beyond. | default |
| `rim_color`, `glow_color` | colours | `#b3202a`, (0.93, 0.32, 0.25) | Rim crimson and its glowing outer feather. | default |
| `noise_tex` | texture | | `ink_noise.png`. | CurseField |
| `fade_start`, `fade_end` | metres | 60, 220 | Fade toward paper with distance. | default |

## Light pools: `LightPools` (`scripts/render/light_pools.gd`)

Lit places in the world. A level adds one `LightPools` node (a plain node, not an autoload) and
gives it lights. Two level-wide amounts say what the pools push back, and either can be
animated:

- **drained**: outside every pool the place is grey, like an unpainted drawing. A lamp lit in it
  brings the colour back in a pool, warm at the centre. When the last lamp is lit,
  `set_drained(0.0, 3.0)` restores the whole place. This is not the Spill: there is no wall, no
  rim and no red.
- **darkness**: outside every pool the place is multiplied down to `shade_color`. Each kindled
  lantern opens a pool you can see in.

The pools work in every spatial shader that writes its colour through `ink_out()`: the toon
material (so every InkLook model, folk and enemies included), outlines, the curse wall, blob
shadows, and the vfx and env shaders (foliage, water, mist, sky, fx). Nothing in those shaders
changes, because `ink_out(c)` is a macro that applies `ink_light()` before encoding. Plain
`StandardMaterial3D` placeholders are not affected.

Some things keep their colour. `InkLook.light_keep` (0..1, default -1 = automatic) is how much
of its own colour a model keeps against drained and darkness. Automatic gives 1 to a model
under the player group (she brings the colour back, so she keeps hers), 0.7 under the enemy
group (readable in the dark), and 0 to everything else, folk and Pell included, which follow
the place. A shader of its own keeps colour by defining `INK_LIGHT_KEEP` (a constant or a
uniform's name) before including `ink_common.gdshaderinc`. Effects keep theirs with
`#define INK_LIGHT_KEEP 1.0` above the include in `fx_sprite.gdshaderinc`, `fx_glow` and
`fx_ribbon`, so bloom petals and flowers stay coloured in a drained place. It must not go in
`vfx_common.gdshaderinc`, which the env shaders (foliage, water, mist, sky) also include: they
follow the place. An emissive prop that should stay readable in the dark without spending a
pool (an unlit lantern-fruit) sets `light_keep` (0.6) on its InkLook and calls `apply()`.

The Post pass's creases (`post_ink3d`) go through `ink_light` too, at the depth under each
crease pixel, so lines darken with the dark instead of drawing brown over it. A translucent veil
(mist) uses `ink_veil(c)` instead of `ink_out`: `ALBEDO = v.rgb; ALPHA = alpha * v.a;` fades its
opacity by how much the place darkened it, so a pale veil does not lift a dark wood. Everything is off until a level sets it,
and the node switches everything off again when it leaves the tree, so Level 1 is unchanged.

| Member | Meaning |
| - | - |
| `set_light(id, at, radius, color = WARM, strength = 1.0)` | Add or move a light at once. `radius` in metres; `strength` 0..1. |
| `light_up(id, at, radius, color = WARM, strength = 1.0, duration = 1.0)` | Light a pool over `duration` seconds: it grows from a third of its radius and fades in. |
| `remove_light(id)`, `clear_lights()`, `has_light(id)` | |
| `set_drained(value, duration = 0.0)`, `set_darkness(value, duration = 0.0)` | Animate the level-wide amounts (0..1). |
| `drained`, `darkness` | The same amounts as properties (0 by default). |
| `warmth` | 0..1, default 0.6: how strongly a light's colour warms the middle of its pool. |
| `shade_color` | Multiplier at full darkness, default (0.30, 0.31, 0.39). |
| `far_distance` | Metres, default 200: beyond this view distance, drained and darkness thin to 15 %, so the sky keeps its colour. |
| `drained_tint` | Colour the drained grey is multiplied by, default (1.0, 0.93, 0.8): an amber-grey dusk. White gives a neutral grey. |
| `drained_saturation` | 0..1, default 0.35: how much of its own colour a drained surface keeps (0 = plain grey). |
| `MAX_DRAWN` | 8. Any number of lights may be set; each frame the 8 whose pools come nearest the camera are drawn. |
| `WARM` | Default light colour, (1.0, 0.84, 0.6). |

A pool is a ragged ball around `at`, squashed vertically (a lamp 2.5 m up lights the ground
around its post). Its edge sits between 80 % and 100 % of the radius. The lights' colours warm
the colour toward `color × 1.12` by `warmth × Σ strength × (1 - d/r)²` (overlapping pools mix
their colours by weight). For a pool that travels
with the player, call `set_light(&"player", player.global_position, 3.5, WARM, 0.5)` each frame.

How a level connects the kit's Kindle targets (`kindled` signal, `lit` property, `light_color`
and `light_range` exports; docs/LEVEL_KIT.md), in the level's own script:

```gdscript
var pools := LightPools.new()

func _ready() -> void:
	add_child(pools)
	pools.set_drained(1.0)                           # Tallowford; Mosswater: pools.set_darkness(1.0)
	for lamp in find_children("*", "StaticBody3D"):
		if lamp is KindleTarget:
			var at: Vector3 = lamp.global_position + Vector3.UP * 2.0
			lamp.kindled.connect(func() -> void: pools.light_up(lamp.name, at, lamp.light_range, lamp.light_color))
			if lamp.lit:
				pools.set_light(lamp.name, at, lamp.light_range, lamp.light_color)
	# when the last lamp is lit: pools.set_drained(0.0, 3.0)
```

If CurseField's `valley_gloom` is also on, it dulls the colour as well. A level that uses
`drained` should set `CurseField.set_valley_gloom(0.0)`, so that the lamps alone decide the
colour.

Demo: `scenes/dev/render_lights.tscn` lights three lamps one after another, then restores the
whole square. Boot options: `mode=drained|dark|none`, `lit=0..3` (hold with that many lit),
`step=` (seconds between lamps), `curse=1` (a cursed zone with tall trunks in it and on its rim),
`view=main|close|curse|keep`, `keep=0|1` (1, the default, gives the fox `light_keep` 1 and the
Splotchet 0.7, as the player and an enemy get in a level; the demo's models are not in those
groups). `docs/render/light_keep_web.jpg`: dark (top) and drained (bottom), `keep=0` left and
`keep=1` right, in the browser.

### Light pools in `ink_common.gdshaderinc`

| Name | Kind | Meaning |
| - | - | - |
| `light_field` | global uniform vec4 | x drained, y darkness, z warmth, w 1 while any pool is lit. All 0 means `ink_light` returns its input exactly. |
| `light_shade` | global uniform vec4 | rgb shade colour, a `far_distance`. |
| `light_tint` | global uniform vec4 | rgb `drained_tint`, a `drained_saturation`. |
| `light_pool_0`, `light_pool_1`, `light_pool_2`, `light_pool_3`, `light_pool_4`, `light_pool_5`, `light_pool_6`, `light_pool_7` | global uniforms vec4 | xyz centre, w radius of the drawn pools (0 = unused). |
| `light_tint_0`, `light_tint_1`, `light_tint_2`, `light_tint_3`, `light_tint_4`, `light_tint_5`, `light_tint_6`, `light_tint_7` | global uniforms vec4 | rgb light colour, a strength. |
| `ink_light(c, world_pos, view_dist, keep)` | `vec3` | The pools applied to an sRGB colour; `keep` 0..1 is how much of `c` survives drained and darkness. |
| `ink_light_pool(...)` | `void` | One pool's contribution (internal to `ink_light`). |
| `INK_NO_LIGHT` | define | Define it before the include in a shader that draws a full-screen pass; `ink_out` then only encodes (`post_ink3d` does this). |
| `ink_light_veil(c, world_pos, view_dist, keep)`, `ink_veil(c)` | `vec4` | For a translucent veil: rgb is the encoded lit colour, a is the opacity it keeps (lit brightness / own brightness). `ink_veil` is the macro form, like `ink_out`. |
| `INK_LIGHT_KEEP` | define | The `keep` that `ink_out` passes, 0.0 unless defined before the include (ink_toon and ink_outline define it as their `light_keep` uniform). |

`ink_out` must be called in `fragment()`, because the macro reads `VERTEX` and `INV_VIEW_MATRIX`
there. Every caller in the project does.

## `probe_constant.gdshader` (dev probe only)

| Uniform | Range | Default | Meaning |
| - | - | - | - |
| `index` | 0..7, or 100 + grey | 0 | Which include constant to write through `ink_out`, or a grey level (`index - 100`)/255. |

## Measured renderer facts this file relies on

- `PROJECTION_MATRIX[1][1]` is negative in Forward+ (Y flip) and positive on web. Use its
  magnitude.
- On web, every 3D pass crushes values below 56/255 (8 → 1, 16 → 12, 24 → 21, 48 → 47 in
  /255, measured on ANGLE / D3D11 / RTX 3080 with `render_probe.tscn ramp=1`). `ink_out`
  pre-compensates. Shaders that do not use `ink_out` (lit StandardMaterial3D, other teams'
  shaders) lose a few levels in their darkest tones on web. Not measured on other GPUs.
- The canvas screen texture holds sRGB values in both renderers and canvas `COLOR` is written
  as is, so the canvas passes need no conversion.
