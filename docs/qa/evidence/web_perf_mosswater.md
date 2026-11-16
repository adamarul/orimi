# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=mosswater&warp=M_DarkHollow&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.60s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9103 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 15 of 15 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":133,"p50_ms":7,"p95_ms":13.9,"frames":798} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":133,"p50_ms":7,"p95_ms":13.9,"frames":798} godot {"fps":129,"mean_ms":7.54,"p95_ms":9.52,"p99_ms":9.72,"max_ms":12.3,"process_ms":11,"render_cpu_ms":4.7,"render_gpu_ms":0,"draw_calls":851,"primitives":175038,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":133,"p50_ms":7,"p95_ms":13.9,"frames":797} godot {"fps":122,"mean_ms":7.54,"p95_ms":9.72,"p99_ms":10.1,"max_ms":10.9,"process_ms":9.5,"render_cpu_ms":2.2,"render_gpu_ms":0,"draw_calls":291,"primitives":46134,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":136,"p50_ms":7,"p95_ms":9.9,"frames":816} godot {"fps":152,"mean_ms":7.38,"p95_ms":9.52,"p99_ms":10.42,"max_ms":12.1,"process_ms":7.1,"render_cpu_ms":4.6,"render_gpu_ms":0,"draw_calls":826,"primitives":171180,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":130,"p50_ms":7.3,"p95_ms":10.1,"frames":784} godot {"fps":110,"mean_ms":7.68,"p95_ms":10,"p99_ms":10.42,"max_ms":11.2,"process_ms":10.1,"render_cpu_ms":2.1,"render_gpu_ms":0,"draw_calls":291,"primitives":46290,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 272 console lines |

screenshots: docs/qa/evidence/web_perf_mosswater_lit.jpg
console log: docs/qa/evidence/web_perf_mosswater_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 133,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 798
  },
  "godot": {
   "fps": 129,
   "mean_ms": 7.54,
   "p95_ms": 9.52,
   "p99_ms": 9.72,
   "max_ms": 12.3,
   "process_ms": 11,
   "render_cpu_ms": 4.7,
   "render_gpu_ms": 0,
   "draw_calls": 851,
   "primitives": 175038,
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
   "fps": 133,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 797
  },
  "godot": {
   "fps": 122,
   "mean_ms": 7.54,
   "p95_ms": 9.72,
   "p99_ms": 10.1,
   "max_ms": 10.9,
   "process_ms": 9.5,
   "render_cpu_ms": 2.2,
   "render_gpu_ms": 0,
   "draw_calls": 291,
   "primitives": 46134,
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
   "fps": 136,
   "p50_ms": 7,
   "p95_ms": 9.9,
   "frames": 816
  },
  "godot": {
   "fps": 152,
   "mean_ms": 7.38,
   "p95_ms": 9.52,
   "p99_ms": 10.42,
   "max_ms": 12.1,
   "process_ms": 7.1,
   "render_cpu_ms": 4.6,
   "render_gpu_ms": 0,
   "draw_calls": 826,
   "primitives": 171180,
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
   "fps": 130,
   "p50_ms": 7.3,
   "p95_ms": 10.1,
   "frames": 784
  },
  "godot": {
   "fps": 110,
   "mean_ms": 7.68,
   "p95_ms": 10,
   "p99_ms": 10.42,
   "max_ms": 11.2,
   "process_ms": 10.1,
   "render_cpu_ms": 2.1,
   "render_gpu_ms": 0,
   "draw_calls": 291,
   "primitives": 46290,
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
