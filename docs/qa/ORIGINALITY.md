# Originality audit

Owner: QA. Searched on 2026-11-14 (Book One names on 2026-11-15; Tallowford cast on 2026-11-15 from docs/levels/tallowford/DESIGN.md and SCRIPT.md; Levels 3 to 5 on 2026-11-16 from their DESIGN.md and SCRIPT.md) with a general web search for each invented name, in quotes and
with "game". The banned-term scan (the lead's list, passed at run time) is a separate check:
`tools/qa/qa.sh terms`.

Verdict: PASS

Signed by QA on 2026-11-16 at main aa3946b, the five-level Book One. No name a player sees collides
with the reference game, and the built cast, enemies, boss and sets are our own shapes. The new
clouds (F-015) are torn wash bands with no spiral, so that finding is closed. One borrowed phrase is
left in our own docs and file names, not in the game's text: "guardian sapling" (F-018, below). It
is the reference game's exact English term for the tree the hero blooms to lift a curse from an
area, so the rename is asked; the player only ever reads "the sapling on the Knoll". The Ink-maker
stays by the lead's decision. If the lead wants F-018 fixed before signing, set this line to OPEN.

## Name search

| Name (CONTRACTS.md) | What the search found | Collision | Severity |
| - | - | - | - |
| The Spill (the curse; replaced an earlier name, F-004) | "The Spill" is a $1.99 itch.io game about a cargo hauler (Thorium 90 Productions); otherwise an everyday word. Sources: thorium90productions.itch.io/the-spill | Title only, different subject | Low |
| Splotchet (small hopping blot; replaced an earlier name, F-004) | Nothing by this name; "Splotch!" is a browser platformer and a board game, different word | None | Low |
| Reedwraith | No game. Appears in fantasy name-generator lists and a fiction blog ("Reedwraiths", Faylinn Defence Group, May 2025) | No game collision | Low |
| Orimi | A Tokyo fashion label (Kenta Orimi), a jewellery brand, an Egg Cave pet name, a design thesis. No game | No game collision | Low |
| Orimi: The Unfaded Vale | Nothing beyond the fashion label | None | - |
| Hazewater Vale / Hazewater | Hazewater is a nature area and street name in the Netherlands; no game | None | - |
| The Lull (the river) | An everyday word; a short story title; no game or fantasy place found | None | - |
| Thousand-Ring Camphor | Real great camphor trees at Japanese shrines, none with this name; no game | None | - |
| Soot bank, thorn gate, withered sapling | Generic phrases; nothing game-specific | None | - |
| Old Trim (Tallowford lamp-maker; replaced a name that collided with a lamp-keeper NPC in a 2026 game, F-012) | Only home-repair pages ("old trim" on houses and lamps); no game character | None | Low |
| the Ink-maker (maker of the ink at the river's head) | Bendy and the Ink Machine has an "Ink Maker": a machine that turns thick ink into items (Chapter 4). Ours is a person and a plain description. Source: bendy.fandom.com/wiki/Ink_Maker | Same words, different thing, in a well-known ink-themed game | Medium; the lead keeps it (F-012 closed) |
| Tamsin (Level 3 mapmaker) | A common given name; no game mapmaker or game character of note found | None | Low |
| The Dregs (Level 5 boss) | Conan Exiles has a dungeon called "The Dregs" with a boss at its end. Source: forums.funcom.com "The Dregs Dungeon" | Same name, a dungeon not a creature, different genre; the lead keeps it | Low |
| The Hollow Kiln (Level 5) | A murder-mystery word-search book title and a ceramics product; no game | None | Low |
| Tallowford (Level 2) | "The Tallow Chandler of Tallowford", a 15,000-word self-published ebook (MR SAQLAIN PRODUCTIONS, on XPlay) about a candle-maker's family in a town of that name; no game. Source: xplay.mrsaqlainproductions.com/games/the-tallow-chandler-of-tallowford | Same name and a similar craft (candles, lamps), but an obscure ebook, not a game | Low |
| Sedge Plain (Level 3) | Plant-catalogue phrase only | None | - |
| Mosswater Wood (Level 4) | A healing-arts studio and nature-reserve pages; no game | None | - |
| Pell (raft ferryman) | No game character found (Raft's cast has other names) | None | Low |
| Fenn (charcoal-burner) | No game character found; "charcoal burner" is a building in other games | None | Low |
| Marrow (dyer), Brindle (well-keeper) | Everyday words; no game characters found by these searches | None | Low |
| Flax, Pibbet (the children, Tallowford) | Flax: an everyday word, no game child of that name found. Pibbet: a gnome name in a name generator only | None | Low |
| Aunt Wherry (ferry-keeper, Tallowford) | No hits for the name; ferrymen in Sea of Thieves, Castlevania and Ultima have other names. A wherry is a kind of boat | None | Low |
| The baker, the net-mender, the old fisher | Plain descriptions | None | - |
| lamp gold (Tallowford's bead) | Plain description | None | - |
| Wenna (Hollow Kiln kiln-keeper) | A given name. Two World of Warcraft NPCs (Wenna, Wenna Silkbeard), a Spruted fan character, a quest item in Monsters and Memories; none a kiln-keeper or a main character | Common name, minor NPCs elsewhere | Low |
| the Sootflit (Mosswater flyer) | No hits beyond name-generator pages | None | - |
| guardian sapling (Sedge Plain: DESIGN.md, LEVELS.md, props/guardian_sapling.tscn) | The reference game's exact English term for the saplings the hero blooms to restore a cursed area, with its own wiki page and soundtrack track. In the game text ours is only "the sapling on the Knoll" (level.json) | Same words for the same mechanic, in docs and file names only | Medium (F-018) |
| The Waking, The Lamps of Tallowford, The Mapmaker's Road, The Three Still Ponds, What the Vat Kept (chapter titles) | "The Waking" is a common chapter phrase (a tabletop rulebook chapter, not a game level). "The Mapmaker's Road Under the Water" is a 2026 short story on a horror fiction site. The other three: no game, book or level of that name | No game collision | Low |
| Leaning Stones, the Mere, the Seam, the Knoll, Kettle Hollow, Ladle Hollow (Sedge Plain places) | "Leaning stone" is a furniture item in Animal Crossing and a scene name in an interactive-fiction site; Kettle Hollow is a real place and ranch name; Ladle Hollow only finds kitchen ladles. The Mere, the Seam, the Knoll are everyday words | No game collision | Low |
| Lily Reach, Wheel Pond, Willow Pool (Mosswater places) | Real fishing ponds and a pool in a park; "Willow Pool" is a book and a scene in a dating game (a character named Willow at a pool) | No game collision | Low |
| sedge green, water indigo, kiln vermilion (beads) | Plain colour descriptions (a jazz bassist named Sedge Green; teapot listings; an itch.io game "Indigo Water") | None | - |
| verse-stones | A "Forbidden Verse Stone" is an item in Tales of the Abyss | Similar phrase, different use (ours teach glyphs) | Low |

**Concept overlap (not a name collision):** paper-fox protagonists already exist in small games
and apps (Paper Fox: The Last Fold, a browser game; Oinari Origami, a game-jam platformer; The Paper
Fox, a 2013 storytelling app). Orimi's design (folded shrine paper, cord and bead) is distinct from
what those pages show, but the art should be compared once it exists.

## Mechanics and glyph names

The brief itself asks for the reference game's core gestures: a circle that makes a withered tree
bloom, a horizontal line that cuts, a loop that makes wind. In the reference game, two of those
techniques carry the same English names our glyphs use ("Bloom" and a "... Slash"). The names are
ordinary English words, so the banned-term scan does not flag them, but together with the identical
gesture-to-effect mapping (circle around a dead tree = bloom) a reader could call this derivative.
The lead has decided: Bloom, Slash and Gust stay (docs/LEVELS.md, "Names that changed").

The two new glyphs repeat the pattern. Kindle lights lamps and braziers, and Tie joins two posts
with a drawn line to cross a gap; the reference game has a fire technique and a technique that
draws a line between two anchor points to pull the hero across. The names differ from the
reference's, but the gesture-to-effect pairs are close. Recorded for the lead (F-005); no change
asked.

## Design review (STYLE_GUIDE.md "Ours, not theirs")

Reviewed on 2026-11-15 against docs/assets/{fox_front,fox_brush_pose,splotchet,reedwraith,folk_web_woken}.jpg
and the browser captures in docs/qa/stack/ and docs/screenshots/.

- [x] Orimi: ivory folded paper with crease lines, grey paws, a vermilion cord with a gold bead at
  the neck; no painted body markings, no emblem, nothing floating on the back, the tail is paper
  planes and not a brush
- [x] Enemies read as ink that took shape: the Splotchet is a black blot with two pale eyes; the
  Reedwraith is a grey veil topped with reeds; neither is a masked demon
- [x] Dialogue and prompt panels are torn paper (docs/qa/stack/), not scrolls with rollers
- [x] Glyph icons are our own shapes (a plain circle on the prompt card)
- [x] Sealed fight (Tallowford jetty, docs/levels/tallowford/shots/fight_v5.jpg): a black ink ring
  with a red rim around the paving; no floating script. The torn-paper screens the style guide
  names are not visible in that capture.
- [x] Tallowford buildings, lamps and cast (play_04_trim_lit.jpg, restored_v8.jpg, the folk
  wrappers): timber houses with paper screens and hanging lanterns are generic rural architecture,
  not a copy of a reference location; the folk are our generator's shapes.
- [ ] Clouds (F-015): the sky's clouds are stacked round white puffs topped with tight spiral curls
  (play_04_trim_lit.jpg, restored_v8.jpg). The style guide asks for our own curl drawn as a
  tapering brush stroke; these read close to the reference game's signature cloud.
- [ ] Concept note, no change asked: villagers standing grey and still until the hero restores
  their lamp is close to the reference's villagers frozen by the curse and revived. The mechanism
  (lamps, not a glyph on each person) and the look differ.
- [x] Clouds (F-015, closed 2026-11-16): the new cloud atlas (docs/vfx/clouds_f015/atlas_preview.jpg)
  is torn-edged wash bands with one dry-brush underline and no curl at all; the before and after
  captures (tf_restored_before_after.jpg, hz_before_after.jpg) show the round puffs with spiral caps
  gone from the sky. Confirmed in the gate run on 940acaa: the Tallowford sky in
  docs/qa/evidence/web_resume_continued.jpg shows the new bands.
- [x] Wind curl (assets/textures/vfx/curls.png, the Gust trail): eight frames, each one tapering stroke
  that starts with a hard pointed head and breaks into dry-brush bristle lines as it bends. Six end in
  a half to three-quarter hook; two (heavy frames 0 and 4) close into about one turn with a broken
  inner arc. That is the style guide's "our own curl, a tapering brush stroke, not a smooth vector
  spiral". It is a single short stroke on the Gust trail, not a cloud cap, so it does not repeat the
  shape F-015 removed. No change asked.
- [x] The Dregs (docs/levels/hollow_kiln/shots/web_vat.jpg, the gate's web_perf_kiln_fight.jpg): a
  slumped grey mound of faceted ink with two pale thumbprint eyes in a banded barrel vat on chains.
  Nothing like a many-headed serpent, a masked demon or an armoured spirit; it fights from one place.
- [x] The Dregs' fight shape: four parts, each answered by one glyph in the order taught (Gust takes
  the veil, Slash cuts the arms, Tie binds it between pillar rings, Kindle dries it at three kiln
  mouths), then a Bloom on the vat. A boss weak to the brush is the reference's pattern, and also the
  general boss pattern of tool-gated adventure games; the parts, the binding rope and the drying are
  ours. Concept note, no change asked.
- [x] Wenna (keeper.jpg), Tamsin, Fenn: folk-generator figures (blocky robe, apron, bucket), grey until
  woken, as in Levels 1 and 2. No resemblance to the reference's villagers beyond being folk.
- [x] Sedge Plain set pieces: map leaves blown by wind, a mapmaker's camp, two broken rope bridges
  mended with Tie, soot causeways blown clear, standing stones over a mere. None is a reference
  location. Concept note: the level's goal, "bloom the sapling on the Knoll and the whole plain is
  restored", is the reference's area-restoring sapling loop (see F-018 for the name). The brief asks
  for the bloom gesture, and Level 1 already does the same with its great tree.
- [x] Mosswater set pieces (the gate's web_perf_mosswater_lit.jpg): a dark wood lit by lantern-fruit,
  three ponds stepped by a weir, a dam and a waterwheel, a charcoal-burner's hut, a soot-winged flyer
  that circles, dives and is knocked down. Lighting lamps in the dark with a fire glyph is a common
  puzzle (Zelda torches, the reference's fire technique); the fruit, the ponds and the wheel are ours.
- [x] The Hollow Kiln: a climbing kiln works in a gorge (yard, drying hall, flue, beehive-domed vat
  chamber). The ending, a tree grown up through the dome restoring the valley in colour
  (ending_tree.jpg), echoes the brief's own "withered tree blooms" image; the dome, flue and vat are
  ours.
