# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=mosswater&warp=M_DarkHollow&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.44s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10065 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 15 of 15 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":783} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":783} godot {"fps":135,"mean_ms":7.69,"p95_ms":9.72,"p99_ms":9.8,"max_ms":11.4,"process_ms":12.5,"render_cpu_ms":4.6,"render_gpu_ms":0,"draw_calls":825,"primitives":171806,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":128,"p50_ms":7,"p95_ms":13.9,"frames":767} godot {"fps":119,"mean_ms":7.83,"p95_ms":10.42,"p99_ms":11.18,"max_ms":13.08,"process_ms":10.7,"render_cpu_ms":2.2,"render_gpu_ms":0,"draw_calls":285,"primitives":45974,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":129,"p50_ms":7.3,"p95_ms":10.5,"frames":774} godot {"fps":128,"mean_ms":7.77,"p95_ms":10.19,"p99_ms":11.67,"max_ms":15.2,"process_ms":10.2,"render_cpu_ms":5.4,"render_gpu_ms":0,"draw_calls":856,"primitives":175268,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":122,"p50_ms":7.7,"p95_ms":11,"frames":736} godot {"fps":110,"mean_ms":8.18,"p95_ms":11.11,"p99_ms":11.71,"max_ms":17.1,"process_ms":14.2,"render_cpu_ms":2.2,"render_gpu_ms":0,"draw_calls":293,"primitives":46866,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 271 console lines |

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
   "frames": 783
  },
  "godot": {
   "fps": 135,
   "mean_ms": 7.69,
   "p95_ms": 9.72,
   "p99_ms": 9.8,
   "max_ms": 11.4,
   "process_ms": 12.5,
   "render_cpu_ms": 4.6,
   "render_gpu_ms": 0,
   "draw_calls": 825,
   "primitives": 171806,
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
   "fps": 128,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 767
  },
  "godot": {
   "fps": 119,
   "mean_ms": 7.83,
   "p95_ms": 10.42,
   "p99_ms": 11.18,
   "max_ms": 13.08,
   "process_ms": 10.7,
   "render_cpu_ms": 2.2,
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
 },
 {
  "label": "uncapped",
  "size": "1280x720",
  "raf": {
   "fps": 129,
   "p50_ms": 7.3,
   "p95_ms": 10.5,
   "frames": 774
  },
  "godot": {
   "fps": 128,
   "mean_ms": 7.77,
   "p95_ms": 10.19,
   "p99_ms": 11.67,
   "max_ms": 15.2,
   "process_ms": 10.2,
   "render_cpu_ms": 5.4,
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
  "label": "uncapped",
  "size": "1920x1080",
  "raf": {
   "fps": 122,
   "p50_ms": 7.7,
   "p95_ms": 11,
   "frames": 736
  },
  "godot": {
   "fps": 110,
   "mean_ms": 8.18,
   "p95_ms": 11.11,
   "p99_ms": 11.71,
   "max_ms": 17.1,
   "process_ms": 14.2,
   "render_cpu_ms": 2.2,
   "render_gpu_ms": 0,
   "draw_calls": 293,
   "primitives": 46866,
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
