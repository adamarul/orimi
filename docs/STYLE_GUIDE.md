# Style guide

The visual target for every workstream. It was written from a study of PS2-era captures of the
ink-painting action-adventure this slice takes its look from, plus published breakdowns of how
that look was built. The captures live in `.reference/` at the top level for study only: that
folder is git-ignored, is never shipped, and nothing in it may be copied, traced, sampled or
used as a texture source. This guide records technique, proportion and colour behaviour, which
is what we emulate. The subject matter is ours.

Sizes are given as a fraction of screen height (%H) so they hold at any resolution.
At 720p, 1 %H is about 7 px.

## What makes the look, in order of importance

1. **Ink does the drawing, colour does the filling.** Form is described by black brush lines,
   not by lighting. Fills are flat washes. If you squint and the image still reads from its
   lines alone, it is right.
2. **The lines are painted, not plotted.** Weight swings from hairline to very heavy inside a
   single stroke, strokes taper to a point, and they break up where the brush ran dry.
3. **Everything sits on paper.** A pebbled paper tooth is visible in every flat area, bright
   areas show it most, and distance fades to the paper's colour rather than to blue haze.
4. **Colour is rationed.** Most of the frame is muted. Saturated colour appears only where it
   means something, so it lands hard when it does.
5. **It is soft.** The original output was low resolution and slightly blurred with a gentle
   glow on bright areas. Crisp, aliased, high-frequency detail breaks the illusion.

## Lines

| Where | Weight | Character |
| - | - | - |
| World silhouettes: trunks, branches, rocks, cliffs, posts | 1.5 to 4 %H at mid distance, never uniform | Pure ink black. Heavy on the underside and the side away from the light, thinning to nothing on the lit side. Ends taper to points. |
| Character silhouettes | 0.5 to 1.2 %H | Softer than the world: dark warm grey rather than pure black, broken in places, heavier under the belly, jaw, ears and tail. |
| Interior creases | 0.2 to 0.5 %H | Thin, slightly brown, wobbly, often not quite closed. Used sparingly: three or four strokes describe a whole rock face. |
| Distant landforms | one contour stroke plus a few crease strokes | Pale wash fill; the line is greyer and thinner with distance. |

- **One-sided weight is the signature.** A branch reads as a pale fill with a fat black stroke
  along its lower edge, not as a shape with an even border. Drive hull width by how much the
  surface faces away from a fixed "brush light" (up and slightly toward the camera's left), on
  top of the vertex-colour weight and noise.
- **Taper.** Width falls to zero toward thin extremities and stroke ends. This is what the
  painted vertex-colour weight is for: paint it to 0 at tips.
- **Dry brush.** Gaps and streaks appear near stroke ends and where weight is low. Break the
  line with a streaky noise stretched along the stroke, not with dots or dither.
- **Wobble.** Lines breathe. Re-seed the width and offset noise at 6 to 8 times a second
  (stepped, never smooth), amplitude no more than about 15% of the local width.
- **Motion drags the ink.** On fast movement the black strokes smear a little behind the
  character while the fill stays put. Reserve it for attacks and dashes.
- Hull outlines show seams where meshes intersect the ground. Hide them the way the original
  did: paint a dark ragged contact stroke into the ground texture or bury the base.

## Painted textures (albedo)

- Fills are flat, with large soft wash variation only: blotches 0.3 to 1 m across, within about
  ±5% value of the base. No gradients, no ambient occlusion, no photographic noise, no
  per-pixel detail.
- **Draw with ink inside the texture.** Rock: a handful of bold tapered crack strokes. Bark:
  long strokes following the trunk. Ground: scattered dark tick marks for grass tufts. Paths:
  a paler sandy fill with ragged dark ticks along both edges, as if the brush skipped.
- Trees are calligraphy: black trunk and branches with tapered ends, foliage as fan-shaped
  clusters of single green brush strokes on camera-facing cards. No leaf-by-leaf modelling.
- Dead or cursed trees are pure black gnarled silhouettes with no fill at all.
- Texture edges are slightly irregular: fills stop a hair short of the line or spill past it,
  as wash does.

## Shading and shadow

- Characters are almost flat. The three bands are subtle: the shadow band is only about 10%
  darker and slightly cool, the highlight band barely lifts. No specular, no rim light.
- The environment gets its form from painted strokes, not from the light. Keep the ramp
  contrast low enough that turning the light barely changes the picture.
- No cast shadows. One dark blob under each character: near black at 70 to 80% strength, an
  ellipse about the body's footprint, firm edge with a slight feather, sitting on the ground.

## Paper

- The dominant texture is **paper tooth**: a fine pebbled emboss, as if lit from the upper
  left, cell size about 0.5 %H, shifting luminance by a few percent. It is a relief, not a
  print: build it from the slope of a noise height field, not from flat speckle.
- Under it, **large uneven staining**: soft blotches 15 to 30% of the screen wide, a few
  percent warmer and darker, strongest toward the corners.
- **Fibres** are sparse and secondary: a few short pale and dark hairs, not a weave.
- Paper shows most in bright flat areas (sky, mist, sand, the fox) and nearly vanishes in ink
  black. Scale it by luminance.
- The texture is fixed to the screen, not the world. It must not swim when the camera moves.
- Suggested mapping for the three settings: Light is tooth only, barely visible; Normal adds
  the staining and a mild warm vignette; Heavy doubles the tooth, adds fibres, deepens the
  vignette and stain, and lowers overall saturation a little.

## Colour

- Base: olive-leaning sage greens, ochre and sand, grey stone, all muted. Skies are a flat pale
  wash (pale blue-grey to off-white) with the paper showing through; clouds and far ridges are
  outline drawings on that wash.
- Distance fades toward paper ivory. Fog colour is paper colour.
- Accents, at full saturation: vermilion for sacred structures and cords, gold for trim and
  things the player can act on, petal pink for restoration. Nothing else is saturated.
- Restored ground is a livelier, cleaner green than the muted base, with flowers and pale
  sparkle; the contrast between drained and restored land is the emotional payoff, so keep the
  drained state genuinely grey-olive and dull.

## Cursed ground

- From a distance a cursed zone is an **opaque black mass with a feathered crimson rim**:
  the rim is 1 to 2 %H thick, glows, and creeps slowly. It hugs the ground and climbs objects.
- The sky above it is drained toward bare paper. Inside, ground is desaturated grey with ink
  blots pooling in it, trees are black silhouettes, and the only colour is red light.
- Restoration is a hard wipe, not a fade: a ragged front races outward from the centre,
  full colour behind it, a ring of flowers and petals riding the front.

## Effects

- **Petals:** chunky flat five-sided flecks in two pinks with a white edge highlight, no
  outline, tumbling. Dozens, not thousands.
- **Sparkles:** small four-point stars with a soft halo, used on restored and sacred things.
- **Slash:** a pale grey-white arc with dry-brush streaking along its length, gone in about
  0.2 s. It reads as a brush mark, not a glow.
- **Ink deaths:** the body collapses into flat black splats with satellite droplets and a few
  thrown streaks, which soak away into the ground.
- **Water:** a flat blue-grey wash with white calligraphic ripple arcs and a faint network of
  bright cell lines drifting over it. No reflections, no refraction.
- **Wind and cloud:** curled strokes that start heavy and thin out as they spiral. Draw our
  own curl; keep it a brush stroke, not a smooth vector spiral.
- **Glow:** bright things carry a soft, wide, low-strength halo.

## Brush view

- The frozen scene turns into a monochrome sepia wash on paper: luminance kept at reduced
  contrast, darks becoming brown-black ink, lights becoming bare paper, with a darker
  vignette. It should look like an underpainting of the scene.
- Strokes are black ink with taper at both ends, width following speed and pressure, and a
  dry streaked edge when moving fast.

## Camera and framing

- Third person, behind and above: looking down about 15 to 20 degrees, field of view 55 to 60
  degrees, the fox about 15 to 18 %H tall on screen. The horizon sits in the upper third so
  the painted ground and its paths carry the composition.

## Interface

- Panels are torn paper scraps with a ragged ink edge; icons are hand-inked tokens. Text is
  dark ink on paper with one accent colour for key words.

## Ours, not theirs

The look is a technique; the content has to be our own. In particular, do not reproduce any of
these from the reference: a white animal hero with crimson body markings; a red disc emblem;
a divine-instrument weapon floating on the hero's back; a brush drawn as the hero's tail;
walls of floating red script around a battle; scroll-with-rollers dialogue boxes; any of its
creature, character or prop designs.

Orimi's identity comes from paper: warm ivory, visible fold creases as its interior lines,
sharp folded planes, ash-grey wash on the ear tips and paws, and a single vermilion cord with
a gold bead at the neck. No painted body markings. The on-screen brush is a plain ink brush
tip. Enemies are ink that has taken shape (blots, reeds, soot), not masked demons. Sealed
fights (docs/LEVELS.md) are ringed by a low wash of rising ink and standing torn-paper screens,
never by floating script.
