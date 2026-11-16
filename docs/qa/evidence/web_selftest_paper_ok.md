# Browser check: paper (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1&paper=light&warp=M_Spawn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=5.13s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9556 ms)


| result | criterion | detail |
| - | - | - |
| ok | boot option paper=light honoured (info; finding F-001) | Settings.paper_intensity 0 at start |
| ok | paper light selected in game (O key) | Settings.paper_intensity 0 |
| ok | paper normal selected in game (O key) | Settings.paper_intensity 1 |
| ok | paper heavy selected in game (O key) | Settings.paper_intensity 2 |
| ok | Light, Normal, Heavy differ in the expected direction | ok all three differ; ok tooth Heavy > Normal; ok tooth Heavy > Light; ok vignette Light < Normal; ok vignette Normal < Heavy; ok saturation Heavy < Normal |
| ok | no console/page errors | 46 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_selftest_paper_ok_light.png, .userdata/qa/full/docs/qa/evidence/web_selftest_paper_ok_normal.png, .userdata/qa/full/docs/qa/evidence/web_selftest_paper_ok_heavy.png
console log: docs/qa/evidence/web_selftest_paper_ok_console.txt

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
   "tooth": 0.00801,
   "vignette": 0.9456,
   "saturation": 0.1608
  },
  "normal": {
   "tooth": 0.01796,
   "vignette": 1.1016,
   "saturation": 0.146
  },
  "heavy": {
   "tooth": 0.0348,
   "vignette": 1.3071,
   "saturation": 0.1287
  }
 },
 "pair_diffs": {
  "light-normal": 0.0586,
  "normal-heavy": 0.0613,
  "light-heavy": 0.1175
 },
 "summary": "ok all three differ; ok tooth Heavy > Normal; ok tooth Heavy > Light; ok vignette Light < Normal; ok vignette Normal < Heavy; ok saturation Heavy < Normal"
}
```
