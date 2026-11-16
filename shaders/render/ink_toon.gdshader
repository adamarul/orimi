// Orimi toon material: flat painted fill, three subtle stepped bands, faceted from screen-space
// derivatives (meshes keep smooth normals for the hull outline), distance fade to paper, wind
// sway, dissolve, hit flash, and the curse response. Unshaded with its own fixed light so the
// result is identical in Forward+ and Compatibility. Owner: render. Uniforms: docs/SHADERS.md.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque, shadows_disabled, fog_disabled;

#define INK_LIGHT_KEEP light_keep
#include "res://shaders/render/ink_common.gdshaderinc"

group_uniforms fill;
uniform vec4 albedo_color : source_color = vec4(0.937, 0.902, 0.824, 1.0);
uniform sampler2D albedo_tex : filter_linear_mipmap_anisotropic, repeat_enable, hint_default_white;
uniform bool use_texture = false;
uniform bool ground_marks = false;
uniform float mark_cut : hint_range(0.0, 1.0) = 0.22;
uniform float mark_halo : hint_range(0.0, 1.0) = 0.5;
uniform float restored_marks : hint_range(0.0, 1.0) = 0.35;
uniform bool has_vertex_color = false;
group_uniforms;

group_uniforms bands;
uniform vec3 light_dir = vec3(-0.45, 0.8, 0.4);
uniform float band_high_cut : hint_range(-1.0, 1.0) = 0.55;
uniform float band_low_cut : hint_range(-1.0, 1.0) = 0.0;
uniform float band_high : hint_range(0.8, 1.3) = 1.03;
uniform float band_low : hint_range(0.5, 1.0) = 0.88;
uniform vec3 shadow_tint = vec3(0.97, 0.985, 1.03);
uniform float facet : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms distance;
uniform float fade_start = 35.0;
uniform float fade_end = 140.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.85;
group_uniforms;

group_uniforms motion;
uniform bool wind_enabled = false;
uniform float wind_amount = 0.12;
group_uniforms;

group_uniforms effects;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;
uniform float dissolve_edge = 0.07;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
group_uniforms;

group_uniforms curse;
uniform bool cursable = true;
uniform bool sacred = false;
uniform vec4 accent_color : source_color = vec4(0.835, 0.251, 0.169, 1.0);
uniform float accent_strength : hint_range(0.0, 1.0) = 0.0;
uniform float curse_rim_h = 0.018;
uniform vec3 curse_light = vec3(1.3, 0.72, 0.68);
uniform float curse_light_amount : hint_range(0.0, 1.0) = 0.8;
uniform float curse_light_width = 6.0;
uniform float curse_light_floor : hint_range(0.0, 1.0) = 0.3;
uniform float blot_scale = 0.12;
uniform float blot_cut : hint_range(0.0, 1.0) = 0.6;
uniform float curse_silhouette : hint_range(0.0, 1.0) = 0.45;
uniform float gloom_desaturate : hint_range(0.0, 1.0) = 0.38;
uniform float gloom_darken : hint_range(0.0, 1.0) = 0.1;
uniform float restored_saturation : hint_range(1.0, 1.5) = 1.12;
uniform float light_keep : hint_range(0.0, 1.0) = 0.0;
group_uniforms;

varying vec3 v_world;
varying vec3 v_object;

void vertex() {
	v_object = VERTEX;
	if (wind_enabled) {
		vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float weight = has_vertex_color ? COLOR.g : 0.0;
		vec3 off = ink_wind_offset(w, weight, VERTEX.y, wind, TIME, wind_amount);
		VERTEX += inverse(mat3(MODEL_MATRIX)) * off;
	}
	v_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float object_noise(vec3 p) {
	float a = texture(noise_tex, p.xy * 0.9 + vec2(0.13, 0.71)).r;
	float b = texture(noise_tex, p.zy * 0.9 + vec2(0.57, 0.29)).r;
	float c = texture(noise_tex, p.xz * 2.3).b;
	return (a + b) * 0.4 + c * 0.2;
}

void fragment() {
	// dissolve: a ragged ink edge eating through the body
	if (dissolve > 0.0) {
		float n = object_noise(v_object);
		float cut = dissolve * (1.0 + dissolve_edge) - dissolve_edge * 0.5;
		if (n < cut) {
			discard;
		}
	}

	vec3 base = ink_in(albedo_color.rgb);
	float mark = 0.0;
	if (use_texture) {
		vec3 t = texture(albedo_tex, UV).rgb;
		if (ground_marks) {
			// painted dark marks on a map-sized ground texture: a crisp ink edge at mark_cut instead
			// of the magnified, blurred texels, and the blurred halo lifted back to ground colour
			float l = ink_luma(t);
			float w = max(fwidth(l), 0.01);
			mark = 1.0 - smoothstep(mark_cut - w, mark_cut + w, l);
			t *= max(mark_halo / max(l, 0.02), 1.0);
			mark *= mix(1.0, restored_marks, max(1.0 - valley_gloom, ink_restored(v_world)));
		}
		base *= t;
	}

	// faceted normal from derivatives (view space -> world)
	vec3 n_view = normalize(NORMAL);
	vec3 n_flat = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n_flat, n_view) < 0.0) {
		n_flat = -n_flat;
	}
	n_view = normalize(mix(n_view, n_flat, facet));
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n_view, 0.0)).xyz);
	float ndl = dot(n_world, normalize(light_dir));
	float aa = fwidth(ndl) * 0.75 + 0.002;
	float hi = smoothstep(band_high_cut - aa, band_high_cut + aa, ndl);
	float lo = 1.0 - smoothstep(band_low_cut - aa, band_low_cut + aa, ndl);
	vec3 c = base * mix(1.0, band_high, hi);
	c = mix(c, base * band_low * shadow_tint, lo);
	c = mix(c, INK_BLACK, mark);

	float dist = length(VERTEX);
	float rag = texture(noise_tex, v_world.xz * 0.09 + vec2(TIME * 0.004, 0.0)).g * 0.6
			+ texture(noise_tex, v_world.xz * 0.31).r * 0.4;

	if (cursable && !sacred) {
		// valley-wide gloom, or the livelier restored look
		float l = ink_luma(c);
		vec3 dull = mix(c, vec3(l), gloom_desaturate) * (1.0 - gloom_darken);
		vec3 lively = clamp(vec3(l) + (c - vec3(l)) * restored_saturation, 0.0, 1.0);
		c = mix(lively, dull, clamp(valley_gloom, 0.0, 1.0));

		float rim_world = ink_world_per_screen_h(dist, PROJECTION_MATRIX[1][1]) * curse_rim_h;
		float inside;
		float wall;
		float rim;
		float front_edge;
		ink_curse(v_world, rag, rim_world, inside, wall, rim, front_edge);
		float flat_k = smoothstep(0.55, 0.85, abs(n_world.y));
		wall *= flat_k;
		rim *= flat_k;
		if (inside > 0.0) {
			float lc = ink_luma(c);
			vec3 grey = vec3(lc * 0.6 + 0.05) * vec3(0.98, 0.98, 1.0);
			float near_rim = ink_curse_edge(v_world, curse_light_width);
			float light_k = curse_light_amount * mix(curse_light_floor, 1.0, near_rim * near_rim);
			vec3 red_light = grey * mix(vec3(1.0), curse_light, light_k);
			red_light = mix(red_light, INK_CURSE_INK, (1.0 - smoothstep(0.05, 0.5, abs(n_world.y))) * curse_silhouette);
			// pooled blots: a slow field decides where ink pools, a mid field tears the edges,
			// a rotated fine sample breaks the tiling
			vec2 q = v_world.xz;
			vec2 qr = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * q;
			float pool = texture(noise_tex, q * blot_scale * 0.25 + vec2(0.31, 0.77)).g;
			float tear = texture(noise_tex, qr * blot_scale + vec2(0.11, 0.53)).r;
			float grit = texture(noise_tex, qr * blot_scale * 3.7).b;
			float blot_n = pool * 0.62 + tear * 0.28 + grit * 0.1;
			float blot = smoothstep(blot_cut, blot_cut + 0.02, blot_n) * flat_k;
			vec3 drained = mix(red_light, INK_CURSE_INK, blot);
			drained = mix(drained, INK_CURSE_INK, max(wall, front_edge));
			c = mix(c, drained, inside);
		}
		if (rim > 0.0) {
			float creep = texture(noise_tex, v_world.xz * 0.5 + vec2(TIME * 0.03, TIME * -0.02)).r;
			float a = clamp(rim * (0.65 + creep * 0.7), 0.0, 1.0);
			vec3 glow = mix(INK_CURSE_RED, vec3(0.93, 0.32, 0.25), (1.0 - rim) * 0.5);
			c = mix(c, glow, a);
		}
	} else if (sacred) {
		float rim_world = ink_world_per_screen_h(dist, PROJECTION_MATRIX[1][1]) * curse_rim_h;
		float inside;
		float wall;
		float rim;
		float front_edge;
		ink_curse(v_world, rag, rim_world, inside, wall, rim, front_edge);
		float glow = max(inside, rim);
		vec3 acc = ink_in(accent_color.rgb);
		float f = pow(1.0 - clamp(dot(n_view, normalize(-VERTEX)), 0.0, 1.0), 2.0);
		float stepped_f = floor(f * 3.0 + 0.5) / 3.0;
		c = mix(c, acc, stepped_f * clamp(accent_strength + glow * 0.45, 0.0, 1.0) * 0.6);
	}

	if (!sacred && accent_strength > 0.0) {
		vec3 acc = ink_in(accent_color.rgb);
		float f = pow(1.0 - clamp(dot(n_view, normalize(-VERTEX)), 0.0, 1.0), 2.0);
		c = mix(c, acc, floor(f * 3.0 + 0.5) / 3.0 * accent_strength * 0.6);
	}

	// dark ragged edge at the dissolve front
	if (dissolve > 0.0) {
		float n = object_noise(v_object);
		float cut = dissolve * (1.0 + dissolve_edge) - dissolve_edge * 0.5;
		c = mix(c, INK_BLACK, 1.0 - smoothstep(cut, cut + dissolve_edge, n));
	}

	c = mix(c, ink_in(flash_color.rgb), clamp(flash_color.a, 0.0, 1.0));
	c = mix(c, INK_PAPER, ink_paper_fade(dist, fade_start, fade_end) * fade_max);
	ALBEDO = ink_out(c);
}
