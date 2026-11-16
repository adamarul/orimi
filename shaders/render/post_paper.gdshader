// Post pass 3 of 3 (canvas, after a BackBufferCopy): the paper. Tooth as an embossed relief
// lit from the upper left (from the slope of a height field), large uneven staining strongest
// toward the corners, sparse fibres, subtle stepped grain, a warm parchment vignette, a little
// desaturation, and a soft wide glow on bright areas. Fixed to the screen, scaled by luminance
// so it shows most in bright flat areas and nearly vanishes in ink black.
// Owner: render. Uniforms: docs/SHADERS.md; the Light / Normal / Heavy presets are in
// scripts/render/post_chain.gd.
shader_type canvas_item;

#include "res://shaders/render/ink_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D tooth_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform sampler2D stain_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform sampler2D fibre_tex : filter_linear_mipmap, repeat_enable, hint_default_black;

uniform float tooth_strength : hint_range(0.0, 0.3) = 0.05;
uniform float tooth_cells_per_h = 200.0;
uniform vec2 tooth_light = vec2(-0.7, -0.7);
uniform float stain_strength : hint_range(0.0, 0.5) = 0.08;
uniform float stain_scale = 0.7;
uniform vec4 stain_tint = vec4(0.88, 0.8, 0.68, 1.0);
uniform float fibre_strength : hint_range(0.0, 1.0) = 0.0;
uniform float fibre_scale = 1.2;
uniform float grain_strength : hint_range(0.0, 0.1) = 0.012;
uniform float grain_fps : hint_range(0.0, 24.0) = 12.0;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.25;
uniform float vignette_start : hint_range(0.0, 1.5) = 0.45;
uniform float vignette_end : hint_range(0.0, 1.5) = 1.05;
uniform vec4 vignette_color = vec4(0.7, 0.63, 0.53, 1.0);
uniform float saturation : hint_range(0.0, 1.5) = 1.0;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.22;
uniform float glow_threshold : hint_range(0.0, 1.0) = 0.72;
uniform float glow_lod : hint_range(0.0, 8.0) = 4.0;
uniform float luma_floor : hint_range(0.0, 1.0) = 0.08;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	float aspect = px.y / px.x;
	vec2 suv = uv * vec2(aspect, 1.0);
	vec3 src = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 c = src;
	float l = ink_luma(c);
	float show = smoothstep(luma_floor, 0.75, l);

	// soft wide glow on bright areas (blurred from the screen mip chain)
	vec3 blur = textureLod(screen_tex, uv, glow_lod).rgb * 0.6 + textureLod(screen_tex, uv, glow_lod + 1.0).rgb * 0.4;
	vec3 bright = max(blur - vec3(glow_threshold), vec3(0.0)) / max(1.0 - glow_threshold, 0.001);
	c = c + (1.0 - c) * bright * glow_strength;

	// staining: large soft warm blotches, strongest toward the corners
	vec2 q = uv - 0.5;
	float corner = smoothstep(0.1, 0.75, length(q * vec2(aspect, 1.0)));
	float st = texture(stain_tex, suv * stain_scale + vec2(0.13, 0.41)).r;
	c *= mix(vec3(1.0), stain_tint.rgb * 1.08, st * stain_strength * (0.35 + corner) * (0.4 + show * 0.6));

	// tooth: embossed relief from the slope of the height field, lit from the upper left
	vec2 tuv = suv * tooth_cells_per_h / 64.0;
	float e = 1.0 / 512.0;
	float hx = texture(tooth_tex, tuv + vec2(e, 0.0)).r - texture(tooth_tex, tuv - vec2(e, 0.0)).r;
	float hy = texture(tooth_tex, tuv + vec2(0.0, e)).r - texture(tooth_tex, tuv - vec2(0.0, e)).r;
	float relief = dot(vec2(hx, hy), normalize(tooth_light)) * 2.0;
	c += relief * tooth_strength * show;

	// fibres: a few short dark and pale hairs
	vec4 f = texture(fibre_tex, suv * fibre_scale + vec2(0.71, 0.23));
	c = mix(c, c * 0.6, f.r * fibre_strength * (0.3 + show * 0.7));
	c = mix(c, INK_PAPER * 1.05, f.g * fibre_strength * 0.9 * show);

	// grain, re-seeded in steps
	float seed = floor(TIME * max(grain_fps, 0.001));
	float g = ink_hash12(floor(uv / px) + vec2(seed * 13.1, seed * 7.7)) - 0.5;
	c += g * grain_strength * (0.4 + show * 0.6);

	// warm parchment vignette
	float v = smoothstep(vignette_start, vignette_end, length(q * vec2(aspect, 1.0) * 1.4));
	c = mix(c, c * vignette_color.rgb, v * vignette_strength);

	// overall saturation, last, so the warm stain and vignette are toned down with everything else
	c = mix(vec3(ink_luma(c)), c, saturation);

	COLOR = vec4(mix(src, clamp(c, 0.0, 1.0), strength), 1.0);
}
