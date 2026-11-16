# Project brief: living-ink vertical slice

This file is the single source of truth for every thread working in this folder.
The lead thread (OKAA-1) owns it. If something here conflicts with a thread prompt, this file wins;
if something here turns out to be wrong or impossible, tell the lead instead of working around it.

## Goal

A small, ORIGINAL, playable vertical slice in Godot 4.7.2 (GDScript, text-based .tscn / .gdshader files)
whose look emulates a mid-2000s Japanese sumi-e "living ink painting" action-adventure.
It must be playable in a desktop browser (Chrome) from a static web export, and run on desktop.

- Protagonist: an original paper-spirit fox.
- Setting: an original misty river valley.
- Slice scope: title screen, one cursed valley, two enemy types, three brush glyphs,
  a restore-the-great-tree finale.

## Hard rule: originality

Invent every character, creature, name, story beat, piece of music, UI string, glyph and texture.
Use no names, characters, logos, glyphs, or ripped/copied/traced art or audio from any existing game,
studio, or franchise. The banned-term list lives in the crew rules, not in this project; no file in
this project may contain a banned term. The folder name on disk is not the game's title: give the game
its own invented title and use that in project.godot, the title screen, and the README.
No third-party art, fonts, audio, or shader code with unclear licences. Fonts must be openly licensed
(record the licence) or generated; everything else is made here.

## Renderer decision (read this first)

The request says Forward+, and it also says playable in the browser. Godot's web export only supports
the Compatibility renderer (WebGL 2). Decision:

- project.godot: `rendering/renderer/rendering_method="forward_plus"`, with
  `rendering/renderer/rendering_method.web="gl_compatibility"`.
- One shader codebase that works under BOTH renderers. The web build is the acceptance target;
  a feature that only works in Forward+ does not count as done.
- Known Compatibility limits to design around (verify each against the 4.7 docs before relying on it):
  no CompositorEffect / RenderingDevice passes; no Decal nodes; no normal-roughness screen texture;
  limited environment post effects; web audio cannot do procedural generation in its default
  playback mode. Depth and screen textures are readable from spatial shaders.
- Consequences: post chain = full-screen shader passes (quad / canvas / SubViewport chain), blob shadow =
  shaded quad or mesh under the character, interior-crease Sobel = depth plus normals reconstructed
  from depth (use the real normal buffer in Forward+ only if it is gated cleanly), all audio pre-rendered
  to files.
- Web export: single-threaded (no cross-origin isolation headers needed), output `build/web/index.html`,
  with a one-command local server script.

## Rendering stack (each item is an acceptance check)

1. Toon material: 3-band stepped ramp, flat hand-painted albedo, near-shadowless lighting
   (soft blob shadow under characters); colour carries form.
2. Ink outlines: inverted-hull `next_pass` extruded in clip space; width modulated by world-space noise
   plus a Blender-painted vertex-colour weight (thick-thin taper, dry-brush gaps, slight wobble).
   Plus a depth/normal Sobel pass for interior creases.
3. Post chain: light Kuwahara (radius 2-3), watercolour edge-darkening and pigment blotches,
   rice-paper fibre texture multiply, subtle grain, warm parchment vignette.
   Paper intensity setting: Light / Normal / Heavy, selectable in-game.
4. Palette: muted, desaturated ivory / sage / stone base; vermilion and gold accents for sacred and
   interactive objects. Cursed zones: black ink blots under red light that restore to full colour
   with a burst of petals.
5. VFX: enemies dissolve into ink splashes, dry-brush ribbon slash trails, flowers sprouting in the
   player's wake, swirled stylised clouds, wind and water.
6. Motion: character animation stepped at 12 fps with smear frames on attacks; camera-facing card
   foliage; third-person orbit camera with gentle lag.

## Brush mechanic

- Holding a button freezes the world (`get_tree().paused = true`; the brush layer keeps processing)
  and fades the screen to sepia scroll paper with the frozen scene faintly visible.
- The player paints with mouse or pen; stroke speed / pressure sets width; an ink-pot meter limits use.
- On release, recognise the glyph with a $1 / $Q unistroke recogniser:
  circle = bloom, horizontal line = slash, loop = gust.
- Raycast the stroke into the world to apply the effect where it was drawn.
- Each glyph must be needed at least once to finish the slice. Unrecognised strokes fail gracefully.
- Must work in the browser with a mouse (pointer lock, focus, and right-click behaviour handled).

## Assets and audio

- Blender, headless, driven by Python scripts kept in the project (`tools/blender/`): low-poly
  (< 5k tris per model), flat-shaded, 1-2K painted albedo, vertex colour for outline width,
  exported as glTF 2.0 into `/assets`. Keep generator scripts so every asset is reproducible.
- Paper and brush textures: procedural or original PNGs, generated by scripts kept in the project.
- Music and SFX: original, pre-rendered to audio files by scripts kept in the project.

## Deliverables

- Runnable Godot project in this folder, plus the web export in `build/web/`.
- README.md: what it is, how to run (desktop and browser), full controls, glyph guide, credits/licences.
- Documented shader parameters (every uniform: meaning, range, default) in `docs/SHADERS.md`.
- Screenshots at each paper intensity (Light, Normal, Heavy), captured from the real game, in
  `docs/screenshots/`, and embedded in the README. At least one set from the web build.

## Definition of done (QA signs each line with evidence)

1. Fresh Godot 4.7.2 opens and runs the project on desktop with no script errors.
2. `build/web/` served locally loads in Chrome with no console errors and is playable from the title
   screen to the finale with mouse and keyboard, at a playable frame rate at 1280x720.
3. All six rendering-stack items are visibly present in the web build, not just in Forward+.
4. The brush mechanic works end to end in the web build: freeze, sepia fade, paint, ink meter,
   three glyphs recognised and applied in the world.
5. Both enemy types can be fought and dissolve into ink; cursed zones restore with petals;
   the great tree restoration finale plays and the slice ends cleanly.
6. Every model is under 5k tris and came out of the Blender scripts; every texture and sound came out
   of a script or is an original file made here.
7. Originality audit passes: banned-term scan of every file is clean and nothing is derivative.
8. README, docs/SHADERS.md, and the three paper-intensity screenshots exist and match the build.

## Working in this folder

- The top-level folder is the `main` checkout; only the lead (OKAA-1) writes there.
  Each workstream works in its own git worktree, `.worktrees/<name>/`, on branch `ws/<name>`,
  and writes only inside the paths docs/CONTRACTS.md gives it. The lead merges into main.
- Shared files (project.godot, the boot scene, autoload list, input map, export presets,
  scripts/core/) belong to the lead; ask for changes with the exact edit.
- Third-party tools (Godot, export templates, Blender, Python venv) live in `.tools/` at the
  top level only, never system-wide. `.tools/`, `.worktrees/` and `.godot/` stay out of git.
- The lead pushes `main` to the project's private GitHub repository. Nobody else pushes, and
  there are no pull requests.
- Never claim something works without having run it. Report what you ran and what you saw.
