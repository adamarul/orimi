# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=mosswater&warp=M_DarkHollow&kindle=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.08s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (8914 ms)


| result | criterion | detail |
| - | - | - |
| ok | every lamp lit before measuring (kindle_all) | 15 of 15 kindle targets lit |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":127,"p50_ms":7,"p95_ms":13.9,"frames":763} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":127,"p50_ms":7,"p95_ms":13.9,"frames":763} godot {"fps":120,"mean_ms":7.91,"p95_ms":11.1,"p99_ms":11.11,"max_ms":12.6,"process_ms":11.1,"render_cpu_ms":5.8,"render_gpu_ms":0,"draw_calls":782,"primitives":168212,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":132,"p50_ms":7,"p95_ms":13.9,"frames":790} godot {"fps":117,"mean_ms":7.6,"p95_ms":10.42,"p99_ms":11.6,"max_ms":13.54,"process_ms":10.3,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":261,"primitives":45534,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":135,"p50_ms":6.8,"p95_ms":10.7,"frames":812} godot {"fps":133,"mean_ms":7.43,"p95_ms":10.42,"p99_ms":11.11,"max_ms":13.15,"process_ms":11.4,"render_cpu_ms":5.1,"render_gpu_ms":0,"draw_calls":785,"primitives":170290,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":137,"p50_ms":6.9,"p95_ms":10.4,"frames":821} godot {"fps":130,"mean_ms":7.33,"p95_ms":10.42,"p99_ms":10.8,"max_ms":12.15,"process_ms":10.6,"render_cpu_ms":2.3,"render_gpu_ms":0,"draw_calls":267,"primitives":45258,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 237 console lines |

screenshots: docs/qa/evidence/web_perf_mosswater_lit.jpg
console log: docs/qa/evidence/web_perf_mosswater_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 127,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 763
  },
  "godot": {
   "fps": 120,
   "mean_ms": 7.91,
   "p95_ms": 11.1,
   "p99_ms": 11.11,
   "max_ms": 12.6,
   "process_ms": 11.1,
   "render_cpu_ms": 5.8,
   "render_gpu_ms": 0,
   "draw_calls": 782,
   "primitives": 168212,
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
   "fps": 132,
   "p50_ms": 7,
   "p95_ms": 13.9,
   "frames": 790
  },
  "godot": {
   "fps": 117,
   "mean_ms": 7.6,
   "p95_ms": 10.42,
   "p99_ms": 11.6,
   "max_ms": 13.54,
   "process_ms": 10.3,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 261,
   "primitives": 45534,
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
   "fps": 135,
   "p50_ms": 6.8,
   "p95_ms": 10.7,
   "frames": 812
  },
  "godot": {
   "fps": 133,
   "mean_ms": 7.43,
   "p95_ms": 10.42,
   "p99_ms": 11.11,
   "max_ms": 13.15,
   "process_ms": 11.4,
   "render_cpu_ms": 5.1,
   "render_gpu_ms": 0,
   "draw_calls": 785,
   "primitives": 170290,
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
   "fps": 137,
   "p50_ms": 6.9,
   "p95_ms": 10.4,
   "frames": 821
  },
  "godot": {
   "fps": 130,
   "mean_ms": 7.33,
   "p95_ms": 10.42,
   "p99_ms": 10.8,
   "max_ms": 12.15,
   "process_ms": 10.6,
   "render_cpu_ms": 2.3,
   "render_gpu_ms": 0,
   "draw_calls": 267,
   "primitives": 45258,
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
