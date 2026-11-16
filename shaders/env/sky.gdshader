// sky.gdshader: flat pale wash sky with drifting wash-band clouds (clouds.png). Owner: vfx.
// Drawn on a dome that is centred on the camera in the vertex shader (no script needed to
// follow it). Drains toward bare paper with valley_gloom and while the camera is inside a
// cursed zone. Animated only by vfx_time, which the Vfx director advances in 12 fps steps and
// stops while the tree is paused.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_never, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform float vfx_time = 0.0;
uniform float dome_radius = 350.0;
uniform vec4 zenith_color : source_color = vec4(0.700, 0.788, 0.812, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.925, 0.910, 0.859, 1.0);
uniform vec4 drained_color : source_color = vec4(0.910, 0.878, 0.812, 1.0);
uniform vec4 cloud_fill : source_color = vec4(0.965, 0.957, 0.930, 1.0);
uniform vec4 cloud_ink : source_color = vec4(0.420, 0.420, 0.430, 1.0);
uniform sampler2D clouds_tex : filter_linear, repeat_disable, hint_default_black;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform int cloud_count : hint_range(0, 16) = 14;
uniform float cloud_min_elev : hint_range(0.0, 1.2) = 0.05;
uniform float cloud_max_elev : hint_range(0.0, 1.4) = 0.5;
uniform float cloud_size : hint_range(0.1, 2.0) = 0.75;
uniform float drift_speed = 0.006;
uniform float wash_variation : hint_range(0.0, 0.2) = 0.05;
uniform float gloom_strength : hint_range(0.0, 1.0) = 0.85;
uniform float cloud_seed = 3.0;

varying vec3 v_dir;

void vertex() {
	v_dir = VERTEX;
	vec3 w = CAMERA_POSITION_WORLD + VERTEX * dome_radius;
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

float h1(float n) {
	return fract(sin(n * 12.9898 + cloud_seed * 78.233) * 43758.5453);
}

void fragment() {
	vec3 dir = normalize(v_dir);
	float elev = asin(clamp(dir.y, -1.0, 1.0));
	float az = atan(dir.x, dir.z);
	vec3 col = mix(ink_in(horizon_color.rgb), ink_in(zenith_color.rgb), smoothstep(-0.02, 0.9, elev));
	vec2 wp = dir.xz / max(dir.y + 0.35, 0.1);
	float n = texture(noise_tex, wp * 0.18 + vec2(vfx_time * drift_speed * 0.5, 0.0)).r;
	col *= 1.0 + (n - 0.5) * wash_variation;

	float fill = 0.0;
	float line = 0.0;
	float t = vfx_time * drift_speed;
	for (int i = 0; i < 16; i++) {
		if (i >= cloud_count) {
			break;
		}
		float fi = float(i);
		float caz = h1(fi) * 6.2831853 + t * (0.6 + h1(fi + 11.0) * 0.8);
		float cel = mix(cloud_min_elev, cloud_max_elev, h1(fi + 23.0));
		float size = cloud_size * mix(0.6, 1.25, h1(fi + 37.0)) * (1.0 - cel * 0.5);
		float d = mod(az - caz + 3.14159265, 6.2831853) - 3.14159265;
		vec2 local = vec2(d * cos(elev) / size, -(elev - cel) / (size * 0.5));
		if (abs(local.x) > 0.5 || abs(local.y) > 0.5) {
			continue;
		}
		float frame = floor(h1(fi + 51.0) * 4.0);
		vec2 uv = local + 0.5;
		if (h1(fi + 61.0) > 0.5) {
			uv.x = 1.0 - uv.x;
		}
		vec4 c = textureLod(clouds_tex, vfx_atlas_uv(uv, frame, vec2(2.0, 2.0)), 0.0);
		fill = max(fill * (1.0 - c.g), c.r);
		line = max(line * (1.0 - c.r * 0.9), c.g);
	}
	float cursed = ink_curse_amount_at(CAMERA_POSITION_WORLD);
	float g = clamp(max(valley_gloom * gloom_strength, cursed), 0.0, 1.0);
	vec3 drained = ink_in(drained_color.rgb);
	col = mix(col, drained * (1.0 + (n - 0.5) * wash_variation), g);
	vec3 fillc = mix(ink_in(cloud_fill.rgb), drained * 1.02, g * 0.8);
	col = mix(col, fillc, smoothstep(0.3, 0.6, fill));
	vec3 inkc = mix(ink_in(cloud_ink.rgb), mix(ink_in(cloud_ink.rgb), drained, 0.45), g);
	col = mix(col, inkc, smoothstep(0.35, 0.65, line));
	ALBEDO = ink_out(clamp(col, 0.0, 1.0));
}
