// fx_sprite_flat.gdshader: the same sprites with no ink outline (petals). Owner: vfx.
// Hard 0/1 alpha in the transparent pass: it never writes depth, so the post chain's crease pass
// does not outline it (the style guide wants petals without outlines), and with alpha exactly 1
// there is no blending difference between the renderers.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#define FX_SPRITE_FLAT
#include "res://shaders/vfx/fx_sprite.gdshaderinc"
