// mist.gdshader: low drifting mist bands in paper colour, drawn by a MultiMesh from Mist.
// Owner: vfx. Each band is a card that turns about Y to face the camera, rooted at its bottom
// edge. Per instance: transform (X scale = length, Y scale = height), INSTANCE_CUSTOM =
// (u offset, drift speed factor, opacity 0..1, v flip 0/1). Translucent (tune on web).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#define INK_LIGHT_KEEP 0.0
#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform float vfx_time = 0.0;
uniform sampler2D band_tex : filter_linear_mipmap, repeat_enable, hint_default_black;
uniform vec4 mist_color : source_color = vec4(0.937, 0.902, 0.824, 1.0);
uniform vec4 cursed_color : source_color = vec4(0.560, 0.520, 0.520, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.7;
uniform float drift_speed = 0.02;
uniform float u_repeat = 1.0;
uniform float near_fade_start = 2.0;
uniform float near_fade_end = 9.0;

varying vec4 v_custom;
varying float v_dist;
varying float v_curse;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	v_custom = INSTANCE_CUSTOM;
	vec3 right = vfx_upright_right(origin, CAMERA_POSITION_WORLD);
	vec3 w = origin + right * VERTEX.x * sx + vec3(0.0, (VERTEX.y + 0.5) * sy, 0.0);
	v_dist = distance(w, CAMERA_POSITION_WORLD);
	v_curse = ink_curse_amount_at(origin);
	VERTEX = (VIEW_MATRIX * vec4(w, 1.0)).xyz;
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec2 uv = vec2(UV.x * u_repeat + v_custom.x + vfx_time * drift_speed * v_custom.y, UV.y);
	if (v_custom.w > 0.5) {
		uv.y = 1.0 - uv.y;
	}
	vec4 t = texture(band_tex, uv);
	float ends = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	float near = smoothstep(near_fade_start, near_fade_end, v_dist);
	vec3 col = mix(ink_in(mist_color.rgb), ink_in(cursed_color.rgb), v_curse * 0.7);
	vec4 veil = ink_veil(col);
	ALBEDO = veil.rgb;
	float a = clamp(t.r * (0.8 + t.g * 0.3) * ends * near * opacity * v_custom.z, 0.0, 1.0);
#if INK_LINEAR_PIPELINE
	// A pale overlay blended in linear space lifts more than the web's sRGB blending: match web.
	a = 1.0 - pow(1.0 - a, 0.6);
	a *= 0.75;
#endif
	ALPHA = a * veil.a;
}
