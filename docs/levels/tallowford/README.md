# Tallowford, phase A: what exists and how it was checked

Everything here is generated. `tools/levels/tallowford/gen.sh` rebuilds the layout data, plan,
docs tables, level data, terrain and models; `tools/assets/gen_folk.sh tools/levels/tallowford/folk.json`
rebuilds the cast. Design: DESIGN.md. Script: SCRIPT.md. Plan: plan.png.

## Files

- `tools/levels/tallowford/`: layout.py (every marker, house, prop, path and the height field),
  plan.py, docs.py, level_data.py, make_terrain.py, paint_terrain.py, tf_models.py, make_model.py,
  paint_models.py, godot_import.py, write_provenance.py, gen.sh, folk.json.
- `scripts/levels/tallowford/`: layout.json, script.json, tallowford.gd (the level script),
  dressing.gd (shared with the look-dev), kindle_lamp.gd (our lamps on the kit's KindleTarget),
  lookdev.gd.
- `scenes/levels/tallowford/`: level.json (kit data file and assembly plan), lookdev.tscn,
  models/*.tscn (wrappers with an InkLook), folk/*.tscn (FolkPerson wrappers).
- `assets/levels/tallowford/`: models/*.glb with materials, textures/*.png, folk/ (the cast);
  provenance.json in assets/levels/tallowford and in folk/.

## Budgets

| Model | Triangles | Texture |
| - | - | - |
| tallowford_terrain (ground 4,450 + ridges 384) | 4,834 | tallowford_ground 2048, tallowford_hills 1024 |
| tallowford_river | 180 | water material |
| persimmon | 1,964 | 1024 |
| house_trim | 1,218 | 1024 |
| house_brindle | 986 | 1024 |
| house_marrow | 904 | 1024 |
| house_children | 896 | 1024 |
| dye_vats | 822 | 512 |
| house_ferry | 746 | 1024 |
| cottage (x4) | 708 | 1024 |
| shed (x3) | 660 | 1024 |
| ford_lamp | 594 | 1024 |
| cloth_line | 390 | 512 |
| well | 388 | 512 |
| jetty | 376 | 512 |
| drying_rack | 256 | 512 |
| lamp_post (x9) | 180 | 512 |
| fence | 120 | 512 |
| landing | 112 | 512 |
| Folk: fisher, baker, marrow, netmender, wherry, brindle, old_trim, pibbet, flax | 578, 562, 558, 550, 548, 520, 520, 514, 474 | 512 woken + 512 faded each |

Every model is within the 5,000-triangle budget (`tools/qa/qa.sh tris` passes) and every
generated file has a provenance entry (`tools/qa/qa.sh provenance` reports no Tallowford problems).

Build size: the imported resources for assets/levels/tallowford come to 3.01 MB in the import
cache (65 files), plus 0.12 MB of scenes, scripts, materials and JSON. So the level adds about
3.1 MB to the web pack, which is 10.25 MB in total. The figure comes from the import cache, not
from comparing two exports. Source files: 1.67 MB of glb and 9.60 MB of png.

## Look-dev

`scenes/levels/tallowford/lookdev.tscn` takes these options: `state=drained|partial|fight|restored`,
`view=1..8` (arrival, square, dye yard, well, jetty square, ford-lamp, overview, from the jetty),
`cycle=1`, `path=1` and `fps=1`. For example:

    tools/screenshot_desktop.sh out.png scene=res://scenes/levels/tallowford/lookdev.tscn state=partial view=4

Captures in `shots/` are 1280x720 JPEGs. The `web_*` files are from the browser (WebGL 2,
Compatibility) and the rest are from desktop (Forward+, Vulkan). Every run logged no errors.
They were retaken on ws/l2 on main 81fcd2f with Tallowford's own drained tint (DESIGN.md,
"Light"): colour inside the lamps' pools and an amber-grey dusk outside them until the finale.
`shots/lightpools_compare_*.jpg` are browser before (render's LightPools defaults, look-dev
option `tint=default`) and after (ours) shots of the dye yard and the well.

| Shot | State | View |
| - | - | - |
| drained_v1, web_drained_v1 | drained | arrival from the landing |
| drained_v2 | drained | the square, bare persimmon, grey neighbours |
| partial_v3 | Trim, Marrow, Brindle lit | dye yard |
| partial_v4, web_partial_v4 | the same | well, Brindle's pool |
| fight_v5, web_fight_v5 | five lamps lit, before the sealed fight | jetty square |
| restored_v2, restored_v3, restored_v6, restored_v7, restored_v8, web_restored_v7 | restored | square, dye yard, ford-lamp, overview, from the jetty |

Browser frame rate (headless Chrome with the real GPU, 1280x720, TF_FPS every 2 s over 12 s):
drained arrival 84 to 107, partial well 124 to 144, fight 122 to 144, restored overview 81 to
106. The display caps it at 144.

## Phase B: the playable level

`tools/game/web_autoplay.sh` (a fresh export of this worktree, then Chrome on the real GPU at
1280x720) plays the whole book on main 1cf1227: Hazewater Vale, Pell's raft, then Tallowford to
its end card and back to the title, 32 stages in 245 s. Both levels complete, award their bead and
save progress; every glyph is drawn through the brush (no simulated casts) and the console logs
no errors. The music goes from the vale tracks to `tallowford_cursed` and, at the ford-lamp,
`tallowford_restored`. `tools/game/autoplay_headless.sh level=tallowford` passes too. Browser
frame rate at Tallowford's stages: arrival 124, verse_1_read 107, trim_lit 89, marrow_lit 142,
brindle_lit 136, children_lit 144, jetty_held 144, finale 85 (not yet profiled; the finale camera
sees the whole village and every pool at once), end_card 143; spawn (62) was sampled while the
level loaded. The stage shots `shots/play_*.jpg` are Tallowford's stages from that run:
`play_09_finale` is the finale camera with the villagers gathered by the jetty, `play_10_end_card`
is Tallowford's own end card.

The collision walk, `tools/game/autoplay_headless.sh level=tallowford tf_route=walk` (see
DESIGN.md), passes with every `go` arriving and no `tf_snag`. Its first run found a fence
across cottage 4's front yard and a cloth line's collider on the edge of lane_dye_well (both
moved), and that a QA warp past the jetty fight left its ring live (the kit's SealedFight now
starts won when its done_flag is set, so the level script no longer patches it).

The raft departure (main d787566) in the browser, from `web_autoplay.sh level=tallowford`:
`shots/play_raft_framed.jpg` (the raft gliding in past the pier end), `play_raft_in.jpg`
(moored clear of the pier, Pell aboard) and `play_raft_off.jpg` (Orimi and Pell pushing off
upriver).

Run it yourself with `level=tallowford`; `warp=<marker>` starts at any beat (M_Verse_1,
M_Lamp_Trim, M_DyeVats, M_Well, M_Persimmon, M_JettySquare, M_FordLamp, M_PellWait).
