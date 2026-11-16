// fx_glow.gdshader: soft translucent sprites with a solid core and a wide low halo, for
// sparkles and the hit spark. Owner: vfx. Same instance layout as fx_sprite (billboard only);
// COLOR.a is the overall fade. Tuned for the web build (translucent blends darker there).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform sampler2D atlas : filter_linear_mipmap, repeat_disable, hint_default_black;
uniform vec2 atlas_grid = vec2(4.0, 1.0);
uniform vec4 core_color : source_color = vec4(1.0, 0.99, 0.95, 1.0);
uniform vec4 halo_color : source_color = vec4(0.922, 0.796, 0.478, 1.0);
uniform float halo_strength : hint_range(0.0, 1.0) = 0.35;

varying vec4 v_custom;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	v_custom = INSTANCE_CUSTOM;
	vec3 c = (VIEW_MATRIX * vec4(origin, 1.0)).xyz;
	float rot = INSTANCE_CUSTOM.z;
	vec2 p = VERTEX.xy * vec2(sx, sy);
	VERTEX = c + vec3(p.x * cos(rot) - p.y * sin(rot), p.x * sin(rot) + p.y * cos(rot), 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	vec4 t = texture(atlas, vfx_atlas_uv(UV, v_custom.x, atlas_grid));
	float core = smoothstep(0.35, 0.6, t.r);
	vec3 col = mix(ink_in(halo_color.rgb) * COLOR.rgb, ink_in(core_color.rgb), core);
	ALBEDO = ink_out(col);
	ALPHA = clamp(max(core, t.g * halo_strength) * COLOR.a, 0.0, 1.0);
}
