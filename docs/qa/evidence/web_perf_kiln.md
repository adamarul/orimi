# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=hollow_kiln&warp=M_Arena_Entry&walk=2&expect_qa=dregs_part
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.37s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9936 ms)


| result | criterion | detail |
| - | - | - |
| ok | measured during dregs_part (the fight is running) | dregs_part {"part":"veil"} |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":142,"p50_ms":6.9,"p95_ms":7,"frames":852} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":142,"p50_ms":6.9,"p95_ms":7,"frames":852} godot {"fps":144,"mean_ms":7.04,"p95_ms":6.94,"p99_ms":7,"max_ms":62.71,"process_ms":5.4,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":281,"primitives":40076,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":143,"p50_ms":6.9,"p95_ms":7,"frames":859} godot {"fps":138,"mean_ms":7,"p95_ms":6.94,"p99_ms":6.94,"max_ms":39.93,"process_ms":52,"render_cpu_ms":2.5,"render_gpu_ms":0,"draw_calls":306,"primitives":63564,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":184,"p50_ms":5.3,"p95_ms":6.7,"frames":1109} godot {"fps":196,"mean_ms":5.42,"p95_ms":6.6,"p99_ms":7.41,"max_ms":55.8,"process_ms":6.8,"render_cpu_ms":2.4,"render_gpu_ms":0,"draw_calls":285,"primitives":40676,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":154,"p50_ms":6.3,"p95_ms":7.7,"frames":926} godot {"fps":164,"mean_ms":6.49,"p95_ms":6.94,"p99_ms":8.33,"max_ms":60.76,"process_ms":6.7,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":318,"primitives":64656,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 225 console lines |

screenshots: docs/qa/evidence/web_perf_kiln_fight.jpg
console log: docs/qa/evidence/web_perf_kiln_console.txt

```
[
 {
  "label": "vsync",
  "size": "1280x720",
  "raf": {
   "fps": 142,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 852
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.04,
   "p95_ms": 6.94,
   "p99_ms": 7,
   "max_ms": 62.71,
   "process_ms": 5.4,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 281,
   "primitives": 40076,
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
   "fps": 143,
   "p50_ms": 6.9,
   "p95_ms": 7,
   "frames": 859
  },
  "godot": {
   "fps": 138,
   "mean_ms": 7,
   "p95_ms": 6.94,
   "p99_ms": 6.94,
   "max_ms": 39.93,
   "process_ms": 52,
   "render_cpu_ms": 2.5,
   "render_gpu_ms": 0,
   "draw_calls": 306,
   "primitives": 63564,
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
   "frames": 1109
  },
  "godot": {
   "fps": 196,
   "mean_ms": 5.42,
   "p95_ms": 6.6,
   "p99_ms": 7.41,
   "max_ms": 55.8,
   "process_ms": 6.8,
   "render_cpu_ms": 2.4,
   "render_gpu_ms": 0,
   "draw_calls": 285,
   "primitives": 40676,
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
   "fps": 154,
   "p50_ms": 6.3,
   "p95_ms": 7.7,
   "frames": 926
  },
  "godot": {
   "fps": 164,
   "mean_ms": 6.49,
   "p95_ms": 6.94,
   "p99_ms": 8.33,
   "max_ms": 60.76,
   "process_ms": 6.7,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 318,
   "primitives": 64656,
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
