# DoD status (signed by QA)

State of each definition-of-done line from the gate on 85a62df (ws/qa with main 2019c4c merged,
which includes the README credits), 2026-11-15T23:24Z. Browser rows tested a fresh export of that
commit (build/web/qa_build.txt). Gate table: docs/qa/evidence/dod.md (26 PASS, 0 FAIL, 1 NOT YET).
Harness self-test on the same commit: 44 cases, 0 wrong outcomes (docs/qa/evidence/selftest.md).
Findings: docs/qa/FINDINGS.md.

Signed: QA, 2026-11-16.

| # | Definition of done | State | Why / evidence | Blocked by |
| - | - | - | - | - |
| 1 | Fresh Godot opens and runs the project, no script errors | PASS | check.sh; a fresh clone imports, checks and runs the main scene windowed; 6 of 6 scenes run windowed without errors | - |
| 2 | Browser: no console errors, playable title to finale, playable fps | PASS | Fresh export; main scene and 5 demos clean; input 16 criteria; manual title to thorn gate with a drawn slash; save, reload and Continue keep progress; no exported Packed*Array with a literal default | - |
| 3 | All six rendering-stack items visible in the web build | PASS | 12 stack captures from the book run (docs/qa/stack/); paper levels step the right way in tooth, vignette and saturation on web and desktop | - |
| 4 | Brush works end to end in the web build | PASS | Freeze, sepia view, circle / line / loop recognised from real pointer strokes, ink drains, world resumes (11 criteria) | - |
| 5 | Both enemies dissolve, zones restore, finale, clean end | PASS | Whole book by autoplay in 253 s: 23 deaths of both kinds, zone_a, zone_b and the tree restored, finale, Hazewater and Tallowford complete with their beads, 33 stages, end card, no console errors; level=tallowford and level=example pass | - |
| 6 | Models < 5k tris and from Blender scripts; textures/sounds from scripts | PASS | Every glTF within 5,000 triangles; every media file tied to a generator by hash | - |
| 7 | Banned-term scan clean, nothing derivative | NOT YET | Scan clean. Register and design review in docs/qa/ORIGINALITY.md; clouds open; levels 3 to 5 not built | F-015 (vfx) |
| 8 | README, SHADERS.md, three paper screenshots exist and match | PASS | README: run, controls, glyph guide, credits and licences, paper screenshots; 268 of 268 uniforms documented | - |
| all | Contract | PASS | API conforms to the stubs; every contract scene present with its animations | - |

## Browser frame rate (Chrome 157, ANGLE D3D11, RTX 3080)

The window column is the real canvas size; the game's logical viewport stays 1280x720 under
canvas_items stretch, and 3D renders at the window size.

| Scene | Mode | Window | rAF fps | p95 frame | Godot fps | Godot mean | Draw calls |
| - | - | - | - | - | - | - | - |
| Hazewater (M_ZoneA) | vsync | 1280x720 | 140 | 7.0 ms | 144 | 7.1 ms | 215 |
| Hazewater | vsync | 1920x1080 | 144 | 7.0 ms | 144 | 6.9 ms | 218 |
| Hazewater | uncapped | 1280x720 | 204 | 6.1 ms | 220 | 4.9 ms | 215 |
| Hazewater | uncapped | 1920x1080 | 173 | 7.2 ms | 178 | 5.8 ms | 220 |
| Tallowford, 6 of 6 lamps lit (M_Square) | vsync | 1280x720 | 143 | 7.0 ms | 144 | 7.0 ms | 228 |
| Tallowford, lit | vsync | 1920x1080 | 144 | 7.0 ms | 144 | 7.0 ms | 214 |
| Tallowford, lit | uncapped | 1280x720 | 194 | 5.8 ms | 194 | 5.2 ms | 228 |
| Tallowford, lit | uncapped | 1920x1080 | 162 | 7.1 ms | 158 | 6.2 ms | 214 |

## Visual sign-off (looked at by QA on 2026-11-16)

- Stack captures docs/qa/stack/web_01_glyph_first_cast.jpg to web_12_end_card.jpg from the book run:
  all six stack items show; the cursed-zone edge reads as a translucent dome over the ground.
- Paper screenshots docs/screenshots/valley_{light,normal,heavy}_{web,desktop}.png: Heavy has deeper
  tooth, fibres and vignette and is greyer than Normal; web and desktop agree.
- Tallowford (docs/levels/tallowford/shots/): village, lamps, cast and the jetty fight ring pass the
  "Ours, not theirs" review except the clouds (F-015).
