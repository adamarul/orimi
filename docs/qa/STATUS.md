# DoD status (signed by QA)

State of each definition-of-done line from the gate on 940acaa (ws/qa on main aa3946b, the
five-level Book One, plus QA's harness), 2026-11-16T05:47Z. Browser rows tested a fresh export of
that commit (build/web/qa_build.txt). Gate table: docs/qa/evidence/dod.md (34 PASS, 1 FAIL, 0 NOT
YET). Harness self-test on the same commit: 44 cases, 0 wrong outcomes
(docs/qa/evidence/selftest.md). Findings: docs/qa/FINDINGS.md.

Signed: QA, 2026-11-16.

| # | Definition of done | State | Why / evidence | Blocked by |
| - | - | - | - | - |
| 1 | Fresh Godot opens and runs the project, no script errors | PASS | check.sh; a fresh clone imports, checks and runs the main scene windowed; every scene runs windowed without errors | - |
| 2 | Browser: no console errors, playable title to finale, playable fps | PASS | Fresh export; main scene and the demos clean; input; manual title to thorn gate with a drawn slash; frame rate in all five levels (Mosswater with 15 of 15 lantern-fruit lit, the Kiln while the Dregs fight runs); save, reload and Continue after Levels 1, 2 and 4 open the next level with 1, 2 and 4 beads | - |
| 3 | All six rendering-stack items visible in the web build | PASS | 12 stack captures from the book run (docs/qa/stack/); paper levels step the right way on web and desktop | - |
| 4 | Brush works end to end in the web build | PASS | Freeze, sepia view, circle / line / loop recognised from real pointer strokes, ink drains, world resumes | - |
| 5 | Both enemies dissolve, zones restore, finale, clean end | PASS | Whole book by autoplay in 975 s of 2000: 67 deaths (Splotchet, Reedwraith, Sootflit, the Dregs), 11 zones restored, all five levels complete with their beads, 116 stages, end card, no console errors in 6,168 lines; each of Levels 2 to 5 also passes on its own | - |
| 6 | Models < 5k tris and from Blender scripts; textures/sounds from scripts | FAIL | 17 glTF files over 5,000 triangles: 16 Sedge Plain terrain tiles (5,480 to 5,792) and the Kiln model (5,468). Every media file is tied to a generator by hash | F-019 (Sedge Plain, Hollow Kiln) |
| 7 | Banned-term scan clean, nothing derivative | PASS | Scan clean (files, build, commits). Originality audit signed PASS for all five levels; clouds redrawn (F-015 closed). One borrowed phrase in docs and file names only, rename asked | F-018 open, not blocking |
| 8 | README, SHADERS.md, three paper screenshots exist and match | PASS | README: run, controls, glyph guide, credits and licences, paper screenshots; every shader uniform documented | - |
| all | Contract | PASS | API conforms to the stubs; every contract scene present with its animations | - |

## Browser frame rate (Chrome 157, ANGLE D3D11, RTX 3080)

The window column is the real canvas size; the game's logical viewport stays 1280x720 under
canvas_items stretch, and 3D renders at the window size.

| Scene | Mode | Window | rAF fps | p95 frame | Godot fps | Godot mean | Draw calls |
| - | - | - | - | - | - | - | - |
| Hazewater (M_ZoneA) | vsync | 1280x720 | 141 | 7.1 ms | 144 | 7.1 ms | 211 |
| Hazewater | vsync | 1920x1080 | 144 | 7.1 ms | 144 | 6.9 ms | 216 |
| Hazewater | uncapped | 1280x720 | 202 | 6.2 ms | 197 | 4.9 ms | 210 |
| Hazewater | uncapped | 1920x1080 | 183 | 6.7 ms | 178 | 5.5 ms | 240 |
| Tallowford, 6 of 6 lamps lit (M_Square) | vsync | 1280x720 | 144 | 7.1 ms | 144 | 6.9 ms | 214 |
| Tallowford, lit | vsync | 1920x1080 | 144 | 7.1 ms | 144 | 6.9 ms | 214 |
| Tallowford, lit | uncapped | 1280x720 | 181 | 6.4 ms | 188 | 5.5 ms | 228 |
| Tallowford, lit | uncapped | 1920x1080 | 167 | 7.3 ms | 177 | 6.0 ms | 214 |
| Sedge Plain (M_Knoll) | vsync | 1280x720 | 74 | 7.1 ms | 65 | 7.6 ms | 586 |
| Sedge Plain | vsync | 1920x1080 | 115 | 13.9 ms | 131 | 8.7 ms | 567 |
| Sedge Plain | uncapped | 1280x720 | 76 | 8.8 ms | 133 | 7.2 ms | 585 |
| Sedge Plain | uncapped | 1920x1080 | 117 | 11.4 ms | 123 | 8.5 ms | 581 |
| Mosswater dark hollow, 15 of 15 lantern-fruit lit (M_DarkHollow) | vsync | 1280x720 | 127 | 13.9 ms | 120 | 7.9 ms | 782 |
| Mosswater, lit | vsync | 1920x1080 | 132 | 13.9 ms | 117 | 7.6 ms | 261 |
| Mosswater, lit | uncapped | 1280x720 | 135 | 10.7 ms | 133 | 7.4 ms | 785 |
| Mosswater, lit | uncapped | 1920x1080 | 137 | 10.4 ms | 130 | 7.3 ms | 267 |
| Hollow Kiln, the Dregs in its veil part (M_Arena_Entry) | vsync | 1280x720 | 142 | 7.1 ms | 144 | 7.0 ms | 242 |
| Hollow Kiln, fight | vsync | 1920x1080 | 140 | 7.1 ms | 144 | 7.2 ms | 303 |
| Hollow Kiln, fight | uncapped | 1280x720 | 181 | 7.3 ms | 209 | 5.5 ms | 237 |
| Hollow Kiln, fight | uncapped | 1920x1080 | 160 | 7.6 ms | 169 | 6.2 ms | 409 |

Sedge Plain's first window (1280x720, the seconds after arriving) runs at 74 to 76 fps by
requestAnimationFrame with frames up to 145 ms and a Godot process-time reading near 2.9 s; the
second window is smooth. Seen on both runs that day; F-020.

## Visual sign-off (looked at by QA on 2026-11-16)

- Stack captures docs/qa/stack/web_01_glyph_first_cast.jpg to web_12_end_card.jpg from the book run:
  all six stack items show; the cursed-zone edge reads as a translucent dome over the ground.
- Paper screenshots docs/screenshots/valley_{light,normal,heavy}_{web,desktop}.png: Heavy has deeper
  tooth, fibres and vignette and is greyer than Normal; web and desktop agree.
- Tallowford (docs/levels/tallowford/shots/): village, lamps, cast and the jetty fight ring pass the
  "Ours, not theirs" review. The new clouds show in the gate's own capture
  (docs/qa/evidence/web_resume_continued.jpg): torn wash bands with a dark underline, no spiral.
- Levels 3 to 5 (the gate's web_level_*, web_perf_* and web_resume_* captures, every stage shot
  full-size under .userdata/qa/full/): looked at in order; what a player would notice first as rough
  is listed in FINDINGS.md under F-021 to F-026, with the camera, colour and prompt problems there.
