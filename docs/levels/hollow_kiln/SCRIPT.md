# The Hollow Kiln: script ("What the Vat Kept")

Every line of talk, narration and verse in Level 5. Generated from
`scripts/levels/hollow_kiln/kiln_script.json` by `tools/levels/hollow_kiln/script_doc.py`; edit the
JSON, then rerun. Markers are in DESIGN.md. Words between *asterisks* are key words: the talk panel shows them in its one accent colour (docs/LEVEL_KIT.md, section 3). Scene ids are the level.json lines keys: a Person with talk_id <id> plays <id>_faded while faded, <id> the first time awake and <id>_again after. Speaker 'narration' is unvoiced text on the panel with no name (who ""). Speaker 'verse' is a verse-stone: four lines, shown when it is bloomed.

## Speakers

- **Pell** (`pell`): Ferry child, paper hat. Quick, practical, never explains the plot.
- **Wenna** (`wenna`): Kept the kiln's fires for the Ink-maker. Plain, warm, tired; talks while she works.
- **Verse-stone** (`verse`): The Ink-maker's own words, carved and remembered. Four lines each.
- **narration** (`narration`): Unvoiced description.

## Beat 0

### `pell` (Pell, at M_Spawn, once)

*Talk to Pell on the landing (first talk). Phase B may play it on arrival, before control.*

- End of the river. Well. End of the bit I'll pole.
- That's the *kiln* up there, with the round hat on. All the black came down from it.
- I'll mind the raft. Shout if you need me. I won't hear you, but shout.

### `pell_again` (Pell, at M_Spawn)

*Talk to Pell again on the landing.*

- The gate's tied with ink. You're good with knots. Well, you cut them.

## Beat 1

### `verse_1` (Verse-stone, at M_Verse_1, once)

*Bloom verse-stone 1 on the landing.*

> I came up the river with a jar of black  
> and a fear of every colour going pale.  
> The mountain gave me clay, the stream gave water.  
> I built a kiln to make a black that stays.

## Beat 2

### `gate_look` (narration, at M_Gate, once)

*Orimi comes within 6 m of the gate while it is shut. Plays once.*

- The gate is tied shut with a cord of wet *ink*. The two braziers beside it are cold, their wicks still dry.

### `gate_half` (narration, at M_Gate)

*One of the gate's three locks is still on (the cord or either brazier) after the other two are done.*

- The gate shivers in its frame, and holds.

## Beat 3

### `wenna_faded` (narration, at M_Keeper)

*Talk to Wenna while she is faded (before the yard is restored).*

- A woman by the woodpile, as grey as the ash in her bucket. She does not look up.

### `wenna` (Wenna, at M_Keeper, once)

*The yard is restored (its sapling bloomed after the sealed fight): Wenna wakes, and speaks when Orimi talks to her. Plays once.*

- Oh. The logs are *brown*. I'd forgotten logs were brown.
- I'm Wenna. I kept his fires for twenty winters, till he sent me down to the yard and barred the hall.
- The hall floor's gone bad. Keep to the *boards*. Where the soot's buried them, the *bellows* still blow.
- The back door hangs on a counterweight. He always *tied* it off to the post. And mind the flue after. It fills.

### `wenna_again` (Wenna, at M_Keeper)

*Talk to Wenna again after she wakes.*

- He wasn't unkind. He was frightened of *grey*.
- He'd hold a page up to the window every morning, to see if it had faded in the night.

## Beat 4

### `hall_look` (narration, at M_HallDoor, once)

*Orimi steps onto the entry platform P0 inside the hall door. Plays once.*

- Racks of paper, every sheet grey. The floor between the boards *smoulders* with ink.

### `verse_2` (Verse-stone, at M_Verse_2, once)

*Bloom verse-stone 2 on the hall's entry platform.*

> Paper fades. The dyer's blue goes grey by spring.  
> I hung a thousand sheets to dry and watched them.  
> The ones I inked the deepest held the longest.  
> So I inked deeper. Then I inked the ink.

## Beat 6

### `counterweight_look` (narration, at M_TieAnchor, once)

*Orimi reaches the back aisle strip P3 while the door is shut. Plays once.*

- The door's weight hangs from a beam overhead. Below it stands a *post*, worn smooth by rope.

## Beat 7

### `flue_rise` (narration, at M_FlueEntry, once)

*Orimi enters the flue (M_FlueEntry). Plays once.*

- Somewhere below, the ink begins to *rise*.

### `flue_dark` (narration, at M_Flue, once)

*Orimi has stood on one ledge for 8 s with a lamp above still unlit. Plays once.*

- Too dark to see the next ledge. The lamps on the walls still have their *wicks*.

## Beat 8

### `verse_3` (Verse-stone, at M_Verse_3, once)

*Bloom verse-stone 3 inside the vat chamber door.*

> The vat drank lamp-black, charcoal, soot and night.  
> It grew too heavy to stir, and then to lift.  
> One morning something in the dark looked back.  
> I told it: keep. It was the only word it learned.

## Beat 9

### `dregs_wakes` (narration, at M_Arena_Entry, once)

*Orimi steps past M_Arena_Entry: the fight seals. Plays once.*

- Something in the vat breathes out *soot*.

### `dregs_hint_veil` (narration, at M_Vat, once)

*Part 1 has lasted 25 s with no Gust on the veil.*

- The soot round it *billows* like a curtain in a draught.

### `dregs_hint_arms` (narration, at M_Vat, once)

*Part 2 has lasted 25 s with no arm cut.*

- Each arm lies *still* a moment after it strikes.

### `dregs_hint_chains` (narration, at M_Vat, once)

*Part 3: the Dregs has reached the top of the chains once.*

- Each of the two *pillars* carries an iron ring.

### `dregs_hint_mouths` (narration, at M_Vat, once)

*Part 4: the binding has broken once.*

- Three kiln mouths, cold for years. Their *wicks* are still dry.

## Beat 10

### `vat_crack` (narration, at M_Vat, once)

*The Dregs has unravelled; Orimi comes within 6 m of the vat. Plays once.*

- The vat is cracked from rim to foot. Something *green* waits in the crack.

## Beat 11

### `verse_4` (Verse-stone, at M_Verse_4, once)

*Bloom verse-stone 4, which the tree's roots lift out of the floor.*

> It kept the river, the reeds, the faces. It kept them still.  
> Nothing faded, because nothing moved.  
> I was wrong about what stays. Colour stays by coming back.  
> Let the river run. Let it fade, and bloom.

## Beat 12

### `ending` (Pell, at M_Pell_End, once)

*The raft talk after completion (level.json raft.talk), after verse-stone 4. Pell has followed Orimi up the flue and stands in the chamber door (M_Pell_End) for the first two lines; the camera then rises through the oculus to M_EndView, over the valley in full colour, for the last. The travel card that follows reads "End of Book One."*

- That flue is a lot of stairs.
- So that's where all the colour went. Back where it was.
- There's more river above the mountain, you know.
