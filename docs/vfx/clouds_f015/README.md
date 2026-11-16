# F-015: clouds redrawn (vfx)

The sky's clouds were stacked round puffs topped with spiral curls. They are now long horizontal
wash bands with torn-paper edges and dry gaps, under a single ink stroke that runs out past the
main band as a tapering dry-brush tail. There are no curls. Only clouds.png changed: it keeps
the same 1024x512 2x2 atlas and channels, so the sky shader and its cost are the same.
Generator: `cloud_cell` in tools/textures/vfx/gen_vfx_textures.py (commit c5ff452).

Each sheet crops the sky from browser captures of the web build (tools/smoke_web.sh). The top
half is before c5ff452 and the bottom half is after it, from the same view.

| Sheet | Boot options |
| --- | --- |
| tf_play_before_after.jpg | level=tallowford fresh=1 (drained village sky, gameplay camera) |
| tf_restored_before_after.jpg | scene=res://scenes/levels/tallowford/lookdev.tscn state=restored view=1 |
| hz_before_after.jpg | level=hazewater fresh=1 (before), plus vfx_gloom=0 (after); the cursed spawn keeps the sky pale either way |

atlas_preview.jpg shows the four cells of the new clouds.png, coloured roughly as the shader colours them.
