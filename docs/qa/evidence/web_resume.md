# Browser check: resume (PASS)

url query: scene=res%3A%2F%2Ftests%2Fqa%2Fqa_host.tscn&target=res%3A%2F%2Fscenes%2Fgame%2Fmain.tscn
chrome: Chrome/157.0.8103.51; webgl: {"webgl2":true,"renderer":"ANGLE (NVIDIA, NVIDIA GeForce RTX 3080 (0x00002206) Direct3D11 vs_5_0 ps_5_0, D3D11)"}
first frame: ORIMI_FIRST_FRAME t=0.76s scene=res://tests/qa/qa_host.tscn renderer=gl_compatibility driver=opengl3 adapter=WebKit WebGL api=OpenGL ES 3.0 (WebGL 2.0 (OpenGL ES 3.0 Chromium)) display=web (10640 ms)


| result | criterion | detail |
| - | - | - |
| ok | hazewater played through and progress saved | progress_saved {"completed":["hazewater"],"current":"tallowford","stats":{"hazewater":{"deaths":1,"kills":16,"time":89}},"taught":["move","jump","fight"]} |
| ok | saved progress loads after a page reload | progress_loaded {"completed":["hazewater"],"current":"tallowford","from":"localStorage","stats":{"hazewater":{"deaths":1,"kills":16,"time":89}},"taught":["move","jump","fight"]} |
| ok | the title shows tallowford behind it | title_ready level tallowford |
| ok | the title offers Continue | buttons: Continue: Tallowford, Chapters, Begin anew |
| ok | Continue starts tallowford | level tallowford, state playing |
| ok | Continue keeps the 1 beads earned up to hazewater | beads 1, ink_max 120 |
| ok | no console/page errors | 794 console lines |

screenshots: docs/qa/evidence/web_resume_title.jpg, docs/qa/evidence/web_resume_continued.jpg
console log: docs/qa/evidence/web_resume_console.txt

image statistics:
```
{
 "indexeddb_before_reload": {
  "/userfs": [
   "/userfs/orimi",
   "/userfs/orimi/progress.json",
   "/userfs/orimi/shader_cache",
   "/userfs/orimi/shader_cache/CanvasOcclusionShaderGLES3",
   "/userfs/orimi/shader_cache/CanvasOcclusionShaderGLES3/f818a8f730d58a711992c8a4e0128943b6de769e22c755bf25fa9b2c91eb797a",
   "/userfs/orimi/shader_cache/CanvasSdfShaderGLES3",
   "/userfs/orimi/shader_cache/CanvasSdfShaderGLES3/bb66bedc1351d45606a9e7a58d673d19a5dcf38d178d630d1254904a435ccd11",
   "/userfs/orimi/shader_cache/CanvasShaderGLES3",
   "/userfs/orimi/shader_cache/CanvasShaderGLES3/8e0fd2a4dcaed358e6f55b4a13dac2e99da849634cb76e03fa72090229e6bf2d",
   "/userfs/orimi/shader_cache/CopyShaderGLES3",
   "/userfs/orimi/shader_cache/CopyShaderGLES3/227703cbe4dbfc7cd2037ec10eef081d3f1f5593f23f5be9a7adb858e12a0b59",
   "/userfs/orimi/shader_cache/CubemapFilterShaderGLES3",
   "/userfs/orimi/shader_cache/CubemapFilterShaderGLES3/b6ae124cd1d4a7e561bd528bd4a77c138ee3a3ecec10dff52834da05a584150b",
   "/userfs/orimi/shader_cache/FeedShaderGLES3",
   "/userfs/orimi/shader_cache/FeedShaderGLES3/bf3e769fb9cccb160c1455e48ff14753cb627a350dd01a48eb0f0c360453e632",
   "/userfs/orimi/shader_cache/GlowShaderGLES3",
   "/userfs/orimi/shader_cache/GlowShaderGLES3/451048476e1fd0d1e3d2ee406829fdfa053b6cd3cd83ca130a227981bae863d2",
   "/userfs/orimi/shader_cache/ParticlesCopyShaderGLES3",
   "/userfs/orimi/shader_cache/ParticlesCopyShaderGLES3/5a972e52ef34baa6d9112f5010053a97977d72e736e5df0bdaf9397b3f4235ad",
   "/userfs/orimi/shader_cache/ParticlesShaderGLES3"
  ]
 }
}
```
