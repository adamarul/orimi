# Browser check: level (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn&autoplay=1&level=sedge_plain
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=4.54s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (9272 ms)


| result | criterion | detail |
| - | - | - |
| ok | autoplay reaches its end | after 265 s |
| ok | autoplay passed (no failed step) | passed true; failures: [] |
| ok | level sedge_plain completes (level_complete) | level_complete: sedge_plain |
| ok | no console/page errors | 1443 console lines |

screenshots: docs/qa/evidence/web_level_sedge_plain_sedge_plain_spawn.jpg, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_arrival.png, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_stones.png, docs/qa/evidence/web_level_sedge_plain_bridge_1.jpg, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_bridge_1_tied.png, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_bridge_1_deck.png, docs/qa/evidence/web_level_sedge_plain_east.jpg, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_kettle_island.png, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_bridge_2.png, docs/qa/evidence/web_level_sedge_plain_west.jpg, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_ladle_island.png, .userdata/qa/full/docs/qa/evidence/web_level_sedge_plain_mere.png, docs/qa/evidence/web_level_sedge_plain_end.jpg
console log: docs/qa/evidence/web_level_sedge_plain_console.txt

image statistics:
```
{
 "levels": [
  "sedge_plain"
 ],
 "stages": [
  "sedge_plain_spawn",
  "arrival",
  "stones",
  "bridge_1",
  "bridge_1_tied",
  "bridge_1_deck",
  "east",
  "kettle_island",
  "bridge_2",
  "west",
  "ladle_island",
  "mere",
  "knoll",
  "restored",
  "exit",
  "sedge_plain_raft_in",
  "sedge_plain_raft_framed",
  "sedge_plain_raft_off"
 ],
 "duration": 249.2,
 "simulated_casts": []
}
```
