# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=hollow_kiln&warp=M_Arena_Entry&walk=2&expect_qa=dregs_part
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.84s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9033 ms)


| result | criterion | detail |
| - | - | - |
| ok | measured during dregs_part (the fight is running) | dregs_part {"part":"veil"} |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":849} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":849} godot {"fps":136,"mean_ms":7.08,"p95_ms":6.94,"p99_ms":8.25,"max_ms":55.55,"process_ms":58.1,"render_cpu_ms":2.3,"render_gpu_ms":0,"draw_calls":268,"primitives":37002,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":141,"p50_ms":6.9,"p95_ms":7,"frames":850} godot {"fps":144,"mean_ms":7.07,"p95_ms":7.14,"p99_ms":8.33,"max_ms":38.89,"process_ms":6.4,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":306,"primitives":63540,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":184,"p50_ms":5.3,"p95_ms":6.7,"frames":1104} godot {"fps":186,"mean_ms":5.45,"p95_ms":6.3,"p99_ms":7,"max_ms":57.6,"process_ms":7.7,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":285,"primitives":40636,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":145,"p50_ms":6.8,"p95_ms":8,"frames":871} godot {"fps":151,"mean_ms":6.91,"p95_ms":7.41,"p99_ms":8.7,"max_ms":56.9,"process_ms":7,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":330,"primitives":65312,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 232 console lines |

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
   "fps": 136,
   "mean_ms": 7.08,
   "p95_ms": 6.94,
   "p99_ms": 8.25,
   "max_ms": 55.55,
   "process_ms": 58.1,
   "render_cpu_ms": 2.3,
   "render_gpu_ms": 0,
   "draw_calls": 268,
   "primitives": 37002,
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
   "frames": 850
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.07,
   "p95_ms": 7.14,
   "p99_ms": 8.33,
   "max_ms": 38.89,
   "process_ms": 6.4,
   "render_cpu_ms": 2.5,
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
 },
 {
  "label": "uncapped",
  "size": "1280x720",
  "raf": {
   "fps": 184,
   "p50_ms": 5.3,
   "p95_ms": 6.7,
   "frames": 1104
  },
  "godot": {
   "fps": 186,
   "mean_ms": 5.45,
   "p95_ms": 6.3,
   "p99_ms": 7,
   "max_ms": 57.6,
   "process_ms": 7.7,
   "render_cpu_ms": 2.5,
   "render_gpu_ms": 0,
   "draw_calls": 285,
   "primitives": 40636,
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
   "p95_ms": 8,
   "frames": 871
  },
  "godot": {
   "fps": 151,
   "mean_ms": 6.91,
   "p95_ms": 7.41,
   "p99_ms": 8.7,
   "max_ms": 56.9,
   "process_ms": 7,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 330,
   "primitives": 65312,
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
