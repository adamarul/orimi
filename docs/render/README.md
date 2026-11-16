# Render evidence

Browser (Compatibility / WebGL 2) captures of the real game, downsized to JPEG. The full-size
PNGs stay in the gitignored `.userdata/`.

| File | What it shows |
| - | - |
| `web_before_after_M_Spawn.jpg`, `_M_ZoneA`, `_M_ZoneB`, `_M_Tree` | Left: c29af6f (before the second pass). Right: the second pass. Each was taken with `tools/smoke_web.sh --no-input --hold 22 --shot <png> warp=<warp> god=1`. Covers the curse wall, the cursed interior, and the world and character lines. |
| `web_paper_before_after.jpg` | Top row: Light / Normal / Heavy at c29af6f. Those three are the same image, because `paper=` did not reach Post in that build. Bottom row: after the second pass (`paper=light|normal|heavy`, warp=M_Spawn god=1). |
| `web_paper_after_crop.jpg` | 1:1 crops of the three presets after the pass, showing tooth, stain and fibres. |
| `perf_web.txt` | Browser frame time on the real valley at 1080p, with the chain on and off. |
| `probe_desktop.txt`, `probe_web.txt` and their `.png` files | Colour probe: 56 of 56 Palette patches, desktop and web. |

Light pools, curse and QA findings (light-pool pass):

| File | What it shows |
| - | - |
| `web_lights_drained.jpg`, `web_lights_dark.jpg` | `scenes/dev/render_lights.tscn` in the browser with 0, 1, 2 and 3 lamps lit (`mode=drained|dark lit=0..3`). |
| `web_lights_close.jpg` | One lamp lit, close view, drained and dark. A villager (folk), foliage and water are inside and outside the pool. |
| `web_curse_trunks_before_after.jpg` | Tall trunks in and on the rim of a cursed zone (`curse=1 view=curse`). Before: c5e0b88. |
| `qa_F008_06.jpg`, `qa_F008_08.jpg`, `qa_F008_09.jpg` | QA's stack captures at 3d3b7cb (left) next to the same autoplay moments from `tools/qa/qa.sh web_full` on this branch (right). |
| `web_paper_F007.jpg` | QA's `web_paper` captures after the saturation fix. |

`tools/render/capture_valley.sh <dir>` takes the four-warp set on desktop and web.
`tools/render/capture_evidence.sh` takes the dev demo set into `.userdata/render_demo/`.
