# Browser check: paper (FAIL)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1&paper=light&warp=M_Spawn&defect=paper_stuck
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=5.16s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9738 ms)


| result | criterion | detail |
| - | - | - |
| ok | boot option paper=light honoured (info; finding F-001) | Settings.paper_intensity 1 at start (ignored: Settings reads Boot.opt before Boot parses options) |
| FAIL | paper light selected in game (O key) | Settings.paper_intensity 1 |
| ok | paper normal selected in game (O key) | Settings.paper_intensity 1 |
| FAIL | paper heavy selected in game (O key) | Settings.paper_intensity 1 |
| FAIL | Light, Normal, Heavy differ in the expected direction | ok all three differ; NOT tooth Heavy > Normal; ok tooth Heavy > Light; NOT vignette Light < Normal; NOT vignette Normal < Heavy; NOT saturation Heavy < Normal |
| ok | no console/page errors | 50 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_selftest_paper_stuck_light.png, .userdata/qa/full/docs/qa/evidence/web_selftest_paper_stuck_normal.png, .userdata/qa/full/docs/qa/evidence/web_selftest_paper_stuck_heavy.png
console log: docs/qa/evidence/web_selftest_paper_stuck_console.txt

image statistics:
```
{
 "pass": false,
 "checks": {
  "all three differ": true,
  "tooth Heavy > Normal": false,
  "tooth Heavy > Light": true,
  "vignette Light < Normal": false,
  "vignette Normal < Heavy": false,
  "saturation Heavy < Normal": false
 },
 "metrics": {
  "light": {
   "tooth": 0.01789,
   "vignette": 1.1018,
   "saturation": 0.1459
  },
  "normal": {
   "tooth": 0.01801,
   "vignette": 1.0997,
   "saturation": 0.1459
  },
  "heavy": {
   "tooth": 0.01795,
   "vignette": 1.0988,
   "saturation": 0.1459
  }
 },
 "pair_diffs": {
  "light-normal": 0.0056,
  "normal-heavy": 0.0053,
  "light-heavy": 0.0053
 },
 "summary": "ok all three differ; NOT tooth Heavy > Normal; ok tooth Heavy > Light; NOT vignette Light < Normal; NOT vignette Normal < Heavy; NOT saturation Heavy < Normal"
}
```
