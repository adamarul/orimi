// Post pass 1 of 3: the one full-screen 3D pass (everything that needs depth). Light Kuwahara
// (radius 2 to 3) for the painted softness, plus interior creases from a Sobel-style test on
// depth and on normals reconstructed from depth (works on web, where there is no normal
// buffer). Drawn by a quad the Post autoload keeps in the current camera's world.
// Owner: render. Uniforms: docs/SHADERS.md.
shader_type spatial;
render_mode unshaded, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

#define INK_NO_LIGHT
#include "res://shaders/render/ink_common.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;

group_uniforms kuwahara;
uniform int kuwahara_radius : hint_range(0, 3) = 2;
uniform float kuwahara_mix : hint_range(0.0, 1.0) = 0.8;
group_uniforms;

group_uniforms crease;
uniform float crease_strength : hint_range(0.0, 1.0) = 0.75;
uniform float crease_normal_cut : hint_range(0.0, 1.0) = 0.22;
uniform float crease_depth_cut : hint_range(0.0, 1.0) = 0.09;
uniform float crease_step_px : hint_range(0.5, 3.0) = 1.5;
uniform vec4 crease_color : source_color = vec4(0.290, 0.204, 0.141, 1.0);
uniform float crease_break : hint_range(0.0, 1.0) = 0.45;
uniform float crease_wobble_px : hint_range(0.0, 4.0) = 1.2;
uniform float crease_fps : hint_range(0.0, 12.0) = 7.0;
uniform float crease_fade_end = 90.0;
uniform float far_depth = 900.0;
group_uniforms;

uniform bool debug_creases_only = false;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

vec3 vpos(vec2 uv, mat4 inv_proj) {
	return ink_view_pos(texture(depth_tex, uv).r, uv, inv_proj);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;

	// light Kuwahara: four overlapping quadrants, keep the mean of the calmest one
	vec3 col = ink_in(texture(screen_tex, uv).rgb);
	vec3 kuw = col;
	int r = kuwahara_radius;
	if (r > 0) {
		vec3 m0 = vec3(0.0); vec3 m1 = vec3(0.0); vec3 m2 = vec3(0.0); vec3 m3 = vec3(0.0);
		vec3 s0 = vec3(0.0); vec3 s1 = vec3(0.0); vec3 s2 = vec3(0.0); vec3 s3 = vec3(0.0);
		for (int y = -r; y <= r; y++) {
			for (int x = -r; x <= r; x++) {
				vec3 c = ink_in(texture(screen_tex, uv + vec2(float(x), float(y)) * px).rgb);
				vec3 c2 = c * c;
				if (x <= 0 && y <= 0) { m0 += c; s0 += c2; }
				if (x >= 0 && y <= 0) { m1 += c; s1 += c2; }
				if (x <= 0 && y >= 0) { m2 += c; s2 += c2; }
				if (x >= 0 && y >= 0) { m3 += c; s3 += c2; }
			}
		}
		float n = float((r + 1) * (r + 1));
		m0 /= n; m1 /= n; m2 /= n; m3 /= n;
		float v0 = dot(s0 / n - m0 * m0, vec3(1.0));
		float v1 = dot(s1 / n - m1 * m1, vec3(1.0));
		float v2 = dot(s2 / n - m2 * m2, vec3(1.0));
		float v3 = dot(s3 / n - m3 * m3, vec3(1.0));
		kuw = m0;
		float best = v0;
		if (v1 < best) { best = v1; kuw = m1; }
		if (v2 < best) { best = v2; kuw = m2; }
		if (v3 < best) { best = v3; kuw = m3; }
	}
	vec3 c = mix(col, kuw, kuwahara_mix);

	// creases: 3x3 view positions, wobbled in steps, normals of the four cells around the centre
	float seed = floor(TIME * max(crease_fps, 0.001));
	vec2 jitter = vec2(ink_noise2(uv * 90.0 + seed * 1.7), ink_noise2(uv * 90.0 + 31.0 + seed * 2.3)) - 0.5;
	vec2 cuv = uv + jitter * crease_wobble_px * px;
	vec2 st = px * crease_step_px;
	vec3 p4 = vpos(cuv, INV_PROJECTION_MATRIX);
	float ink = 0.0;
	vec2 margin = st * 2.0 + crease_wobble_px * px;
	bool on_screen = all(greaterThan(uv, margin)) && all(lessThan(uv, vec2(1.0) - margin));
	if (on_screen && -p4.z < far_depth) {
		vec3 p1 = vpos(cuv + vec2(0.0, -st.y), INV_PROJECTION_MATRIX);
		vec3 p3 = vpos(cuv + vec2(-st.x, 0.0), INV_PROJECTION_MATRIX);
		vec3 p5 = vpos(cuv + vec2(st.x, 0.0), INV_PROJECTION_MATRIX);
		vec3 p7 = vpos(cuv + vec2(0.0, st.y), INV_PROJECTION_MATRIX);
		vec3 na = normalize(cross(p5 - p4, p7 - p4));
		vec3 nb = normalize(cross(p3 - p4, p1 - p4));
		vec3 nc = normalize(cross(p7 - p4, p3 - p4));
		vec3 nd = normalize(cross(p1 - p4, p5 - p4));
		float nedge = max(1.0 - dot(na, nb), 1.0 - dot(nc, nd));
		float z = max(-p4.z, 0.001);
		float dedge = (abs(p3.z + p5.z - 2.0 * p4.z) + abs(p1.z + p7.z - 2.0 * p4.z)) / z;
		float e = max(smoothstep(crease_normal_cut, crease_normal_cut * 2.0, nedge),
				smoothstep(crease_depth_cut, crease_depth_cut * 3.0, dedge));
		float brk = smoothstep(crease_break - 0.15, crease_break + 0.15,
				ink_noise2(uv * vec2(VIEWPORT_SIZE.x / VIEWPORT_SIZE.y, 1.0) * 18.0 + seed * 0.37));
		float fade = 1.0 - smoothstep(crease_fade_end * 0.4, crease_fade_end, z);
		ink = e * brk * fade * crease_strength;
	}
	vec3 crease_c = ink_in(crease_color.rgb);
	if (ink > 0.0) {
		crease_c = ink_light(crease_c, (INV_VIEW_MATRIX * vec4(p4, 1.0)).xyz, length(p4), 0.0);
	}
	c = mix(c, crease_c, ink);
	if (debug_creases_only) {
		c = vec3(1.0 - ink);
	}
	ALBEDO = ink_out(c);
	ALPHA = 1.0;
}
