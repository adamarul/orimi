# Browser check: brush (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.92s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9769 ms)


| result | criterion | detail |
| - | - | - |
| ok | title -> playing with real input | states title > cutscene > playing, player [0,0.036,50] |
| ok | a circle is recognised as bloom | glyph_cast bloom score 0.977863551851068 |
| ok | a line is recognised as slash | glyph_cast slash score 0.994498322363749 |
| ok | a loop is recognised as gust | glyph_cast gust score 0.941129775708167 |
| ok | holding Shift opens the brush and freezes the world | 3 of 3 holds emitted brush_opened with the tree paused |
| ok | Brush.is_open() is true while held | 3 of 3 |
| ok | releasing resumes the world (brush_closed, tree unpaused) | 3 of 3 |
| ok | the captured mouse comes back after the brush closes | 3 of 3 |
| ok | ink drains when casting | Brush.ink 100 -> 61.7718903189994; ink_changed 100, 100, 99.5793815453847, 98.7422211170197, 97.9050614568922, 97.0679016113281, 96.2307421366374, 95.3935815758175 |
| ok | sepia view while open (before / during / after screenshots) | ok during differs from before; ok during is warm (hue 15-60); ok during is monochrome (hue spread < 30); ok during r>=g>=b on 70% of pixels; ok after returns toward before |
| ok | no console/page errors | 177 console lines |

screenshots: docs/qa/evidence/web_brush_before.jpg, docs/qa/evidence/web_brush_during.jpg, docs/qa/evidence/web_brush_after.jpg
console log: docs/qa/evidence/web_brush_console.txt

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
  "diff_before_during": 0.1273,
  "diff_before_after": 0.051,
  "mean_hue": 33.2,
  "hue_spread": 2.4,
  "warm_fraction": 1,
  "sat_before": 0.141,
  "sat_during": 0.3201
 },
 "summary": "ok during differs from before; ok during is warm (hue 15-60); ok during is monochrome (hue spread < 30); ok during r>=g>=b on 70% of pixels; ok after returns toward before"
}
```
