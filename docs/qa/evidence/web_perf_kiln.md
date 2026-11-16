# Browser check: perf (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1&level=hollow_kiln&warp=M_Arena_Entry&walk=2&expect_qa=dregs_part
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.22s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (8800 ms)


| result | criterion | detail |
| - | - | - |
| ok | measured during dregs_part (the fight is running) | dregs_part {"part":"veil"} |
| ok | playable at 1280x720 (rAF >= 30 fps, p95 frame <= 50 ms) | {"fps":142,"p50_ms":6.9,"p95_ms":7.1,"frames":852} |
| ok | measured vsync 1280x720 (info) | rAF {"fps":142,"p50_ms":6.9,"p95_ms":7.1,"frames":852} godot {"fps":144,"mean_ms":7.02,"p95_ms":6.94,"p99_ms":7.67,"max_ms":40.27,"process_ms":5.8,"render_cpu_ms":3.1,"render_gpu_ms":0,"draw_calls":242,"primitives":39272,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured vsync 1920x1080 (info) | rAF {"fps":140,"p50_ms":6.9,"p95_ms":7.1,"frames":838} godot {"fps":144,"mean_ms":7.16,"p95_ms":7.58,"p99_ms":8.33,"max_ms":55.12,"process_ms":5.9,"render_cpu_ms":2.7,"render_gpu_ms":0,"draw_calls":303,"primitives":64350,"viewport":[1280,720],"window":[1920,1080]} |
| ok | measured uncapped 1280x720 (info) | rAF {"fps":181,"p50_ms":5.3,"p95_ms":7.3,"frames":1086} godot {"fps":209,"mean_ms":5.53,"p95_ms":7.24,"p99_ms":8.33,"max_ms":57.5,"process_ms":6.6,"render_cpu_ms":2.6,"render_gpu_ms":0,"draw_calls":237,"primitives":39066,"viewport":[1280,720],"window":[1280,720]} |
| ok | measured uncapped 1920x1080 (info) | rAF {"fps":160,"p50_ms":6.1,"p95_ms":7.6,"frames":963} godot {"fps":169,"mean_ms":6.24,"p95_ms":6.94,"p99_ms":8.08,"max_ms":59.12,"process_ms":6.4,"render_cpu_ms":3.2,"render_gpu_ms":0,"draw_calls":409,"primitives":71986,"viewport":[1280,720],"window":[1920,1080]} |
| ok | no console/page errors | 219 console lines |

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
   "p95_ms": 7.1,
   "frames": 852
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.02,
   "p95_ms": 6.94,
   "p99_ms": 7.67,
   "max_ms": 40.27,
   "process_ms": 5.8,
   "render_cpu_ms": 3.1,
   "render_gpu_ms": 0,
   "draw_calls": 242,
   "primitives": 39272,
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
   "fps": 140,
   "p50_ms": 6.9,
   "p95_ms": 7.1,
   "frames": 838
  },
  "godot": {
   "fps": 144,
   "mean_ms": 7.16,
   "p95_ms": 7.58,
   "p99_ms": 8.33,
   "max_ms": 55.12,
   "process_ms": 5.9,
   "render_cpu_ms": 2.7,
   "render_gpu_ms": 0,
   "draw_calls": 303,
   "primitives": 64350,
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
   "fps": 181,
   "p50_ms": 5.3,
   "p95_ms": 7.3,
   "frames": 1086
  },
  "godot": {
   "fps": 209,
   "mean_ms": 5.53,
   "p95_ms": 7.24,
   "p99_ms": 8.33,
   "max_ms": 57.5,
   "process_ms": 6.6,
   "render_cpu_ms": 2.6,
   "render_gpu_ms": 0,
   "draw_calls": 237,
   "primitives": 39066,
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
   "fps": 160,
   "p50_ms": 6.1,
   "p95_ms": 7.6,
   "frames": 963
  },
  "godot": {
   "fps": 169,
   "mean_ms": 6.24,
   "p95_ms": 6.94,
   "p99_ms": 8.08,
   "max_ms": 59.12,
   "process_ms": 6.4,
   "render_cpu_ms": 3.2,
   "render_gpu_ms": 0,
   "draw_calls": 409,
   "primitives": 71986,
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
