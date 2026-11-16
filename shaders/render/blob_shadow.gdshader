// Blob shadow: the dark ellipse under a character, on a flat quad (Decals draw nothing on web).
// Near-black, firm edge with a slight feather. Alpha goes through ink_alpha() so desktop
// (linear blending) matches the web (sRGB blending). Owner: render. Uniforms: docs/SHADERS.md.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/render/ink_common.gdshaderinc"

uniform vec4 shadow_color : source_color = vec4(0.051, 0.047, 0.055, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.75;
uniform float feather : hint_range(0.0, 1.0) = 0.18;
uniform float raggedness : hint_range(0.0, 0.3) = 0.08;
uniform float fade = 1.0;

void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float ang = atan(q.y, q.x);
	float rag = (ink_noise2(vec2(ang * 2.2, 0.0) + 5.0) - 0.5) * raggedness;
	float r = length(q) + rag;
	float a = 1.0 - smoothstep(1.0 - feather, 1.0, r);
	ALBEDO = ink_out(ink_in(shadow_color.rgb));
	ALPHA = ink_alpha(a * strength * fade);
}
