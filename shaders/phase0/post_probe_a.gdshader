// Phase 0 probe pass A (3D full-screen quad). Writes tiles 0-4, discards everywhere else:
//  0 marker (magenta) for the chain probes
//  1 screen texture read of the background: green = linear values, blue = sRGB-encoded values
//  2 depth texture: green when linearised depth at screen centre matches the expected value
//  3 normal-roughness texture: green when it matches the expected ground normal, yellow = gated off
//  4 normal reconstructed from depth: green when it matches the expected ground normal
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#include "res://shaders/phase0/probe_tiles.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
#if CURRENT_RENDERER != RENDERER_COMPATIBILITY
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
#endif
uniform vec3 bg_srgb;
uniform vec2 bg_uv;
uniform float expected_depth;
uniform vec3 expected_view_normal;

vec3 view_pos(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return v.xyz / v.w;
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	int t = probe_tile(SCREEN_UV);
	if (t < 0 || t > 4) {
		discard;
	}
	vec2 center = vec2(0.5) + 0.5 / VIEWPORT_SIZE;
	vec3 c = TILE_FAIL;
	if (t == 0) {
		c = TILE_MARK_A;
	} else if (t == 1) {
		vec3 s = texture(screen_tex, bg_uv).rgb;
		if (probe_near(s, probe_srgb_to_linear(bg_srgb), 0.04)) {
			c = TILE_PASS;
		} else if (probe_near(s, bg_srgb, 0.04)) {
			c = TILE_ALT;
		}
	} else if (t == 2) {
		float lin = -view_pos(center, INV_PROJECTION_MATRIX).z;
		c = abs(lin - expected_depth) < 0.25 ? TILE_PASS : TILE_FAIL;
	} else if (t == 3) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
		c = TILE_NA;
#else
		vec3 n = normalize(texture(nr_tex, center).xyz * 2.0 - 1.0);
		c = dot(n, expected_view_normal) > 0.95 ? TILE_PASS : TILE_FAIL;
#endif
	} else {
		vec2 step_uv = 4.0 / VIEWPORT_SIZE;
		vec3 p = view_pos(center, INV_PROJECTION_MATRIX);
		vec3 px = view_pos(center + vec2(step_uv.x, 0.0), INV_PROJECTION_MATRIX);
		vec3 py = view_pos(center + vec2(0.0, step_uv.y), INV_PROJECTION_MATRIX);
		vec3 n = normalize(cross(px - p, py - p));
		if (n.z < 0.0) {
			n = -n;
		}
		c = dot(n, expected_view_normal) > 0.95 ? TILE_PASS : TILE_FAIL;
	}
	ALBEDO = c;
	ALPHA = 1.0;
}
