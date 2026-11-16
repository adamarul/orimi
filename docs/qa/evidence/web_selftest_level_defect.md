# Browser check: level (FAIL)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Ftests%2Ffixtures%2Fqa_fixture.tscn&autoplay=1&level=example&defect=level_fail
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.30s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9393 ms)


| result | criterion | detail |
| - | - | - |
| ok | autoplay reaches its end | after 7 s |
| FAIL | autoplay passed (no failed step) | passed false; failures: ["planted level_fail"] |
| FAIL | level example completes (level_complete) | level_complete: none |
| ok | no console/page errors | 95 console lines |

screenshots: .userdata/qa/full/docs/qa/evidence/web_selftest_level_defect_end.png
console log: docs/qa/evidence/web_selftest_level_defect_console.txt

image statistics:
```
{
 "levels": [
  "example"
 ]
}
```
