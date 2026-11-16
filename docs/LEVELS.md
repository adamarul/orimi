# Levels and story: Book One, "Upriver"

Five levels. Level 1 exists (the vale built as the first slice). Levels 2 to 5 are new.
Read docs/BRIEF.md, docs/CONTRACTS.md and docs/STYLE_GUIDE.md first; this file adds to them.
The lead (OKAA-1) owns this file.

## What the owner asked for

Levels that play like the opening hours of the game this project takes its look from: a hub
village where you help people one by one, an open plain with cursed ground and roaming fights,
a forest, then a ruin with a boss, each with a story beat. The structure and the mechanics
follow that model closely. The maps, story, characters, creatures and names are our own, and
the originality rule in docs/BRIEF.md applies to every one of them: search each new name before
using it, and copy no layout, character or line of dialogue from anywhere.

## Names that changed

QA found two collisions with existing games. From now on:

- The curse is **the Spill** (not the old name). Lower-case "the spilled ink" in running text.
- The small hopping enemy is the **Splotchet** (not the old name).

Three more, found by the level workstreams' own searches:

- The river is **the Lull** (the old name is a coined word from a series of fantasy novels).
- The mapmaker of Level 3 is **Tamsin** (the old name is a hero of one game and an item in another).
- The maker of the ink at the river's head is **the Ink-maker**, a plain description and not a
  title (the old name is the title of a game released this month).
- The lamp-maker of Level 2 is **Old Trim** (the old name is a lamp-keeping character in a
  game released this year; found by QA).

"Tallowford", "The Hollow Kiln" and "the Dregs" stay: plain words, no game of that name.

Gameplay renames classes, files, ids and strings; other workstreams follow after `git merge main`.
The glyph names Bloom, Slash and Gust stay: they are plain verbs and the owner chose them.

## The story

The Thousand-Ring Camphor kept the colours of everything along the Lull, the way a tree
keeps its years. Somewhere upriver the Spill began: a black so deep it drinks colour. It came
down the river and the vale went grey. Orimi, a fox folded from shrine paper, woke at the
riverside shrine with a brush that still remembers how colour goes.

Each place Orimi restores gives back one **remembered colour**, worn as a bead on Orimi's cord.
Five beads in Book One. Each bead also raises the ink pot's capacity.

The Spill was not sent by anyone. At the river's head stands a kiln where an ink-maker, the
**Ink-maker**, spent his life trying to grind a black that could hold every colour at once, so
that nothing he loved would ever fade. The vat cracked. What ran out was the Spill; what stayed
at the bottom is **the Dregs**, which is the boss of Level 5. The Ink-maker is long gone; his
story is told by the verse-stones he left along the river, one or two per level, which speak
when Orimi blooms them. The tone is gentle and a little sad, never grim. Nobody is evil.

**Pell**, a ferry child with a paper hat who poles a raft, carries Orimi from level to level
and is the one recurring voice: quick, practical, never explains the plot.

| # | Id | Name | Chapter | Bead | New here |
| - | - | - | - | - | - |
| 1 | hazewater | Hazewater Vale | The Waking | ivory | Bloom, Slash, Gust |
| 2 | tallowford | Tallowford | The Lamps of Tallowford | lamp gold | Kindle glyph; talking to people; the first sealed fight |
| 3 | sedge_plain | Sedge Plain | The Mapmaker's Road | sedge green | Tie glyph; ground that keeps you out; roaming fights |
| 4 | mosswater | Mosswater Wood | The Three Still Ponds | water indigo | climbing and water; a flying enemy; darkness lit by Kindle |
| 5 | hollow_kiln | The Hollow Kiln | What the Vat Kept | kiln vermilion | interior rooms and locks; the Dregs |

## Mechanics added for these levels

Gameplay builds these once, as the level kit (docs/LEVEL_KIT.md, written by gameplay); levels use them.

- **People and talk.** Characters you walk up to and talk with; short lines on a torn-paper
  panel, one accent colour for key words, advance with a click or key. People the Spill has
  reached stand grey and still, like unpainted cut-outs, until what they care about is restored.
- **Verse-stones.** Bloom one and it speaks four short lines of the Ink-maker's story.
- **Sealed fights.** A drifting knot of black cord marks a pack on the map. Touch it and a ring
  of ink rises around a circle about 10 m across until every enemy in it is gone. Our own look:
  a low ring of rising ink wash and standing torn-paper screens, not floating script.
- **Finishing stroke.** An enemy at zero health unravels for about a second and a half before
  it falls apart. A Slash through it in that window is a clean cut: extra ink and a burst of
  petals. Miss it and it dies normally.
- **Ground that keeps you out.** From Level 3, cursed ground hurts and pushes back. You cross
  it on safe causeways or not at all, and the way to the sapling is the puzzle.
- **Two more glyphs** (the brush workstream adds them):
  - **Kindle**: a dab, a short press on a wick. Lights lamps, braziers and lantern-fruit.
  - **Tie**: a straight line, at any angle, whose two ends land on two tie posts. Draws a rope
    of ink between them: a bridge, a pull, a binding. A line that does not join two posts is
    still a Slash if it is near horizontal.
- **Beads.** Finishing a level adds its bead to the cord and raises maximum ink.
- **Travel and progress.** Title screen with Continue and a level list; Pell's raft between
  levels; progress kept between sessions, in the browser too.

## Level 1: Hazewater Vale (exists)

Unchanged in layout. Additions once the kit exists: one verse-stone near the shrine, the
finishing stroke, the ivory bead on completion, and Pell arriving by raft after the Camphor
blooms ("I saw the colour from the ford. Come and see what's happened to my village.").

## Level 2: Tallowford, "The Lamps of Tallowford"

A village of lamp-makers at a river ford, at dusk. Every lamp is out. The people stand grey in
their doorways. The ferry cannot cross in the dark.

- **Goal:** relight the five house lamps and then the great ford-lamp.
- **Shape:** about 70 by 60 m. The Lull along the east side with a jetty and the
  ford-lamp on a post at the north-east; a square in the middle with a bare persimmon tree; five
  houses around the square; a dye yard to the west; a well to the south; the road in from the
  south, where Pell's raft lands.
- **Beats, in order.** Each wakes a villager, who points to the next.
  1. Old Trim, the lamp-maker, by his cold lamp. A verse-stone beside it teaches Kindle. Light
     his lamp: he wakes, and colour spreads a few metres from the lamp.
  2. Marrow the dyer: her vats are bound in ink thorns. Slash them, then Kindle her lamp.
  3. Brindle the well-keeper: the well is packed with soot. Gust it out, then Kindle.
  4. The children's house on the square: the persimmon tree is bare. Bloom it, then Kindle.
  5. The ferry-house by the jetty. Lighting its lamp draws the Spill out of the river: the
     first sealed fight, Splotchets and one Reedwraith, on the jetty square.
  6. The ford-lamp, hooded in soot. Gust the hood off, Kindle the wick. The whole village
     comes into lamplight colour, everyone gathers, Pell's raft can cross.
- **Story beat:** Old Trim remembers the Ink-maker buying lamp-black from him, more every year.
- **Feel:** safe, warm, small. The only fight is at beat 5.

## Level 3: Sedge Plain, "The Mapmaker's Road"

A wide windy plain of sedge and standing stones between the village and the wood. The Spill
lies in three hollows. Packs drift across the open ground.

- **Goal:** bloom the guardian sapling on the central knoll and restore the plain.
- **Shape:** about 120 by 100 m, gently rolling. A dry gully runs east to west across the
  middle with two broken rope bridges. Three cursed hollows; the largest surrounds the knoll.
  Entry from the south (raft landing), exit to the north-west (the edge of the wood).
- **People:** Tamsin, a mapmaker, camped at the south with an empty map frame. The wind took
  three leaves of her map; each lies beside a hollow.
- **Beats.**
  1. Tamsin explains the plain and marks the first leaf. Roaming packs: two or three sealed
     fights on the way, with the finishing stroke taught on the first.
  2. First bridge: a verse-stone teaches Tie. Join the two posts to cross the gully.
  3. Leaves two and three sit on islands of clean ground inside the smaller hollows; the
     causeways to them are buried in soot, and Gust uncovers them.
  4. With all three leaves Tamsin can read the way through the big hollow: a causeway, a second
     Tie across a break in it, and the knoll.
  5. Bloom the sapling. The restoration sweeps the whole plain, hollow by hollow.
- **Story beat:** Tamsin's finished map shows the river's course, and a blank where the kiln is.
- **Feel:** open, fast, the most fighting so far. Wind everywhere.

## Level 4: Mosswater Wood, "The Three Still Ponds"

Old forest: tall dark trunks, moss, a stream that falls through three ponds. The ponds have
gone black and still, and under the canopy it is nearly dark.

- **Goal:** set the three ponds moving again so the stream runs and the raft can go upriver.
- **Shape:** about 90 by 90 m with real height: the ponds step up the slope from south-east to
  north-west, about 6 m apart in height, joined by ledges, roots and leaf platforms.
- **People:** Fenn, a charcoal-burner who has lived here alone since the ponds stopped. Wary;
  helps more with each pond.
- **Beats.**
  1. The path in is dark. Lantern-fruit hang from the branches; Kindle them to see the way and
     to drive back the dark, which hides Splotchets.
  2. Lower pond: its paddle-wheel is clogged with soot. Gust spins it free.
  3. Middle pond: reached by blooming lily buds into leaf platforms across the black water,
     then a Tie to haul a fallen log into place. A new flying enemy lives here: something small
     and soot-winged that circles out of reach until a Gust brings it down.
  4. Upper pond: all four glyphs in one short climb, a sealed fight on the dam, then Bloom the
     old willow whose roots hold the spring.
  5. The stream runs through all three ponds; colour pours down the slope with the water.
- **Story beat:** Fenn sold the Ink-maker his charcoal. "He wanted a black you could fall into."
- **Feel:** vertical, quiet, a little eerie, then loud with water at the end.

## Level 5: The Hollow Kiln, "What the Vat Kept"

The Ink-maker's works at the river's head: a walled yard, a long drying hall, the flue, and
the vat chamber under the kiln's dome. The only level with interiors.

- **Goal:** reach the vat and end the Spill at its source.
- **Shape:** four connected spaces, each about 30 m across, climbing: yard, drying hall, flue,
  vat chamber.
- **Beats.**
  1. Yard: the gate is tied shut with ink cord (Slash) and its two braziers are dead (Kindle).
     A sealed fight in the yard.
  2. Drying hall: racks of grey paper, a floor of cursed ground with safe planks; bellows
     worked by Gust blow soot off the plank route; a counterweight door opened with Tie.
  3. Flue: a climb with ink rising slowly from below; bloom moss footholds, kindle lamps to see.
  4. Vat chamber: the Dregs.
- **The Dregs,** in four parts, each using one glyph, so the fight is the whole game in small:
  veiled in soot (Gust); it lashes with ink arms, which can be cut while extended (Slash);
  it climbs the vat's chains, and tying the two pillars binds it (Tie); the three kiln mouths
  must be lit to dry it out (Kindle). Then it unravels, and the finishing stroke is a Bloom on
  the cracked vat: a tree grows up through the kiln and the river runs clear from its roots.
- **Story beat:** the last verse-stones. The Ink-maker only wanted nothing to fade.
- **Ending:** all five beads; the valley seen from the kiln in full colour; Pell: "There's
  more river above the mountain, you know." End of Book One.

## How the level workstreams work

One workstream per new level: `l2` (tallowford), `l3` (sedge_plain), `l4` (mosswater),
`l5` (hollow_kiln), each in `.worktrees/<name>/` on branch `ws/<name>`.

Each owns, for its level id: `scenes/levels/<id>/`, `scripts/levels/<id>/`,
`assets/levels/<id>/`, `audio/levels/<id>/`, `tools/levels/<id>/`, `docs/levels/<id>/`.
Everything else is someone else's: use it, do not edit it.

Two phases:

- **Phase A (now, before the kit exists):** a level design document with a top-down plan and
  every marker; the terrain and every prop, building and character model the level needs,
  generated by scripts under `tools/levels/<id>/` using the shared painting and modelling
  helpers the assets workstream wrote (read docs/ASSETS.md); the complete script of the
  level's talk and verse-stones; and a look-dev scene that shows the place under the real
  materials, sky and foliage, clean and drained.
- **Phase B (when docs/LEVEL_KIT.md is on main):** assemble the playable level from the kit,
  with its own scripted autoplay route, proven in the browser from arrival to completion.

Budgets: every model under 5,000 triangles (split large terrain into several models);
textures 1K, 2K only for the main ground; a level adds no more than about 8 MB to the build;
the level holds a playable frame rate in the browser at 1280x720 with the full post chain.
