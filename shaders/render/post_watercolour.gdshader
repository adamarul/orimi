// Post pass 2 of 3 (canvas, after the 3D pass): watercolour edge darkening and pigment
// blotches. Pigment pools on the dark side of every edge between washes, and the density of the
// wash varies in large soft blotches fixed to the screen. Canvas screen values are sRGB in both
// renderers, so no conversion. Owner: render. Uniforms: docs/SHADERS.md.
shader_type canvas_item;

#include "res://shaders/render/ink_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D stain_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;

uniform float edge_darken : hint_range(0.0, 3.0) = 1.2;
uniform float edge_radius_px : hint_range(0.5, 6.0) = 2.5;
uniform float blotch_strength : hint_range(0.0, 0.5) = 0.12;
uniform float blotch_scale = 1.3;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 c = texture(screen_tex, uv).rgb;
	float r = edge_radius_px;
	vec3 b = vec3(0.0);
	b += texture(screen_tex, uv + vec2(r, 0.0) * px).rgb;
	b += texture(screen_tex, uv + vec2(-r, 0.0) * px).rgb;
	b += texture(screen_tex, uv + vec2(0.0, r) * px).rgb;
	b += texture(screen_tex, uv + vec2(0.0, -r) * px).rgb;
	b += texture(screen_tex, uv + vec2(0.7, 0.7) * r * px).rgb;
	b += texture(screen_tex, uv + vec2(-0.7, 0.7) * r * px).rgb;
	b += texture(screen_tex, uv + vec2(0.7, -0.7) * r * px).rgb;
	b += texture(screen_tex, uv + vec2(-0.7, -0.7) * r * px).rgb;
	b /= 8.0;
	float edge = clamp((ink_luma(b) - ink_luma(c)) * 4.0, 0.0, 1.0);

	vec2 suv = uv * vec2(px.y / px.x, 1.0);
	float blot = texture(stain_tex, suv * blotch_scale * 0.5 + vec2(0.31, 0.17)).r * 0.6
			+ texture(noise_tex, suv * blotch_scale).g * 0.4;
	float density = 1.0 + edge_darken * edge + (blot - 0.4) * 2.0 * blotch_strength;
	vec3 w = c - (c - c * c) * (density - 1.0);
	COLOR = vec4(mix(c, clamp(w, 0.0, 1.0), strength), 1.0);
}
