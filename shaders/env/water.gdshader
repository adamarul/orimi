// water.gdshader: flat river wash with white calligraphic ripple arcs and a faint network of
// bright cell lines drifting with the flow. Owner: vfx. Works on any mesh: it maps in world XZ
// (or the mesh UV with use_uv). No reflection, no refraction. Animated only by vfx_time
// (12 fps steps from the Vfx director, frozen while paused).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

#define INK_LIGHT_KEEP 0.0
#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform float vfx_time = 0.0;
uniform vec4 wash_color : source_color = vec4(0.498, 0.627, 0.651, 1.0);
uniform vec4 deep_color : source_color = vec4(0.420, 0.553, 0.584, 1.0);
uniform vec4 line_color : source_color = vec4(0.965, 0.961, 0.937, 1.0);
uniform vec4 cursed_color : source_color = vec4(0.200, 0.192, 0.200, 1.0);
uniform sampler2D ripple_tex : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform sampler2D cells_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec2 flow_direction = vec2(0.0, 1.0);
uniform float flow_speed = 0.6;
uniform bool use_uv = false;
uniform vec2 uv_scale = vec2(1.0, 1.0);
uniform float cell_scale = 0.11;
uniform float cell_strength : hint_range(0.0, 1.0) = 0.35;
uniform vec2 ripple_spacing = vec2(2.4, 3.2);
uniform float ripple_density : hint_range(0.0, 1.0) = 0.55;
uniform float ripple_size : hint_range(0.2, 1.0) = 0.85;
uniform float ripple_cycle = 2.5;
uniform float gloom_drain : hint_range(0.0, 1.0) = 0.45;
uniform float fade_start = 35.0;
uniform float fade_end = 140.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.85;

varying vec3 v_world;

void vertex() {
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float rh(vec2 p) {
	return ink_hash12(p);
}

void fragment() {
	vec2 p = use_uv ? UV * uv_scale : v_world.xz;
	vec2 f = length(flow_direction) > 0.0001 ? normalize(flow_direction) : vec2(0.0, 1.0);
	vec2 s = vec2(-f.y, f.x);
	float t = vfx_time;
	vec2 q = vec2(dot(p, s), dot(p, f));

	vec4 wash_n = texture(cells_tex, p * 0.02 - f * t * flow_speed * 0.01);
	vec3 col = mix(ink_in(wash_color.rgb), ink_in(deep_color.rgb), smoothstep(0.3, 0.75, wash_n.b));

	vec2 c1 = (p - f * t * flow_speed * 0.55) * cell_scale;
	vec2 c2 = (p - f * t * flow_speed * 0.85) * cell_scale * 1.7 + vec2(0.37, 0.71);
	float cells = max(texture(cells_tex, c1).r, texture(cells_tex, c2).g * 0.8);
	cells = smoothstep(0.45, 0.85, cells) * cell_strength;

	vec2 rq = vec2(q.x, q.y - t * flow_speed) / ripple_spacing;
	vec2 cell = floor(rq);
	vec2 local = fract(rq) - 0.5;
	float ripple = 0.0;
	float present = step(rh(cell + 3.1), ripple_density);
	if (present > 0.0) {
		float frame = floor(rh(cell + 7.7) * 16.0);
		vec2 jitter = (vec2(rh(cell + 1.3), rh(cell + 5.9)) - 0.5) * 0.3;
		float sc = ripple_size * mix(0.7, 1.0, rh(cell + 9.1));
		vec2 uv = (local - jitter) / sc * vec2(1.0, ripple_spacing.y / ripple_spacing.x * 2.0) + 0.5;
		uv.y = 1.0 - uv.y;
		if (all(greaterThan(uv, vec2(0.0))) && all(lessThan(uv, vec2(1.0)))) {
			vec4 r = texture(ripple_tex, vfx_atlas_uv(uv, frame, vec2(4.0, 4.0)));
			float phase = fract(t / ripple_cycle + rh(cell + 13.3));
			float head = clamp(phase * 2.2, 0.0, 1.0);
			float tail = clamp(phase * 2.2 - 1.1, 0.0, 1.0);
			ripple = step(0.5, r.r) * step(r.g, head) * step(tail, r.g) * step(0.004, r.g);
		}
	}
	vec3 line = ink_in(line_color.rgb);
	col = mix(col, line, cells);
	col = mix(col, line, ripple);

	float lum = ink_luma(col);
	col = mix(col, vec3(lum) * vec3(0.98, 1.0, 0.99), valley_gloom * gloom_drain);
	float cursed = ink_curse_amount_at(v_world);
	col = mix(col, ink_in(cursed_color.rgb) + ripple * 0.12, cursed);
	col = mix(col, INK_PAPER, ink_paper_fade(distance(v_world, CAMERA_POSITION_WORLD), fade_start, fade_end) * fade_max);
	ALBEDO = ink_out(clamp(col, 0.0, 1.0));
}
