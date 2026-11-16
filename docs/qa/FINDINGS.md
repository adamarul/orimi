# QA findings

One entry per finding. Severity: blocker (a DoD line cannot pass), high, medium, low.
Status: open until the lead closes it. Gate run these come from: docs/qa/evidence/dod.md (the
final gate on ws/qa with main 2f8ed3e merged; browser build exported from the commit it names).
Every finding below was re-judged on 2026-11-16 from that gate's fresh browser captures and QA log.
Level-row stage shots named below but not in docs/qa/evidence (the gate publishes every third) are
full-size on the QA machine under .userdata/qa/full/docs/qa/evidence/.

## Open, by owner

| Owner | Findings |
| - | - |
| render | F-028 render_demo logs four engine errors on desktop and in the browser (blocks DoD 1 and 2) |
| Mosswater | F-023 a: the camera behind rocks at the waterwheel |
| Sedge Plain (or render) | F-021: low views of the path still smear the tuft marks into soft dark streaks |
| gameplay | F-022: after a reload, Continue shows the WASD card again |

Closed on 2026-11-16 after re-judging: F-015, F-016, F-017, F-018, F-019, F-020, F-023 b to d,
F-024, F-025, F-026, F-027.

## F-015 Clouds read close to the reference game's signature cloud (closed 2026-11-16 by QA: redrawn by vfx in c5ff452, seen in the 940acaa gate; DoD 7, visual)

- **What:** the sky's clouds are stacked round white puffs topped with tight spiral curls
  (docs/levels/tallowford/shots/play_04_trim_lit.jpg, restored_v8.jpg). STYLE_GUIDE.md "Wind and
  cloud" asks for our own curl, drawn as a stroke that starts heavy and thins as it spirals. Judged by
  eye; docs/qa/ORIGINALITY.md.
- **Owner:** vfx (shaders/env/sky.gdshader and its cloud texture).

## F-018 Sedge Plain's sapling carried the reference game's own name for it (closed 2026-11-16; DoD 7, names)

- **What:** Sedge Plain's docs and files named the sapling on the Knoll with the reference game's
  exact two-word English name for the saplings its hero blooms to lift a curse from an area (a word
  for a protector, then "sapling"), with the same mechanic. Players never saw it; the game's text
  says "the sapling on the Knoll".
- **Fixed:** c41b45f and 59b54a9 renamed it the Knoll sapling (scenes/levels/sedge_plain/props/knoll_sapling.tscn,
  DESIGN.md, LEVELS.md "Names that changed"). Re-judged: no tracked file holds the old word
  (git grep, case-insensitive).
- **Owner:** Sedge Plain; the lead (LEVELS.md).

## F-019 Seventeen models over the 5,000-triangle budget (closed 2026-11-16; DoD 6)

- **Re-judged:** tris passes on the final gate: every glTF within 5,000 (Sedge Plain is now 36 tiles under 2,720 each; kiln.glb 4,956).
- **What:** tools/qa/qa.sh tris counts from the glTF data. assets/levels/sedge_plain/terrain/ground_{00..33}.glb:
  16 tiles at 5,480 to 5,792 triangles; assets/levels/hollow_kiln/models/kiln.glb: 5,468.
- **Evidence:** docs/qa/evidence/tris.txt.
- **Owner:** Sedge Plain (split the terrain into more tiles or decimate each by about 15 %); Hollow
  Kiln (take about 470 triangles out of the kiln model or split it).

## F-020 Sedge Plain: a hitch in the first seconds at the Knoll (closed 2026-11-16; DoD 2)

- **Re-judged:** web_perf_sedge_plain's first window now runs 134 fps (vsync) and 152 (uncapped) at 1280x720, longest frame 48 ms, process time 7 ms; the fights and zones are drawn once behind the loading screen (2b3f6ed).
- **What:** web_perf_sedge_plain's first window (1280x720, starting 3 s after arriving at M_Knoll)
  runs at 74 to 76 fps by requestAnimationFrame against 140 elsewhere, with frames up to 145 ms and
  Godot's process time reading about 2.9 s; the second window is smooth. Same on two runs. Still
  "playable", but something heavy runs after arrival.
- **Owner:** Sedge Plain.

## F-021 Blurred dark smudges over the ground (open, low; visual; narrowed to Sedge Plain)

- **Re-judged:** Hazewater's ground marks are now crisp ink flecks and lighten where restored (stack web_01 to web_09, the six paper screenshots). On Sedge Plain the low path views still show soft, smeared dark streaks along the road (web_level_sedge_plain_west, _sedge_plain_spawn, _east).
- **What:** soft, motion-blurred black blots lie over the ground in nearly every outdoor capture of
  Hazewater and Sedge Plain (docs/qa/stack/web_01 to web_09; web_level_sedge_plain_*), also after a
  zone is restored. They read as dirt on the screen rather than ink in the world. Not traced to a
  file.
- **Owner:** render or vfx (whichever draws ground decals or soot flecks).

## F-022 The control prompts come back in every level (open, low; gameplay; narrowed to Continue)

- **Re-judged:** in one sitting each control prompt now shows once in the whole book (move, jump and fight once each in the book run's QA log). After a page reload, Continue shows the "WASD to run" card again at the start of the level although the loaded save lists taught: move, jump, fight (web_resume_tallowford_continued.jpg, web_resume_mosswater_continued.jpg; progress_loaded in their consoles).
- **What:** in the book run the "move" (WASD), "jump" (Space to leap) and "fight" prompts each show 5
  times, once per level (QA log, web_full console). "Space to leap" also stays up through the first
  minute of Level 1's fights (stack web_03 to web_06) and shows during the Dregs fight
  (web_perf_kiln_fight.jpg).
- **Owner:** gameplay (show each control prompt once per save).

## F-023 Mosswater: camera, arrival backdrop, lantern-fruit (a open; b, c, d closed 2026-11-16; visual)

- **Re-judged:** (a) the gully foot is fixed (Orimi framed on the ledge), but at the waterwheel the
  camera still looks through a heap of grey rock shapes that fill two thirds of the screen
  (web_level_mosswater_wheel). (b) the first view now shows the wood and the hill, no white plane.
  (c) lit lantern-fruit glow amber and the hollow brightens (web_perf_mosswater_lit.jpg). (d) the
  sealed-fight screens are grey-tan washed paper and read as screens.
- **What:** at the waterwheel the camera sits behind rocks and the screen is grey blobs
  (web_level_mosswater_wheel); at the gully foot it is inside
  Orimi's head (web_level_mosswater_gully_foot). The first view has a large flat white plane across
  the top left (web_level_mosswater_arrival). Lit lantern-fruit hang as brown spiky shapes and the
  hollow does not get warmer when all 15 are lit (web_perf_mosswater_lit.jpg).
- **Owner:** Mosswater (camera zones or occluder fade, the backdrop, the fruit's lit look).

## F-024 The Kiln: "colour restored" and the space stays grey (closed 2026-11-16; visual)

- **Re-judged:** the restored yard turns warm tan with terracotta pots, and the restored hall shows its red, blue and yellow cloths on a warm floor (web_level_hollow_kiln_hk_yard_restored, _hk_hall_restored).
- **What:** the banners "The Kiln Yard / colour restored" and "The Drying Hall / colour restored" show
  while the yard and hall stay grey (web_level_hollow_kiln_hk_yard_restored,
  web_level_hollow_kiln_hk_hall_restored). In Levels 1 to 4 the same banner comes with green and
  flowers.
- **Owner:** Hollow Kiln.

## F-025 The Kiln: the Dregs out of frame at the arena door (closed 2026-11-16; visual)

- **Re-judged:** in web_perf_kiln_fight.jpg the Dregs' body, arms and both pillar rings are in frame above the vat. The capture stands Orimi against the vat after a 2 s run, so its eyes sit just above the top edge there; from anywhere on the ring floor that is not the case.
- **What:** two seconds after M_Arena_Entry, with the fight running (dregs_part veil), the view is
  the vat wall filling the screen; the Dregs is above the frame (web_perf_kiln_fight.jpg). DESIGN.md
  says VatCam keeps both in view.
- **Owner:** Hollow Kiln (VatCam pitch or follow distance).

## F-026 The title after the Kiln shows a blurred wall (closed 2026-11-16; visual)

- **Re-judged:** with Level 5 current, the title shows the dome and the works over the gorge (web_resume_mosswater_title.jpg); after the whole book it shows Hazewater restored.
- **What:** with Level 5 as the current level (Continue after Level 4, and after the end of the book)
  the title's backdrop is a blurred close-up of a soot wall (web_resume_mosswater_title.jpg,
  web_level_hollow_kiln_end).
- **Owner:** Hollow Kiln (its title camera marker), or gameplay.

## F-027 The End of Book One card shows the Kiln's numbers (closed 2026-11-16; gameplay)

- **Re-judged:** the book run's end card reads "The whole book, 5 levels: Time 14:54, Ink-spawn undone 67, Falls 2, Beads 5" (stack web_12_end_card.jpg).
- **What:** the card reads "Five beads on Orimi's cord" beside "Time 5:42, Ink-spawn undone 11"
  (stack web_12_end_card.jpg); the book run took 975 s and undid 67. Stats reset per level
  (game.gd reset_run), so the last level's numbers read as the book's.
- **Owner:** gameplay (book totals on the last card, or label them as the Kiln's).

## F-028 render_demo logs engine errors on desktop and in the browser (open, blocker; DoD 1 and 2)

- **What:** desktop_scenes and web_smoke_demos fail on render_demo only: four times
  'ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()' at
  scene/3d/node_3d.cpp get_global_transform, from scripts/render/ink_look.gd:137 (_apply_mesh reads
  mi.global_transform) via ink_look.gd:87 apply, scripts/render/render_demo.gd:221 _build_world (it
  calls look.apply() before add_child(body)), render_demo.gd:34 _ready. New with 9890982 (ground
  marks sized from the mesh's world scale). The game itself is clean (web_full: no console errors).
- **Evidence:** docs/qa/evidence/desktop_scenes.txt, web_smoke_render_demo.md and its console.
- **Ask:** in ink_look.gd use the local transform when the mesh is not in the tree yet (for example
  mi.global_transform if mi.is_inside_tree() else mi.transform), or add the body to the tree before
  look.apply() in render_demo.gd.
  QA tried the first form on this checkout without committing it: desktop_scenes then ran 6 of 6
  scenes windowed with no errors.
- **Owner:** render.

## F-016 Progress reaches IndexedDB a few seconds after progress_saved (closed 2026-11-16; DoD 2)

- **Re-judged:** the browser save goes to localStorage before save_progress returns (d3d94ad); the three resume rows pass and progress_loaded says "from": "localStorage".
- **What:** in the browser, a reload 2 s after `progress_saved` found no saved file (no
  `progress_loaded`, title offered Begin); a reload 6 s after found it, and Continue opened Tallowford
  with the bead. Godot writes user:// to IndexedDB asynchronously. A player who closes the tab on the
  raft card right after a bead can lose it.
- **Evidence:** docs/qa/evidence/web_resume.md (passing, 6 s wait, with the IndexedDB keys listed
  before the reload); the 2 s failure was the first run of that check on efa78c8.
- **Owner:** gameplay (for example, hold the raft card until the sync has had time, or save earlier
  in the finale).

## F-017 The static server stalls under load on this machine (closed 2026-11-16; harness)

- **Re-judged:** no stall and no retry in the last two full gates; the runner keeps its one retry.
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
