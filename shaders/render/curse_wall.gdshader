// Curse wall: the low, billowing black mass with a feathered crimson rim that marks a cursed
// zone. An open cylinder around the zone (CurseField builds one per slot). The top is torn at
// three scales and its height wanders around the ring; the lower part is opaque ink, the top
// feathers through crimson into nothing. It shrinks to a low lip while the camera or the player
// is inside the zone, flattens with distance so far zones read as a stain on the land, and sinks
// as the restoration front reaches the rim. Owner: render. Uniforms: docs/SHADERS.md.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

#include "res://shaders/render/ink_common.gdshaderinc"

global uniform vec3 player_world_pos;

uniform int slot = 0;
uniform float height = 2.0;
uniform float mass : hint_range(0.0, 1.0) = 0.8;
uniform float feather : hint_range(0.0, 1.0) = 0.3;
uniform float rim_h = 0.02;
uniform float creep_speed = 0.04;
uniform float inside_scale : hint_range(0.0, 1.0) = 0.2;
uniform float far_start = 8.0;
uniform float far_end = 45.0;
uniform float far_scale : hint_range(0.0, 1.0) = 0.25;
uniform vec4 rim_color : source_color = vec4(0.702, 0.125, 0.165, 1.0);
uniform vec4 glow_color : source_color = vec4(0.93, 0.32, 0.25, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float fade_start = 60.0;
uniform float fade_end = 220.0;

varying float v_angle;

void vertex() {
	v_angle = atan(VERTEX.z, VERTEX.x);
}

void fragment() {
	vec4 zone = slot == 0 ? curse_zone_0 : (slot == 1 ? curse_zone_1 : (slot == 2 ? curse_zone_2 : curse_zone_3));
	float amount = slot == 0 ? curse_amount.x : (slot == 1 ? curse_amount.y : (slot == 2 ? curse_amount.z : curse_amount.w));
	float r = max(zone.w, 0.001);
	float front = INK_CURSE_FRONT(r, amount);
	float sink = clamp((r - front) / (r * 0.3), 0.0, 1.0) * step(0.001, amount);
	bool inside = length(CAMERA_POSITION_WORLD.xz - zone.xz) < r || length(player_world_pos.xz - zone.xz) < r;
	float cam_d = length(CAMERA_POSITION_WORLD.xz - zone.xz) - r;
	float far_k = mix(1.0, far_scale, smoothstep(far_start, far_end, cam_d));
	float scale = sink * far_k * (inside ? inside_scale : 1.0);

	float u = v_angle * r / 6.2831;
	float t = TIME * creep_speed;
	float big = texture(noise_tex, vec2(u * 0.035 + t * 0.3, 0.37)).g;
	float mid = texture(noise_tex, vec2(u * 0.16 - t, 0.71)).r;
	float fine = texture(noise_tex, vec2(u * 0.7 + t * 1.6, 0.13)).r;
	float swell = smoothstep(0.3, 0.85, big);
	float billow = mass * (0.05 + swell * 0.95) * (0.55 + mid * 0.6) + (fine - 0.5) * 0.12;
	float top = max(height * scale * billow, 0.0);
	float y = UV.y * height;
	float dist = length(VERTEX);
	float rim = ink_world_per_screen_h(dist, PROJECTION_MATRIX[1][1]) * rim_h;
	float soft = max(top * feather, rim);
	if (y > top + rim * 1.5 || top <= 0.0) {
		discard;
	}
	// below the top: opaque ink, thinning into crimson over the feather band, glow above it
	float into = (top - y) / max(soft, 0.001);
	float over = (y - top) / max(rim, 0.001);
	vec3 c = INK_CURSE_INK;
	float a = 1.0;
	if (y > top - soft) {
		float k = 1.0 - clamp(into, 0.0, 1.0);
		c = mix(INK_CURSE_INK, ink_in(rim_color.rgb), smoothstep(0.5, 1.0, k));
		a = 1.0 - smoothstep(0.75, 1.0, k) * 0.35;
	}
	if (over > 0.0) {
		c = mix(ink_in(rim_color.rgb), ink_in(glow_color.rgb), clamp(over, 0.0, 1.0) * 0.6);
		a = 0.65 * (1.0 - smoothstep(0.0, 1.5, over));
	}
	float f = ink_paper_fade(dist, fade_start, fade_end);
	c = mix(c, INK_PAPER, f * 0.6);
	ALBEDO = ink_out(c);
	ALPHA = ink_alpha(a);
}
