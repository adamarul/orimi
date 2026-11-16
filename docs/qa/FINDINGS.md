# QA findings

One entry per finding. Severity: blocker (a DoD line cannot pass), high, medium, low.
Status: open until the lead closes it. Gate run these come from: docs/qa/evidence/dod.md
(940acaa = main aa3946b plus the harness; browser build exported from that commit). F-021 to F-027
come from looking at that run's captures (and the book run's QA log), in the order a player meets them.
Level-row stage shots named below but not in docs/qa/evidence (the gate publishes every third) are
full-size on the QA machine under .userdata/qa/full/docs/qa/evidence/, and as JPEGs in commit 084faa5.

## Open, by owner

| Owner | Findings |
| - | - |
| Sedge Plain | F-019 terrain tiles over 5,000 triangles (blocks DoD 6); F-018 "guardian sapling" name; F-020 a hitch in the first seconds at the Knoll |
| Hollow Kiln | F-019 kiln.glb over 5,000 triangles (blocks DoD 6); F-024 "colour restored" with no colour; F-025 the Dregs out of frame at the arena door; F-026 the title backdrop after the Kiln |
| Mosswater | F-023 camera inside rocks and inside Orimi; the arrival backdrop; lantern-fruit that do not read as lit |
| gameplay | F-016 progress reaches IndexedDB a few seconds after the save; F-022 control prompts repeat in every level; F-027 the book's end card shows the Kiln's numbers |
| render or vfx (not traced) | F-021 blurred dark smudges over the ground |
| lead | F-018 the LEVELS.md line |
| QA / machine | F-017 static server stalls under load (no stall in the 940acaa gate) |

## F-015 Clouds read close to the reference game's signature cloud (closed 2026-11-16 by QA: redrawn by vfx in c5ff452, seen in the 940acaa gate; DoD 7, visual)

- **What:** the sky's clouds are stacked round white puffs topped with tight spiral curls
  (docs/levels/tallowford/shots/play_04_trim_lit.jpg, restored_v8.jpg). STYLE_GUIDE.md "Wind and
  cloud" asks for our own curl, drawn as a stroke that starts heavy and thins as it spirals. Judged by
  eye; docs/qa/ORIGINALITY.md.
- **Owner:** vfx (shaders/env/sky.gdshader and its cloud texture).

## F-018 "Guardian sapling" is the reference game's own term (open, medium; DoD 7, names)

- **What:** Sedge Plain's docs and files call the sapling on the Knoll the "guardian sapling"
  (docs/levels/sedge_plain/DESIGN.md lines 29 and 78, docs/LEVELS.md line 124,
  scenes/levels/sedge_plain/props/guardian_sapling.tscn and its node GuardianSapling,
  scripts/levels/sedge_plain/lookdev.gd). That is the reference game's exact English name for the
  saplings its hero blooms to lift the curse from an area, with the same mechanic. The game's text
  never shows it (level.json: "Wake the sapling on the Knoll"), so players do not see it.
- **Ask:** call it something of ours in docs and file names, for example "the Knoll sapling" or "the
  mere sapling"; add it to LEVELS.md "Names that changed".
- **Owner:** the Sedge Plain workstream (DESIGN.md, the prop scene, lookdev.gd); the lead (LEVELS.md).

## F-019 Seventeen models over the 5,000-triangle budget (open, blocker; DoD 6)

- **What:** tools/qa/qa.sh tris counts from the glTF data. assets/levels/sedge_plain/terrain/ground_{00..33}.glb:
  16 tiles at 5,480 to 5,792 triangles; assets/levels/hollow_kiln/models/kiln.glb: 5,468.
- **Evidence:** docs/qa/evidence/tris.txt.
- **Owner:** Sedge Plain (split the terrain into more tiles or decimate each by about 15 %); Hollow
  Kiln (take about 470 triangles out of the kiln model or split it).

## F-020 Sedge Plain: a hitch in the first seconds at the Knoll (open, low; DoD 2)

- **What:** web_perf_sedge_plain's first window (1280x720, starting 3 s after arriving at M_Knoll)
  runs at 74 to 76 fps by requestAnimationFrame against 140 elsewhere, with frames up to 145 ms and
  Godot's process time reading about 2.9 s; the second window is smooth. Same on two runs. Still
  "playable", but something heavy runs after arrival.
- **Owner:** Sedge Plain.

## F-021 Blurred dark smudges over the ground (open, medium; visual)

- **What:** soft, motion-blurred black blots lie over the ground in nearly every outdoor capture of
  Hazewater and Sedge Plain (docs/qa/stack/web_01 to web_09; web_level_sedge_plain_*), also after a
  zone is restored. They read as dirt on the screen rather than ink in the world. Not traced to a
  file.
- **Owner:** render or vfx (whichever draws ground decals or soot flecks).

## F-022 The control prompts come back in every level (open, low; gameplay)

- **What:** in the book run the "move" (WASD), "jump" (Space to leap) and "fight" prompts each show 5
  times, once per level (QA log, web_full console). "Space to leap" also stays up through the first
  minute of Level 1's fights (stack web_03 to web_06) and shows during the Dregs fight
  (web_perf_kiln_fight.jpg).
- **Owner:** gameplay (show each control prompt once per save).

## F-023 Mosswater: camera, arrival backdrop, lantern-fruit (open, medium; visual)

- **What:** at the waterwheel the camera sits behind rocks and the screen is grey blobs
  (web_level_mosswater_wheel); at the gully foot it is inside
  Orimi's head (web_level_mosswater_gully_foot). The first view has a large flat white plane across
  the top left (web_level_mosswater_arrival). Lit lantern-fruit hang as brown spiky shapes and the
  hollow does not get warmer when all 15 are lit (web_perf_mosswater_lit.jpg).
- **Owner:** Mosswater (camera zones or occluder fade, the backdrop, the fruit's lit look).

## F-024 The Kiln: "colour restored" and the space stays grey (open, medium; visual)

- **What:** the banners "The Kiln Yard / colour restored" and "The Drying Hall / colour restored" show
  while the yard and hall stay grey (web_level_hollow_kiln_hk_yard_restored,
  web_level_hollow_kiln_hk_hall_restored). In Levels 1 to 4 the same banner comes with green and
  flowers.
- **Owner:** Hollow Kiln.

## F-025 The Kiln: the Dregs out of frame at the arena door (open, medium; visual)

- **What:** two seconds after M_Arena_Entry, with the fight running (dregs_part veil), the view is
  the vat wall filling the screen; the Dregs is above the frame (web_perf_kiln_fight.jpg). DESIGN.md
  says VatCam keeps both in view.
- **Owner:** Hollow Kiln (VatCam pitch or follow distance).

## F-026 The title after the Kiln shows a blurred wall (open, low; visual)

- **What:** with Level 5 as the current level (Continue after Level 4, and after the end of the book)
  the title's backdrop is a blurred close-up of a soot wall (web_resume_mosswater_title.jpg,
  web_level_hollow_kiln_end).
- **Owner:** Hollow Kiln (its title camera marker), or gameplay.

## F-027 The End of Book One card shows the Kiln's numbers (open, low; gameplay)

- **What:** the card reads "Five beads on Orimi's cord" beside "Time 5:42, Ink-spawn undone 11"
  (stack web_12_end_card.jpg); the book run took 975 s and undid 67. Stats reset per level
  (game.gd reset_run), so the last level's numbers read as the book's.
- **Owner:** gameplay (book totals on the last card, or label them as the Kiln's).

## F-016 Progress reaches IndexedDB a few seconds after progress_saved (open, low; DoD 2)

- **What:** in the browser, a reload 2 s after `progress_saved` found no saved file (no
  `progress_loaded`, title offered Begin); a reload 6 s after found it, and Continue opened Tallowford
  with the bead. Godot writes user:// to IndexedDB asynchronously. A player who closes the tab on the
  raft card right after a bead can lose it.
- **Evidence:** docs/qa/evidence/web_resume.md (passing, 6 s wait, with the IndexedDB keys listed
  before the reload); the 2 s failure was the first run of that check on efa78c8.
- **Owner:** gameplay (for example, hold the raft card until the sync has had time, or save earlier
  in the finale).

## F-017 The static server stalls under load on this machine (open, low; harness)

- **What:** with other workstreams' builds running, index.html sometimes does not load within 30 s.
  The runner retries once on a fresh server (logged as `# retry`); in the dc902a5 gate the retry
  also timed out for render_demo and vfx_demo, so web_smoke_demos failed. Rerun on the same commit
  and build: 5 of 5 demos clean (docs/qa/evidence/web_smoke_demos.txt; the gate's failing output is
  web_smoke_demos_gate_run.txt). Not a game defect.
- **Owner:** QA. Run the gate when the machine is quiet, or give the server its own process priority.

## Closed

- F-009 README credits and licences: written on main (aec8e3e); the docs row passes.
- F-001 `paper=` boot option ignored: fixed (2ad56cb); paper_desktop sets the level only through it.
- F-002 media without provenance: 155 of 155 media files covered by 15 manifests.
- F-003 undocumented uniforms: 268 of 268 documented (docs/BRUSH.md joins the list; phase 0 probe
  shaders skipped by the lead's decision).
- F-004 names that collided: renamed (the Spill, Splotchet); the kind strings follow.
- F-005 glyph gestures: the lead keeps Bloom, Slash and Gust; recorded in ORIGINALITY.md.
- F-006 browser resume bounced back to pause: web_input passes all 16 criteria.
- F-007 Heavy paper raised saturation: now Light > Normal > Heavy (web 0.151 / 0.144 / 0.136,
  desktop 0.153 / 0.146 / 0.139); both paper rows pass.
- F-008 cursed zones as flat-topped walls: the edge now reads as a translucent dome over the ground
  (docs/qa/stack/web_06_cursed_zone_before.jpg).
- F-010 vfx_demo missing: delivered.
- F-011 long-tailed gust loops: closed by brush.
- F-012 Ink-maker near-collision: kept by the lead's decision; the lamp-maker renamed Old Trim.
- F-013 gameplay_demo script error: desktop_scenes passes 6 of 6.
- F-014 example level Bellows: web_level passes.
- valley_terrain.glb triangles, withered animations: fixed earlier.
