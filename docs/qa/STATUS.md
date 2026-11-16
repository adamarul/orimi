# DoD status (signed by QA)

State of each definition-of-done line from the final gate on d0685c3 (ws/qa with main 887d424
merged: the five-level Book One with every fix through F-028), 2026-11-16T14:16Z. Browser rows
tested a fresh export of that commit (build/web/qa_build.txt). Gate table:
docs/qa/evidence/dod.md (33 PASS, 2 FAIL, 0 NOT YET). Harness self-test on the same commit: 44
cases, 0 wrong outcomes (docs/qa/evidence/selftest.md). The run before it on the same game code
(05e935a, committed in d0685c3) had 31 PASS, 4 FAIL. Findings: docs/qa/FINDINGS.md.

Signed: QA, 2026-11-17.

| # | Definition of done | State | Why / evidence | Blocked by |
| - | - | - | - | - |
| 1 | Fresh Godot opens and runs the project, no script errors | PASS | check.sh; a fresh clone imports, checks and runs the main scene windowed; 6 of 6 scenes run windowed without errors (render_demo clean again, F-028). check failed once in the run before ("2 resources still in use at exit") and passed in 3 runs since | - |
| 2 | Browser: no console errors, playable title to finale, playable fps | PASS | Fresh export; main scene and 5 demos clean; input; manual title to thorn gate with a drawn slash; frame rate in all five levels; save, reload and Continue after Levels 1, 2 and 4 open the next level with 1, 2 and 4 beads (save read from localStorage) | - |
| 3 | All six rendering-stack items visible in the web build | FAIL (rule) | The row only accepts captures from a passing book run, and web_full failed one autoplay step (DoD 5). The 12 captures it took show all six items (docs/qa/stack/); paper levels step the right way on web and desktop | F-029 |
| 4 | Brush works end to end in the web build | PASS | Freeze, sepia view, circle / line / loop recognised from real pointer strokes, ink drains, world resumes | - |
| 5 | Both enemies dissolve, zones restore, finale, clean end | FAIL (flaky) | The book completes in 996 s of 2000 with all five beads, the end card and no console errors, but autoplay once "could not reach" a point at Mosswater's stair tree. Levels 2 to 5 on their own all pass in this run. Mosswater's route step fails about half the time on this build (F-029); your own book run on 887d424 passed | F-029 (Mosswater) |
| 6 | Models < 5k tris and from Blender scripts; textures/sounds from scripts | PASS | 144 glTF models, largest kiln.glb 4,956; every media file tied to a generator by hash | - |
| 7 | Banned-term scan clean, nothing derivative | PASS | Scan clean (files, build, commits). Originality audit signed PASS for all five levels; the sapling renamed (F-018 closed) | - |
| 8 | README, SHADERS.md, three paper screenshots exist and match | PASS | README with level ids; every shader uniform documented; the six paper screenshots retaken by this gate from the current build (bead cord in the HUD, crisp ground marks) | - |
| all | Contract | PASS | API conforms to the stubs; every contract scene present with its animations | - |

## Browser frame rate (Chrome 157, ANGLE D3D11, RTX 3080)

The window column is the real canvas size; the game's logical viewport stays 1280x720 under
canvas_items stretch, and 3D renders at the window size.

| Scene | Mode | Window | rAF fps | p95 frame | Godot fps | Godot mean | Draw calls |
| - | - | - | - | - | - | - | - |
| Hazewater (M_ZoneA) | vsync | 1280x720 | 140 | 7.0 ms | 144 | 7.1 ms | 232 |
| Hazewater | vsync | 1920x1080 | 143 | 7.0 ms | 144 | 7.0 ms | 253 |
| Hazewater | uncapped | 1280x720 | 196 | 6.4 ms | 185 | 5.1 ms | 232 |
| Hazewater | uncapped | 1920x1080 | 162 | 7.1 ms | 165 | 6.2 ms | 257 |
| Tallowford, 6 of 6 lamps lit (M_Square) | vsync | 1280x720 | 144 | 7.0 ms | 144 | 7.0 ms | 249 |
| Tallowford, lit | vsync | 1920x1080 | 144 | 7.0 ms | 142 | 7.0 ms | 235 |
| Tallowford, lit | uncapped | 1280x720 | 184 | 6.2 ms | 187 | 5.4 ms | 249 |
| Tallowford, lit | uncapped | 1920x1080 | 155 | 7.4 ms | 161 | 6.5 ms | 235 |
| Sedge Plain (M_Knoll) | vsync | 1280x720 | 139 | 7.1 ms | 144 | 7.2 ms | 661 |
| Sedge Plain | vsync | 1920x1080 | 131 | 13.9 ms | 144 | 7.6 ms | 749 |
| Sedge Plain | uncapped | 1280x720 | 153 | 8.3 ms | 166 | 6.6 ms | 663 |
| Sedge Plain | uncapped | 1920x1080 | 131 | 9.7 ms | 144 | 7.7 ms | 753 |
| Mosswater dark hollow, 15 of 15 lantern-fruit lit (M_DarkHollow) | vsync | 1280x720 | 130 | 13.9 ms | 134 | 7.7 ms | 856 |
| Mosswater, lit | vsync | 1920x1080 | 127 | 13.9 ms | 120 | 7.9 ms | 287 |
| Mosswater, lit | uncapped | 1280x720 | 134 | 10.0 ms | 150 | 7.5 ms | 857 |
| Mosswater, lit | uncapped | 1920x1080 | 127 | 10.4 ms | 106 | 7.9 ms | 285 |
| Hollow Kiln, the Dregs in its veil part (M_Arena_Entry) | vsync | 1280x720 | 141 | 7.0 ms | 143 | 7.1 ms | 283 |
| Hollow Kiln, fight | vsync | 1920x1080 | 141 | 7.0 ms | 134 | 7.1 ms | 306 |
| Hollow Kiln, fight | uncapped | 1280x720 | 183 | 6.8 ms | 198 | 5.5 ms | 285 |
| Hollow Kiln, fight | uncapped | 1920x1080 | 146 | 7.9 ms | 151 | 6.9 ms | 306 |

Sedge Plain's first window no longer stalls (F-020 closed): longest frame 32 ms.

## Visual sign-off (looked at by QA on 2026-11-16 and 2026-11-17)

- Stack captures docs/qa/stack/web_01_glyph_first_cast.jpg to web_12_end_card.jpg from the book run:
  all six stack items show; the ground marks are crisp ink flecks; the end card gives the whole
  book's totals.
- Paper screenshots docs/screenshots/valley_{light,normal,heavy}_{web,desktop}.png: all six retaken
  by this gate (same view, 1280x720). The old ones predated the HUD bead cord and the crisp ground
  marks. Heavy has deeper tooth, fibres and vignette and is greyer than Normal; web and desktop agree.
- Clouds: torn wash bands with a dark underline, no spiral (docs/qa/evidence/web_resume_continued.jpg).
- Levels 3 to 5 (the gates' web_level_*, web_perf_* and web_resume_* captures): looked at in order;
  what is still rough is in FINDINGS.md (F-021, F-022, F-023 a, F-029).
