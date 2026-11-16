// fx_sprite.gdshader: opaque cut-out one-shot effect sprites (ink, flowers, wind strokes, soot).
// Owner: vfx. Drawn by VfxLayer (scripts/vfx/vfx_layer.gd) as one MultiMesh per layer and by
// the soot bank. Cut-out rather than blended, so it draws the same in both renderers and needs
// no sorting; it writes depth, so the post chain's crease pass inks its edges.
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://shaders/vfx/fx_sprite.gdshaderinc"
