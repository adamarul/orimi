# QA findings

One entry per finding. Severity: blocker (a DoD line cannot pass), high, medium, low.
Status: open until the lead closes it. Gate run these come from: docs/qa/evidence/dod.md
(85a62df = main 2019c4c plus the harness; browser build exported from that commit).

## Open, by owner

| Owner | Findings |
| - | - |
| vfx | F-015 cloud shape |
| gameplay | F-016 progress reaches IndexedDB a few seconds after the save |
| QA / machine | F-017 static server stalls under load (harness retries; one row needed a rerun) |

## F-015 Clouds read close to the reference game's signature cloud (open, medium; DoD 7, visual)

- **What:** the sky's clouds are stacked round white puffs topped with tight spiral curls
  (docs/levels/tallowford/shots/play_04_trim_lit.jpg, restored_v8.jpg). STYLE_GUIDE.md "Wind and
  cloud" asks for our own curl, drawn as a stroke that starts heavy and thins as it spirals. Judged by
  eye; docs/qa/ORIGINALITY.md.
- **Owner:** vfx (shaders/env/sky.gdshader and its cloud texture).

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
