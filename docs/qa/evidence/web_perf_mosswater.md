# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=mosswater&warp=M_DarkHollow&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.52s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9550 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 15 of 15 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":781} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":130,"p50_ms":7,"p95_ms":13.9,"frames":781} godot {"fps":136,"mean_ms":7.73,"p95_ms":10.35,"p99_ms":10.7,"max_ms":12.13,"process_ms":8.2,"render_cpu_ms":4.8,"render_gpu_ms":0,"draw_calls":791,"primitives":168190,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":127,"p50_ms":7,"p95_ms":13.9,"frames":760} godot {"fps":119,"mean_ms":7.92,"p95_ms":10.1,"p99_ms":10.5,"max_ms":13.67,"process_ms":9.9,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":280,"primitives":44444,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":133,"p50_ms":7.1,"p95_ms":9.9,"frames":802} godot {"fps":152,"mean_ms":7.52,"p95_ms":9.72,"p99_ms":11.2,"max_ms":13.9,"process_ms":7.3,"render_cpu_ms":4.7,"render_gpu_ms":0,"draw_calls":819,"primitives":171470,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":127,"p50_ms":7.4,"p95_ms":10.3,"frames":765} godot {"fps":110,"mean_ms":7.87,"p95_ms":10.42,"p99_ms":11.08,"max_ms":13.17,"process_ms":10.2,"render_cpu_ms":3.1,"render_gpu_ms":0,"draw_calls":291,"primitives":46250,"viewport":[1280,720],"window":[1920,1080]} |
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
   "frames": 781
  },
  "godot": {
   "fps": 136,
   "mean_ms": 7.73,
   "p95_ms": 10.35,
   "p99_ms": 10.7,
   "max_ms": 12.13,
   "process_ms": 8.2,
   "render_cpu_ms": 4.8,
   "render_gpu_ms": 0,
   "draw_calls": 791,
   "primitives": 168190,
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
   "frames": 760
  },
  "godot": {
   "fps": 119,
   "mean_ms": 7.92,
   "p95_ms": 10.1,
   "p99_ms": 10.5,
   "max_ms": 13.67,
   "process_ms": 9.9,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 280,
   "primitives": 44444,
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
   "fps": 133,
   "p50_ms": 7.1,
   "p95_ms": 9.9,
   "frames": 802
  },
  "godot": {
   "fps": 152,
   "mean_ms": 7.52,
   "p95_ms": 9.72,
   "p99_ms": 11.2,
   "max_ms": 13.9,
   "process_ms": 7.3,
   "render_cpu_ms": 4.7,
   "render_gpu_ms": 0,
   "draw_calls": 819,
   "primitives": 171470,
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
   "p50_ms": 7.4,
   "p95_ms": 10.3,
   "frames": 765
  },
  "godot": {
   "fps": 110,
   "mean_ms": 7.87,
   "p95_ms": 10.42,
   "p99_ms": 11.08,
   "max_ms": 13.17,
   "process_ms": 10.2,
   "render_cpu_ms": 3.1,
   "render_gpu_ms": 0,
   "draw_calls": 291,
   "primitives": 46250,
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
