# Renderer notes (phase 0)

Measured with Godot 4.7.2 on an RTX 3080. Desktop: Forward+ on Vulkan 1.4. Web: the Compatibility
renderer on WebGL 2.0 in Chrome 157, run headless but on the GPU through ANGLE (Direct3D 11) on the
RTX 3080, not a software rasteriser. The probe scene is `scenes/phase0/phase0.tscn`
(`scripts/phase0/phase0.gd`, `shaders/phase0/`). It checks itself: post passes write coloured tiles
along the top edge, the script reads the viewport image back, and every probe prints an
`ORIMI_PROBE` line. Evidence is in `docs/phase0/`.

The web build is the acceptance target, so the right-hand columns decide.

| Feature | Forward+ (desktop) | Compatibility (web) | How tested | Use instead / rule |
| - | - | - | - | - |
| Inverted-hull outline as `next_pass`, extruded in clip space (constant pixel width) | Works | Works | Torus + glTF mesh with `shaders/phase0/ink_outline.gdshader`; counted outline-coloured pixels around each (179 / 176 on the torus) | Use it. Flat-shaded meshes crack the hull at hard edges, so export **smooth** normals and make the flat look in the toon shader from `cross(dFdx(VERTEX), dFdy(VERTEX))` (works in both, see the glTF pebble). |
| Vertex colours from a Blender glTF, read in a shader | Works | Works | `tools/blender/phase0_vcol_probe.py` paints a colour attribute and exports `assets/phase0/vcol_probe.glb` headless; the game reads `Mesh.surface_get_arrays` and renders `COLOR` | Same 63 colours in both renderers (min #21241f, max #d73c69), and **alpha survives** (0.25 to 1.00). The values are the colours as painted in Blender. Weights in R/G/B (per CONTRACTS.md) reach the shader unchanged in both. |
| Colour of shader output (unshaded `ALBEDO`, vertex colours used as colour) | Encoded linear to sRGB on output | **Written out as-is** | Unshaded `ALBEDO = vec3(0.5)` reads back #bcbcbc on desktop and #808080 on web; unshaded `ALBEDO = COLOR` reads #e98466 vs #d03b20 (desktop = sRGB encoding of the web value). A lit toon ground with a `source_color` albedo matched exactly (luminance 0.91 in both). | **Design change.** Colours computed in a shader look brighter and paler on desktop than on web. Tune on web, and in Forward+ only apply `srgb_to_linear()` to shader-made colours behind `#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS`. Check each effect with a desktop-vs-web pixel comparison. |
| Full-screen post pass (3D quad, `POSITION = vec4(VERTEX.xy, 1.0, 1.0)`) reading the screen texture | Works; values are **linear** | Works; values are **sRGB-encoded** | Pass A samples the known background colour and reports which encoding matched | Read the screen texture with a renderer-gated decode (`#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` = sRGB values) before doing colour maths, or the Kuwahara/paper look differs between builds. |
| Depth texture in a 3D post pass | Works | Works | Linearised depth at the screen centre compared with the analytic camera-to-ground distance; also drives a full-screen depth Sobel (`post_depth_edges.gdshader`, `blend_mul`) | NDC must be gated: Compatibility `vec3(uv, d) * 2.0 - 1.0`, Forward+ `vec3(uv * 2.0 - 1.0, d)`. Both variants are in `post_probe_a.gdshader`. |
| Second 3D screen-reading pass sees the first pass's output | **No** | **No** | Pass B (higher `render_priority`) samples pass A's magenta marker and gets the old background | Do not chain 3D quads. |
| Canvas pass (ColorRect in a CanvasLayer) reads the 3D frame including 3D post passes | Yes | Yes | Canvas pass samples pass A's marker | |
| Canvas pass chained after another canvas pass, **without** BackBufferCopy | No | No | Second ColorRect samples the first one's cyan marker | |
| Canvas pass chained **with** a BackBufferCopy (COPY_MODE_VIEWPORT) in between | **Yes** | **Yes** | Same, with the copy node between | **Post chain:** one 3D quad for everything that needs depth (Kuwahara colour plus depth/normal Sobel darkening, since that only needs depth), then canvas ColorRects separated by BackBufferCopy nodes (watercolour edge darkening on the Kuwahara result, then paper/grain/vignette). Canvas screen texture holds sRGB-encoded values in **both** renderers. SubViewport chains were not tested. |
| `hint_normal_roughness_texture` | Works (normal matches the ground) | Not available; declared only under `#if CURRENT_RENDERER != RENDERER_COMPATIBILITY`, so the web build shows the gated fallback (yellow tile) | Normal at the centre vs the expected view-space ground normal | Gate the uniform as in `post_probe_a.gdshader`. An ungated declaration was not tried in the web build, so whether it errors or silently reads black is unverified. |
| Normal reconstructed from depth | Works | Works | Cross product of view positions 4 px apart vs the expected ground normal | Use this on web (and on desktop unless the gated real buffer is clearly better). |
| Decal node (blob shadow) | Works (luminance 0.43 vs ground 0.91) | **Draws nothing** (0.91 vs 0.91), no error | Decal with a radial texture on bare ground | Confirmed: do not use Decal. |
| Blob shadow as an alpha-blended quad | Works (0.61) | Works, **darker** (0.42) | Unshaded quad with radial alpha, same parameters | Use it, but tune its alpha on web: Compatibility blends in sRGB space, so translucent things come out darker than on desktop. |
| GPUParticles3D | Works (~300 particle pixels) | Works (~300) | Orange billboards, pixel count near the emitter | Either works. |
| CPUParticles3D | Works | Works | Blue billboards | |
| Pre-rendered audio after the first click | Plays (`playing` true, position 0.46 s after 0.5 s) | Plays: the page's AudioContext is `suspended` before the click and `running` 1.5 s after it (currentTime 1.4 s); `AudioStreamPlayer.playing` is true but `get_playback_position()` stays 0.00 | WAV from `tools/gen/phase0_audio.py`, played on first mouse press | Works. In the default web playback mode (Sample) the playback position is not reported, so do not drive gameplay or music sync from it. Not listened to: headless runs prove the audio graph runs, not that sound came out of speakers. |
| Mouse capture / pointer lock | Works (`MOUSE_MODE_CAPTURED`) | Works after a click: `Input.mouse_mode` captured and `document.pointerLockElement` set (headless Chrome) | Capture requested on the first press, released 0.5 s later | Only request capture from a click handler on web. Escape release / lost-focus handling not tested. |
| `get_tree().paused` with one node still processing | Works (paused node +0 frames, ALWAYS node +40 to +52) | Works (+0 / +58) | Two spinning cubes, one PAUSABLE and one ALWAYS, frame counts over 0.4 s | Use as the brief describes. |
| Pressure on `InputEventMouseMotion` | Real OS mouse moves: pressure 0.00 in all 33 events, tilt 0 | Synthetic **pen** events (Chrome DevTools, pointerType pen, force 0.3 to 0.9): pressure 0.00 to 0.90 arrives; tilt does not (0) | Desktop: PowerShell `mouse_event` moves over the window. Web: CDP `Input.dispatchMouseEvent` | A mouse gives no pressure, so stroke width must come from speed, with pressure as an optional extra. **No real pen was tested on either platform**; desktop pen support is unverified. |

## Dark values on web (measured by the render workstream)

On web, every 3D pass darkens values below about 56/255 (8 becomes 1, 16 becomes 12, 24 becomes
21, in /255). Measured on the RTX 3080 only. `ink_out()` in `shaders/render/ink_common.gdshaderinc`
pre-compensates, so **every spatial shader must write its colour through `ink_out()`**; shaders
that do not (including lit StandardMaterial3D) lose a few levels in their darkest tones in the
browser. Proof: `scenes/dev/render_probe.tscn`, logs in `docs/render/probe_*.txt`.

## Performance and loading (trivial scene)

- Desktop: about 140 fps (vsync, 144 Hz display); first frame 2 to 3 s after launch, 17 s on the
  first launch in a fresh worktree (import plus a cold shader cache).
- Web: 144 fps (requestAnimationFrame and Godot both report 144, display-capped). First frame
  11.2 s after navigation with a fresh browser profile, 4.0 s on a warm reload in the same
  profile, 25 s while three other Godot/Chrome runs were going. Cold breakdown from the engine's
  own clock: about 3.5 s to download and start the 39.5 MB wasm, 3.7 s of engine start-up before
  the boot script runs, 4.0 s from boot to the first frame. On the warm reload the last two shrink
  to 0.2 s and 0.5 s, which points at shader compilation (cached by Chrome's GPU program cache)
  as the main cold cost. Every smoke check uses a fresh profile, so its numbers are cold numbers.
- The python server sends no compression. A real host should gzip/brotli the .wasm.

## What this changes in docs/BRIEF.md

1. Colour handling differs between the renderers (see the colour rows above). "One shader
   codebase" needs a small shared helper for screen-texture decode and shader-made colours,
   gated on `CURRENT_RENDERER`, and tuning has to happen against the web build.
2. The post chain shape is fixed by measurement: one 3D pass that uses depth, then canvas passes
   separated by BackBufferCopy. 3D quad chains do not work in either renderer.
3. Decal and normal-roughness texture limits are confirmed as the brief expected; the blob quad
   and depth-reconstructed normals work in both.
4. The cold web load is about 11 s on this PC, so the title screen needs a loading state.
5. Translucent effects (blob shadow, ink washes, petals) blend darker on web.
