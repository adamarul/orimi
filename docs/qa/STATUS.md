# DoD status (signed by QA)

State of each definition-of-done line from the final gate on 312543b (ws/qa with main 8d0f362
merged: the five-level Book One with every fix through F-029), 2026-11-16T17:39Z. Browser rows
tested a fresh export of that commit (build/web/qa_build.txt). Gate table:
docs/qa/evidence/dod.md (35 PASS, 0 FAIL, 0 NOT YET). Harness self-test on the same commit: 44
cases, 0 wrong outcomes (docs/qa/evidence/selftest.md). Findings: docs/qa/FINDINGS.md (one open,
low).

Signed: QA, 2026-11-17.

| # | Definition of done | State | Why / evidence | Blocked by |
| - | - | - | - | - |
| 1 | Fresh Godot opens and runs the project, no script errors | PASS | check.sh; a fresh clone imports, checks and runs the main scene windowed; 6 of 6 scenes run windowed without errors | - |
| 2 | Browser: no console errors, playable title to finale, playable fps | PASS | Fresh export; main scene and 5 demos clean; input; manual title to thorn gate with a drawn slash; frame rate in all five levels (Mosswater with 15 of 15 lantern-fruit lit, the Kiln with the Dregs fight running); save, reload and Continue after Levels 1, 2 and 4 open the next level with 1, 2 and 4 beads | - |
| 3 | All six rendering-stack items visible in the web build | PASS | 12 stack captures from the passing book run (docs/qa/stack/); paper levels step the right way on web and desktop | - |
| 4 | Brush works end to end in the web build | PASS | Freeze, sepia view, circle / line / loop recognised from real pointer strokes, ink drains, world resumes | - |
| 5 | Both enemies dissolve, zones restore, finale, clean end | PASS | Whole book by autoplay in 959 s of 2000: no failed step, 116 stages, all five levels with their beads, end card with the book's totals, no console errors in 6,116 lines; Levels 2 to 5 also pass on their own (Mosswater with no unreachable point) | - |
| 6 | Models < 5k tris and from Blender scripts; textures/sounds from scripts | PASS | 144 glTF models, largest kiln.glb 4,956; every media file tied to a generator by hash | - |
| 7 | Banned-term scan clean, nothing derivative | PASS | Scan clean (files, build, commits). Originality audit signed PASS for all five levels | - |
| 8 | README, SHADERS.md, three paper screenshots exist and match | PASS | README with level ids; every shader uniform documented; the six paper screenshots retaken by this gate from the current build (the larger HUD bead cord) | - |
| all | Contract | PASS | API conforms to the stubs; every contract scene present with its animations | - |

## Browser frame rate (Chrome 157, ANGLE D3D11, RTX 3080)

The window column is the real canvas size; the game's logical viewport stays 1280x720 under
canvas_items stretch, and 3D renders at the window size.

| Scene | Mode | Window | rAF fps | p95 frame | Godot fps | Godot mean | Draw calls |
| - | - | - | - | - | - | - | - |
| Hazewater (M_ZoneA) | vsync | 1280x720 | 141 | 7.0 ms | 144 | 7.1 ms | 228 |
| Hazewater | vsync | 1920x1080 | 144 | 7.0 ms | 144 | 6.9 ms | 247 |
| Hazewater | uncapped | 1280x720 | 206 | 6.0 ms | 208 | 4.8 ms | 232 |
| Hazewater | uncapped | 1920x1080 | 174 | 6.6 ms | 179 | 5.7 ms | 257 |
| Tallowford, 6 of 6 lamps lit (M_Square) | vsync | 1280x720 | 144 | 7.0 ms | 144 | 6.9 ms | 249 |
| Tallowford, lit | vsync | 1920x1080 | 144 | 7.0 ms | 144 | 7.0 ms | 235 |
| Tallowford, lit | uncapped | 1280x720 | 195 | 5.6 ms | 197 | 5.1 ms | 249 |
| Tallowford, lit | uncapped | 1920x1080 | 168 | 6.7 ms | 171 | 6.0 ms | 235 |
| Sedge Plain (M_Knoll) | vsync | 1280x720 | 141 | 7.0 ms | 144 | 7.1 ms | 663 |
| Sedge Plain | vsync | 1920x1080 | 134 | 13.9 ms | 144 | 7.5 ms | 751 |
| Sedge Plain | uncapped | 1280x720 | 155 | 8.2 ms | 170 | 6.4 ms | 650 |
| Sedge Plain | uncapped | 1920x1080 | 136 | 9.2 ms | 146 | 7.3 ms | 745 |
| Mosswater dark hollow, 15 of 15 lantern-fruit lit (M_DarkHollow) | vsync | 1280x720 | 133 | 13.9 ms | 129 | 7.5 ms | 851 |
| Mosswater, lit | vsync | 1920x1080 | 133 | 13.9 ms | 122 | 7.5 ms | 291 |
| Mosswater, lit | uncapped | 1280x720 | 136 | 9.9 ms | 152 | 7.4 ms | 826 |
| Mosswater, lit | uncapped | 1920x1080 | 130 | 10.1 ms | 110 | 7.7 ms | 291 |
| Hollow Kiln, the Dregs in its veil part (M_Arena_Entry) | vsync | 1280x720 | 142 | 7.0 ms | 144 | 7.0 ms | 281 |
| Hollow Kiln, fight | vsync | 1920x1080 | 143 | 7.0 ms | 138 | 7.0 ms | 306 |
| Hollow Kiln, fight | uncapped | 1280x720 | 184 | 6.7 ms | 196 | 5.4 ms | 285 |
| Hollow Kiln, fight | uncapped | 1920x1080 | 154 | 7.7 ms | 164 | 6.5 ms | 318 |

Sedge Plain's first window no longer stalls (F-020 closed): longest frame 19 ms.

## Visual sign-off (looked at by QA on 2026-11-16 and 2026-11-17)

- Stack captures docs/qa/stack/web_01_glyph_first_cast.jpg to web_12_end_card.jpg from the book run:
  all six stack items show; the ground marks are crisp ink flecks; the end card gives the whole
  book's totals.
- Paper screenshots docs/screenshots/valley_{light,normal,heavy}_{web,desktop}.png: all six retaken
  by this gate (same view, 1280x720). The old ones predated the HUD bead cord and the crisp ground
  marks. Heavy has deeper tooth, fibres and vignette and is greyer than Normal; web and desktop agree.
- Clouds: torn wash bands with a dark underline, no spiral (docs/qa/evidence/web_resume_continued.jpg).
- Levels 3 to 5 (the gates' web_level_*, web_perf_* and web_resume_* captures): looked at in order;
  the one thing still open is F-021 in FINDINGS.md.
