# Mosswater Wood: script

Every line in the level, with who says it and what starts it. The data is
`scenes/levels/mosswater/level.json` (`lines`, in the kit's format: a line with no `who` is spoken
by the Person who owns it, `"who": ""` is narration, `*word*` is shown in the accent colour); this
page is the readable copy, and the JSON wins if they disagree. Event triggers, hints and the kit
nodes are under the `mosswater` key of the same file.

**Voices.** Pell is quick and practical and never explains the plot. Fenn is short with words,
wary at first and warmer with each pond; he does not complain, he states. The verse-stones are
the Ink-maker speaking, four lines each, plain and a little proud.

## pell

**Pell.** Talk to Pell at the raft (M_Raft); also plays as the arrival cutscene.

- Mosswater Wood. The stream ought to be loud here.
- It isn't.
- I lit the first *lantern-fruit* for you. That's all my flint's good for.
- Bring the water back and we can go on upriver. I'll mind the raft.

## pell_again

**Pell.** Talk to Pell again.

- Mind the dark. Things sit in it.
- And don't fall in anything. I only brought one towel.

## pell_leaves

**Pell.** After the level completes (raft cutscene).

- That's water! Real water, going the right way!
- Get on. Before it changes its mind.

## fenn

**Fenn.** Talk to Fenn at the brazier (M_Fenn_1), first time.

- Stop there. In my light or out of it. Not on the edge.
- ...A paper fox. Huh.
- Fenn. I burn charcoal. Burned. Nobody's come for any in a long while.
- You came up the river, so you've seen the ponds. Black as my hands.
- The *wheel* at the bottom pond is choked with soot. If it turned, the pond would breathe again.
- I'd clear it myself. Soot doesn't care for shovels.

## fenn_again

**Fenn.** Talk to Fenn at the brazier again, before the wheel turns.

- This fire hasn't gone out in a year. I think it's the only reason I'm still me.
- Keep a light near you. The dark here isn't empty.

## fenn_wheel

**Fenn.** Bark: flag wheel_freed. Fenn speaks from the brazier; he is gone once Orimi reaches the stair top.

- Hear that? That's the bottom pond, talking again.
- ...Thank you. I'm out of practice at saying it.
- The middle pond's up the bank. Climb the shelves on the *stair tree*. They held me and a sack of charcoal.
- The lilies up there shut tight when the water stopped. Show them something round and bright. They'll think it's morning.
- I'll go round by the goat path and meet you up top. You'd fit on it. You wouldn't like it.

## fenn_call

**Fenn.** Bark: Orimi reaches the stair-top checkpoint (reached_cp_stair_top). Fenn calls from M_Fenn_2.

- Over here! Keep out of the water. It's deep, and it's wrong.
- Mind the flitters over the island. Soot with wings. They can't abide a draught.

## fenn_log

**Fenn.** Bark: the third lily bud opens (lily_3_open), the step before the island.

- That log was my bridge. Now it's a cork in the weir.
- There's a post on your side and one on mine. You'd want a long rope, mind.

## fenn_tied

**Fenn.** Bark: flag tied_log.

- You made a rope out of ink. I'm not going to ask.
- Hear the weir? That's two ponds talking.
- Come over. I owe you a story, and I'd rather tell it in the light.

## fenn_ledge

**Fenn.** Talk to Fenn on the north shore (M_Fenn_2), first time.

- There was a man from the head of the river. The *Ink-maker*, folk called him.
- Most people buy a sack of charcoal. He bought the whole winter's burn. Every winter.
- Last time, he wanted it blacker. I asked him how black.
- He said, a black you could fall into.
- I should have asked what he wanted it for.

## fenn_ledge_again

**Fenn.** Talk to Fenn on the north shore again.

- The gully's the only way up to the dam.
- Thorns at the bottom, dark in the middle, soot at the top. And a gap with no bridge. Bring everything you've got.

## fenn_willow

**Fenn.** Talk to Fenn at the willow (M_Fenn_3), first time.

- You came up the gully. I took the long way. I'm not ashamed.
- That's the old *willow*. Its roots hold the spring. Open, or shut. Right now, shut.
- My mother tied that cord round it, for luck. It's been a thin year for luck.

## fenn_willow_again

**Fenn.** Talk to Fenn at the willow again, before the Bloom.

- *Bloom* the willow. I'll stand back. I've had enough surprises for one year.

## fenn_end

**Fenn.** Bark: flag water_runs (about 7 s after restored_spring, once the ponds have cleared).

- Listen to that.
- ...I'd forgotten it was this loud.

## fenn_farewell

**Fenn.** Talk to Fenn at the willow after the Bloom.

- If you meet the Ink-maker up there, tell him the burner says the ponds are moving.
- He'll know what I mean. Or he won't. Either way, tell him.

## verse_1

**Verse-stone.** Bloom the verse-stone at M_Verse_1.

> I bought my black from the burner by the ponds.  
> Willow wood, burned slow, a whole winter's sleep.  
> He said, that's dark enough for any letter.  
> I said, not for the one I mean to write.

## verse_2

**Verse-stone.** Bloom the verse-stone at M_Verse_2.

> I cut a willow switch here for my first brush.  
> The tree didn't mind. It had a thousand more.  
> I came back for water when my ink ran thick.  
> The spring always gave. I never once said thank you.

## bead

**Narration** (level.json `barks`, on `ponds_remember` once the finale camera lets go).

- The ponds remember their colour. *Water indigo* joins the cord.

## Hints

Short prompts on the paper strip, no speaker: level.json `hints` (the kit's), except mw_lily and
mw_wheel, which ride on their nodes.

| Id | Text | When |
| - | - | - |
| mw_kindle | *Kindle* a lantern-fruit: a short dab on it. | within 6 m of LF02 while unlit |
| mw_dark | Something waits where the light stops. | within 9 m of M_DarkHollow while LF03 is unlit |
| mw_wheel | Soot packs the paddles. A *Gust* could clear them. | WheelSoot hint_text, hint_distance 6 |
| mw_lily | The bud is waiting for a sun. *Bloom* it. | within 5 m of M_Lily_1 while closed |
| mw_sootflit | *Sootflits* circle out of reach. A *Gust* brings them down. | within 5 m of M_Lily_3 once lily_2_open, until tied_log |
| mw_tie | Two posts, one line. *Tie* them. | within 3 m of TiePost_A before tied_log |
| mw_moss | The moss leans toward the light. | within 5 m of M_MossLantern before lit_lf10 |
| mw_deep | The still water will not hold Orimi. Back to the shore. | first fall into a pond (DeepWater flag fell_in_pond) |
