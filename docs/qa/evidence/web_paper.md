# Browser check: paper (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&paper=light&warp=M_Spawn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.52s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9098 ms)


| result | criterion | detail |
| - | - | - |
| ok | boot option paper=light honoured (info; finding F-001) | Settings.paper_intensity 0 at start |
| ok | paper light selected in game (O key) | Settings.paper_intensity 0 |
| ok | paper normal selected in game (O key) | Settings.paper_intensity 1 |
| ok | paper heavy selected in game (O key) | Settings.paper_intensity 2 |
| ok | Light, Normal, Heavy differ in the expected direction | ok all three differ; ok tooth Heavy > Normal; ok tooth Heavy > Light; ok vignette Light < Normal; ok vignette Normal < Heavy; ok saturation Heavy < Normal |
| ok | no console/page errors | 58 console lines |

screenshots: docs/screenshots/valley_light_web.png, docs/screenshots/valley_normal_web.png, docs/screenshots/valley_heavy_web.png
console log: docs/qa/evidence/web_paper_console.txt

image statistics:
```
{
 "pass": true,
 "checks": {
  "all three differ": true,
  "tooth Heavy > Normal": true,
  "tooth Heavy > Light": true,
  "vignette Light < Normal": true,
  "vignette Normal < Heavy": true,
  "saturation Heavy < Normal": true
 },
 "metrics": {
  "light": {
   "tooth": 0.02138,
   "vignette": 0.9456,
   "saturation": 0.1506
  },
  "normal": {
   "tooth": 0.02774,
   "vignette": 1.0617,
   "saturation": 0.1438
  },
  "heavy": {
   "tooth": 0.03727,
   "vignette": 1.1917,
   "saturation": 0.1356
  }
 },
 "pair_diffs": {
  "light-normal": 0.049,
  "normal-heavy": 0.0808,
  "light-heavy": 0.1155
 },
 "summary": "ok all three differ; ok tooth Heavy > Normal; ok tooth Heavy > Light; ok vignette Light < Normal; ok vignette Normal < Heavy; ok saturation Heavy < Normal"
}
```
