# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=mosswater&warp=M_DarkHollow&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.40s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9266 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 15 of 15 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":782} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":782} godot {"fps":134,"mean_ms":7.69,"p95_ms":9.72,"p99_ms":10.42,"max_ms":12.5,"process_ms":11.3,"render_cpu_ms":4.8,"render_gpu_ms":0,"draw_calls":856,"primitives":175268,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":127,"p50_ms":7,"p95_ms":13.9,"frames":761} godot {"fps":120,"mean_ms":7.91,"p95_ms":10.3,"p99_ms":10.7,"max_ms":15.06,"process_ms":9.8,"render_cpu_ms":2.4,"render_gpu_ms":0,"draw_calls":287,"primitives":46014,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":134,"p50_ms":7,"p95_ms":10,"frames":807} godot {"fps":150,"mean_ms":7.46,"p95_ms":9.72,"p99_ms":9.72,"max_ms":14.9,"process_ms":6.9,"render_cpu_ms":4.8,"render_gpu_ms":0,"draw_calls":857,"primitives":175782,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":127,"p50_ms":7.5,"p95_ms":10.4,"frames":763} godot {"fps":106,"mean_ms":7.89,"p95_ms":10.3,"p99_ms":12.96,"max_ms":15.3,"process_ms":14.5,"render_cpu_ms":2.3,"render_gpu_ms":0,"draw_calls":285,"primitives":45974,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 272 console lines |

screenshots: docs/qa/evidence/web_perf_mosswater_lit.jpg
console log: docs/qa/evidence/web_perf_mosswater_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 130,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 782
  },
  "godot": {
   "fps": 134,
   "mean_ms": 7.69,
   "p95_ms": 9.72,
   "p99_ms": 10.42,
   "max_ms": 12.5,
   "process_ms": 11.3,
   "render_cpu_ms": 4.8,
   "render_gpu_ms": 0,
   "draw_calls": 856,
   "primitives": 175268,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1280,
    720
   ]
  }
 },
 {
  "label": "vsync",
  "size": "1920x1080",
  "raf": {
   "fps": 127,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 761
  },
  "godot": {
   "fps": 120,
   "mean_ms": 7.91,
   "p95_ms": 10.3,
   "p99_ms": 10.7,
   "max_ms": 15.06,
   "process_ms": 9.8,
   "render_cpu_ms": 2.4,
   "render_gpu_ms": 0,
   "draw_calls": 287,
   "primitives": 46014,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1920,
    1080
   ]
  }
 },
 {
  "label": "uncapped",
  "size": "1280x720",
  "raf": {
   "fps": 134,
   "p50_ms": 7,
   "p95_ms": 10,
   "frames": 807
  },
  "godot": {
   "fps": 150,
   "mean_ms": 7.46,
   "p95_ms": 9.72,
   "p99_ms": 9.72,
   "max_ms": 14.9,
   "process_ms": 6.9,
   "render_cpu_ms": 4.8,
   "render_gpu_ms": 0,
   "draw_calls": 857,
   "primitives": 175782,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1280,
    720
   ]
  }
 },
 {
  "label": "uncapped",
  "size": "1920x1080",
  "raf": {
   "fps": 127,
   "p50_ms": 7.5,
   "p95_ms": 10.4,
   "frames": 763
  },
  "godot": {
   "fps": 106,
   "mean_ms": 7.89,
   "p95_ms": 10.3,
   "p99_ms": 12.96,
   "max_ms": 15.3,
   "process_ms": 14.5,
   "render_cpu_ms": 2.3,
   "render_gpu_ms": 0,
   "draw_calls": 285,
   "primitives": 45974,
   "viewport": [
    1280,
    720
   ],
   "window": [
    1920,
    1080
   ]
  }
 }
]
```
