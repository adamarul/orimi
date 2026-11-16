# Browser check: input (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&god=1
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.54s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10337 ms)


| result | criterion | detail |
| - | - | - |
| ok | title -> playing with real input | states title > cutscene > playing, player [0,0.036,50] |
| ok | click captures the mouse | pointerLockElement true, Input.mouse_mode 2 |
| ok | KeyW moves the player +fwd | moved 5.78 m, 5.78 m along the camera fwd axis |
| ok | KeyS moves the player -fwd | moved 5.78 m, 5.78 m along the camera fwd axis |
| ok | KeyA moves the player -right | moved 5.77 m, 5.77 m along the camera right axis |
| ok | KeyD moves the player +right | moved 5.78 m, 5.78 m along the camera right axis |
| ok | Game.debug_snapshot() reports the player position and it changes | position changed in 4 of 4 moves |
| ok | mouse motion orbits the camera | yaw 15.9 -> -28.7 |
| ok | Space jumps | height 0.05 -> peak 0.41 |
| ok | J and the left mouse button attack (Events.player_attacked) | J true, left button true |
| ok | Escape (pause action) pauses and frees the mouse | pointer lock false, mouse_mode 0, tree paused true, state paused |
| ok | resume with Escape again (playing and captured 1.5 s later) | state changes playing; now state playing, tree paused false, mouse_mode 2 |
| ok | resume with P (playing and captured 1.5 s later) | state changes paused > playing; now state playing, tree paused false, mouse_mode 2 |
| ok | resume with a click on Resume (playing and captured 1.5 s later) | state changes paused > playing; now state playing, tree paused false, mouse_mode 2 |
| ok | a capture lost to the browser is treated as a pause | after exitPointerLock: mouse_mode 0, tree paused true, state paused |
| ok | no console/page errors | 131 console lines |

screenshots: none
console log: docs/qa/evidence/web_input_console.txt
