// vfx_common.gdshaderinc: shared helpers for the vfx and environment shaders. Owner: vfx.
// Colour handling and the curse lookup come from render's ink_common (see its COLOUR RULE):
// colour maths happens in sRGB display values; source_color uniforms go through ink_in(),
// the result through ink_out(). Uniforms of every shader that includes this are documented in
// docs/SHADERS_VFX.md.

#ifndef VFX_COMMON_INCLUDED
#define VFX_COMMON_INCLUDED

// Effects keep their own colour in a drained or dark place (render's light pools). Scenery
// (foliage, water, mist) defines INK_LIGHT_KEEP 0.0 before including this, so it darkens with
// the ground around it.
#ifndef INK_LIGHT_KEEP
#define INK_LIGHT_KEEP 1.0
#endif
#include "res://shaders/render/ink_common.gdshaderinc"

// UV inside cell 'frame' of an atlas with grid.x columns and grid.y rows (row-major, top first).
vec2 vfx_atlas_uv(vec2 uv, float frame, vec2 grid) {
	float f = floor(frame + 0.5);
	float col = mod(f, grid.x);
	float row = floor(f / grid.x);
	return (vec2(col, row) + clamp(uv, vec2(0.002), vec2(0.998))) / grid;
}

// Camera-facing right vector around the world Y axis, for upright cards rooted at origin.
vec3 vfx_upright_right(vec3 origin, vec3 camera_pos) {
	vec3 f = camera_pos - origin;
	f.y = 0.0;
	float l = length(f);
	f = l > 0.0001 ? f / l : vec3(0.0, 0.0, 1.0);
	return vec3(f.z, 0.0, -f.x);
}

#endif
