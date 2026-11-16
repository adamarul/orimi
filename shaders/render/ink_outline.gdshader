// Orimi ink outline: inverted hull drawn as the toon material's next_pass, extruded in clip
// space so its width is set in % of screen height. Width = base x vertex-colour R x world noise
// x one-sided "brush light" term, re-seeded in steps (wobble), clamped to the style guide's
// range. Dry-brush gaps from streak noise weighted by vertex-colour B. Owner: render.
// Uniforms: docs/SHADERS.md.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled, fog_disabled;

#define INK_LIGHT_KEEP light_keep
#include "res://shaders/render/ink_common.gdshaderinc"

group_uniforms line;
uniform vec4 line_color : source_color = vec4(0.106, 0.102, 0.110, 1.0);
uniform vec4 far_line_color : source_color = vec4(0.42, 0.41, 0.40, 1.0);
uniform float width_h = 0.022;
uniform float min_h = 0.0;
uniform float max_h = 0.04;
uniform float width_scale = 1.0;
uniform bool has_vertex_color = false;
uniform float default_weight : hint_range(0.0, 1.0) = 1.0;
uniform float default_dry : hint_range(0.0, 1.0) = 0.25;
group_uniforms;

group_uniforms brush_light;
uniform vec3 brush_light_view = vec3(-0.35, 1.0, 0.3);
uniform float one_sided : hint_range(0.0, 1.0) = 0.95;
uniform float lit_cut : hint_range(-1.0, 1.0) = 0.55;
uniform float shade_cut : hint_range(-1.0, 1.0) = -0.35;
group_uniforms;

group_uniforms variation;
uniform float thick_thin_scale = 0.55;
uniform float thick_thin_min = 0.5;
uniform float thick_thin_max = 1.4;
uniform float wobble_fps : hint_range(0.0, 12.0) = 7.0;
uniform float wobble_amount : hint_range(0.0, 0.3) = 0.15;
uniform float wobble_scale = 2.3;
group_uniforms;

group_uniforms dry_brush;
uniform sampler2D streak_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float dry_amount : hint_range(0.0, 1.0) = 0.55;
uniform float dry_low_weight : hint_range(0.0, 1.0) = 0.35;
uniform float streak_along = 2.5;
uniform float streak_across = 28.0;
group_uniforms;

group_uniforms distance;
uniform float near_dist = 32.0;
uniform float far_scale_min : hint_range(0.0, 1.0) = 0.45;
uniform float fade_start = 35.0;
uniform float fade_end = 140.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.85;
uniform float depth_pull = 0.0;
group_uniforms;

group_uniforms motion;
uniform bool wind_enabled = false;
uniform float wind_amount = 0.12;
group_uniforms;

group_uniforms effects;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_edge = 0.07;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float light_keep : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

varying vec2 v_dir;
varying float v_dry;
varying float v_weight;
varying vec3 v_object;
varying float v_dist;

void vertex() {
	v_object = VERTEX;
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 col = has_vertex_color ? COLOR : vec4(default_weight, 0.0, default_dry, 1.0);
	if (wind_enabled) {
		w += ink_wind_offset(w, col.g, VERTEX.y, wind, TIME, wind_amount);
	}
	vec4 view = VIEW_MATRIX * vec4(w, 1.0);
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	float dist = length(view.xyz);
	v_dist = dist;

	float seed = floor(TIME * max(wobble_fps, 0.001));
	float thick_thin = mix(thick_thin_min, thick_thin_max, ink_noise3(w * thick_thin_scale));
	float wob = ink_noise3(w * wobble_scale + vec3(seed * 7.13, seed * 3.71, seed * 5.19));
	float facing = dot(n_view, normalize(brush_light_view));
	float side = smoothstep(lit_cut, shade_cut, facing);
	float dist_scale = clamp(near_dist / max(dist, 0.001), far_scale_min, 1.0);

	float h = width_h * width_scale * col.r * thick_thin * (1.0 + wobble_amount * (wob * 2.0 - 1.0));
	h *= mix(1.0, side, one_sided) * dist_scale;
	h = clamp(h, min_h, max_h);
	v_weight = clamp(col.r * mix(1.0, side, one_sided), 0.0, 1.0);
	v_dry = col.b;

	vec4 clip = PROJECTION_MATRIX * view;
	vec2 dir = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy * VIEWPORT_SIZE;
	float dl = length(dir);
	dir = dl > 1e-5 ? dir / dl : vec2(0.0);
	v_dir = dir;
	// h is a fraction of screen height; clip space spans 2 units over VIEWPORT_SIZE.y pixels.
	vec2 px = dir * h * VIEWPORT_SIZE.y;
	clip.xy += px * 2.0 / VIEWPORT_SIZE * clip.w;
	clip.z += depth_pull * clip.w;
	POSITION = clip;
}

void fragment() {
	if (dissolve > 0.0) {
		float a = texture(noise_tex, v_object.xy * 0.9 + vec2(0.13, 0.71)).r;
		float b = texture(noise_tex, v_object.zy * 0.9 + vec2(0.57, 0.29)).r;
		float c = texture(noise_tex, v_object.xz * 2.3).b;
		float n = (a + b) * 0.4 + c * 0.2;
		if (n < dissolve * (1.0 + dissolve_edge) - dissolve_edge * 0.5 + dissolve_edge) {
			discard;
		}
	}
	// dry brush: streaks run along the stroke (perpendicular to the extrusion direction)
	vec2 nd = length(v_dir) > 1e-4 ? normalize(v_dir) : vec2(0.0, 1.0);
	vec2 td = vec2(-nd.y, nd.x);
	vec2 p = FRAGCOORD.xy / VIEWPORT_SIZE.y;
	float seed = floor(TIME * max(wobble_fps, 0.001));
	vec2 suv = vec2(dot(p, td) * streak_along, dot(p, nd) * streak_across) + vec2(seed * 0.137, seed * 0.311);
	float s = texture(streak_tex, suv).r;
	float thr = v_dry * dry_amount + (1.0 - v_weight) * dry_low_weight;
	if (s < thr * 0.85) {
		discard;
	}
	float f = ink_paper_fade(v_dist, fade_start, fade_end);
	vec3 c = mix(ink_in(line_color.rgb), ink_in(far_line_color.rgb), f);
	c = mix(c, INK_PAPER, f * fade_max * 0.7);
	ALBEDO = ink_out(c);
}
