// foliage.gdshader: camera-facing card foliage (reeds, grass, bush and tree fans) drawn by a
// MultiMesh from FoliageScatter. Owner: vfx. Sways with the "wind" global in 12 fps steps
// (vfx_time), bends away from player_world_pos, drains in the dull valley (valley_gloom) and
// turns to black ink silhouettes inside cursed zones. Cut-out, one draw call per scatter.
// Per instance: transform (root position, X scale = card width, Y scale = card height),
// INSTANCE_CUSTOM = (atlas frame, random 0..1, sway weight 0..1, tint -1..1).
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#define INK_LIGHT_KEEP 0.0
#include "res://shaders/vfx/vfx_common.gdshaderinc"

global uniform vec3 player_world_pos;

uniform float vfx_time = 0.0;
uniform sampler2D atlas : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform vec2 atlas_grid = vec2(4.0, 2.0);
uniform vec4 light_color : source_color = vec4(0.62, 0.72, 0.50, 1.0);
uniform vec4 dark_color : source_color = vec4(0.36, 0.47, 0.33, 1.0);
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.110, 1.0);
uniform vec4 drained_tint : source_color = vec4(0.60, 0.60, 0.52, 1.0);
uniform vec4 cursed_color : source_color = vec4(0.090, 0.086, 0.094, 1.0);
uniform float cutoff : hint_range(0.05, 0.95) = 0.45;
uniform float sway_amount : hint_range(0.0, 1.0) = 0.22;
uniform float bend_radius = 1.6;
uniform float bend_amount : hint_range(0.0, 1.5) = 0.7;
uniform float gloom_drain : hint_range(0.0, 1.0) = 0.75;
uniform float fade_start = 35.0;
uniform float fade_end = 140.0;
uniform float fade_max : hint_range(0.0, 1.0) = 0.85;

varying vec4 v_custom;
varying float v_curse;
varying float v_dist;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	v_custom = INSTANCE_CUSTOM;
	float h = VERTEX.y + 0.5;
	vec3 right = vfx_upright_right(origin, CAMERA_POSITION_WORLD);
	vec3 w = origin + right * VERTEX.x * sx + vec3(0.0, h * sy, 0.0);

	vec3 offset = ink_wind_offset(origin + vec3(INSTANCE_CUSTOM.y * 7.0, 0.0, 0.0), INSTANCE_CUSTOM.z, 1.0, wind, vfx_time, sway_amount);

	vec3 away = origin - player_world_pos;
	away.y = 0.0;
	float d = length(away);
	float near = (1.0 - smoothstep(bend_radius * 0.3, bend_radius, d)) * step(abs(origin.y - player_world_pos.y), 2.5);
	offset += (d > 0.001 ? away / d : vec3(0.0)) * near * bend_amount;
	offset *= h * h * sy;
	offset.y -= length(offset) * 0.35;
	w += offset;

	v_curse = ink_curse_amount_at(origin);
	v_dist = distance(origin, CAMERA_POSITION_WORLD);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec4 t = texture(atlas, vfx_atlas_uv(UV, v_custom.x, atlas_grid));
	if (t.r < cutoff) {
		discard;
	}
	vec3 col = mix(ink_in(dark_color.rgb), ink_in(light_color.rgb), t.g) * (1.0 + v_custom.w * 0.08);
	float lum = ink_luma(col);
	col = mix(col, vec3(lum) * ink_in(drained_tint.rgb) * 1.35, valley_gloom * gloom_drain);
	col = mix(col, ink_in(ink_color.rgb), smoothstep(0.35, 0.6, t.b));
	col = mix(col, ink_in(cursed_color.rgb) * (0.8 + t.g * 0.6), smoothstep(0.1, 0.6, v_curse));
	col = mix(col, INK_PAPER, ink_paper_fade(v_dist, fade_start, fade_end) * fade_max);
	ALBEDO = ink_out(clamp(col, 0.0, 1.0));
}
