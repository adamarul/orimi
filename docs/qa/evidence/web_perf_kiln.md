# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=hollow_kiln&warp=M_Arena_Entry&walk=2&expect_qa=dregs_part
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.48s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9777 ms)


| result | criterion | detail |
| - | - | - |
| ok | measured during dregs_part (the fight is running) | dregs_part {"part":"veil"} |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":849} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":849} godot {"fps":143,"mean_ms":7.07,"p95_ms":6.94,"p99_ms":7.14,"max_ms":43.63,"process_ms":10.1,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":268,"primitives":38998,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":848} godot {"fps":137,"mean_ms":7.08,"p95_ms":7.41,"p99_ms":7.58,"max_ms":55.51,"process_ms":53.8,"render_cpu_ms":2.8,"render_gpu_ms":0,"draw_calls":302,"primitives":63268,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":183,"p50_ms":5.3,"p95_ms":6.7,"frames":1099} godot {"fps":185,"mean_ms":5.47,"p95_ms":6.67,"p99_ms":7.58,"max_ms":57.94,"process_ms":8.1,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":283,"primitives":40596,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":145,"p50_ms":6.8,"p95_ms":7.8,"frames":871} godot {"fps":150,"mean_ms":6.9,"p95_ms":7.53,"p99_ms":8.9,"max_ms":52.78,"process_ms":9.8,"render_cpu_ms":3.1,"render_gpu_ms":0,"draw_calls":306,"primitives":63540,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 231 console lines |

screenshots: docs/qa/evidence/web_perf_kiln_fight.jpg
console log: docs/qa/evidence/web_perf_kiln_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 141,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 849
  },
  "godot": {
   "fps": 143,
   "mean_ms": 7.07,
   "p95_ms": 6.94,
   "p99_ms": 7.14,
   "max_ms": 43.63,
   "process_ms": 10.1,
   "render_cpu_ms": 2.5,
   "render_gpu_ms": 0,
   "draw_calls": 268,
   "primitives": 38998,
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
   "fps": 141,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 848
  },
  "godot": {
   "fps": 137,
   "mean_ms": 7.08,
   "p95_ms": 7.41,
   "p99_ms": 7.58,
   "max_ms": 55.51,
   "process_ms": 53.8,
   "render_cpu_ms": 2.8,
   "render_gpu_ms": 0,
   "draw_calls": 302,
   "primitives": 63268,
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
   "fps": 183,
   "p50_ms": 5.3,
   "p95_ms": 6.7,
   "frames": 1099
  },
  "godot": {
   "fps": 185,
   "mean_ms": 5.47,
   "p95_ms": 6.67,
   "p99_ms": 7.58,
   "max_ms": 57.94,
   "process_ms": 8.1,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 283,
   "primitives": 40596,
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
   "fps": 145,
   "p50_ms": 6.8,
   "p95_ms": 7.8,
   "frames": 871
  },
  "godot": {
   "fps": 150,
   "mean_ms": 6.9,
   "p95_ms": 7.53,
   "p99_ms": 8.9,
   "max_ms": 52.78,
   "process_ms": 9.8,
   "render_cpu_ms": 3.1,
   "render_gpu_ms": 0,
   "draw_calls": 306,
   "primitives": 63540,
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
