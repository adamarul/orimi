# Browser frame rate (vfx demo)

Measured with `tools/vfx/shots_web.sh --perf 30 [foliage=N]` against the web export from
`tools/export_web.sh`, in Chrome 157 with WebGL 2 (ANGLE, D3D11, RTX 3080) on a 144 Hz display.
The demo ran its whole effect sequence with no peak pauses for 30 s. `raf_fps` is the browser's
requestAnimationFrame rate per second and `game_fps` is the engine's `ORIMI_FPS` per second.

| Foliage cards | raf_fps (min / typical) | game_fps (min after load / typical) | First frame |
|---|---|---|---|
| 300 (demo default) | 126 / 144 | 144 / 144 (83 in the first second) | 19.0 s |
| 500 | 124 / 144 | 97 / 144 (46 in the first second) | 17.8 s |
| 2000 | 122 / 144 | 95 / 144 (10 in the first second) | 19.0 s |

Every run held the 144 Hz vsync cap except brief dips, which line up with effect bursts and
shader first-use. This is one fast desktop GPU, so it only shows that the effects and 2000
foliage cards are not the bottleneck there; it says nothing about integrated or mobile GPUs.
Raw logs of each run are in `perf_300/`, `perf_500/` and `perf_2000/`.

## Level-kit effects (set=kit)

`tools/vfx/shots_web.sh --perf 40 set=kit step_time=1.2` played the 16 kit effects back to back
(a new effect every 1.2 s) for 40 s in Chrome 157, WebGL 2, ANGLE D3D11, RTX 3080 at 144 Hz. The
same run of the main demo is beside it for comparison.

| Run | raf_fps after the first second (min / typical) | game_fps after the first second (min / typical) |
|---|---|---|
| kit effects | 121 / 144 | 93 / 144 |
| main demo, same settings | 105 / 144 | 97 / 144 |

No frame second dropped below 93 fps after loading, including the first use of each kit
effect, so nothing stalls on a shader compile. The same caveat holds: one fast GPU at a vsync
cap, so this only shows that the effects are not the bottleneck there.
