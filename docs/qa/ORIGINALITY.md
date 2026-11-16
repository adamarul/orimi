# Originality audit

Owner: QA. Searched on 2026-11-14 (Book One names on 2026-11-15; Tallowford cast on 2026-11-15 from docs/levels/tallowford/DESIGN.md and SCRIPT.md) with a general web search for each invented name, in quotes and
with "game". The banned-term scan (the lead's list, passed at run time) is a separate check:
`tools/qa/qa.sh terms`.

Verdict: OPEN

The verdict stays OPEN while the cloud shape (F-015) is open and while levels 3 to 5 (their
cast, the Dregs, the flyer) are not built. The Ink-maker stays by the lead's decision. Everything built so far passes the design
review below.

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
- [ ] Levels 3 to 5 (their people, the Dregs, the soot-winged flyer): not built yet
