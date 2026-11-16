# Browser check: brush (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.50s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10645 ms)


| result | criterion | detail |
| - | - | - |
| ok | title -> playing with real input | states title > playing, player [0,0,50] |
| ok | a circle is recognised as bloom | glyph_cast bloom score 0.9 |
| ok | a line is recognised as slash | glyph_cast slash score 0.9 |
| ok | a loop is recognised as gust | glyph_cast gust score 0.9 |
| ok | holding Shift opens the brush and freezes the world | 3 of 3 holds emitted brush_opened with the tree paused |
| ok | releasing resumes the world (brush_closed, tree unpaused) | 3 of 3 |
| ok | the captured mouse comes back after the brush closes | 3 of 3 |
| ok | ink drains when casting | Brush.ink 100 -> 80.154178888887; ink_changed 90, 90.5159055555556, 91.0228188888888, 91.5262588888887, 81.5609788888887, 82.0644188888886, 82.5678588888885, 83.0712988888884 |
| ok | sepia view while open (before / during / after screenshots) | ok during differs from before; ok during is warm (hue 15-60); ok during is monochrome (hue spread < 30); ok during r>=g>=b on 70% of pixels; ok after returns toward before |
| ok | no console/page errors | 99 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_brush_before.png, .userdata/qa/full/docs/qa/evidence/web_brush_during.png, .userdata/qa/full/docs/qa/evidence/web_brush_after.png
console log: docs/qa/evidence/web_selftest_brush_ok_console.txt

image statistics:
```
{
 "pass": true,
 "checks": {
  "during differs from before": true,
  "during is warm (hue 15-60)": true,
  "during is monochrome (hue spread < 30)": true,
  "during r>=g>=b on 70% of pixels": true,
  "after returns toward before": true
 },
 "values": {
  "diff_before_during": 0.2504,
  "diff_before_after": 0.0052,
  "mean_hue": 33.6,
  "hue_spread": 1.2,
  "warm_fraction": 1,
  "sat_before": 0.1458,
  "sat_during": 0.4473
 },
 "summary": "ok during differs from before; ok during is warm (hue 15-60); ok during is monochrome (hue spread < 30); ok during r>=g>=b on 70% of pixels; ok after returns toward before"
}
```
