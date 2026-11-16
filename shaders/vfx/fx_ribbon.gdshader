// fx_ribbon.gdshader: dry-brush ribbons (slash glyph, tail-swipe arcs, attached trails).
// Owner: vfx. Built by VfxRibbon as a strip in world space: VERTEX = centre line point,
// NORMAL = tangent, UV = (u along the stroke 0..1, side 0/1), UV2.x = arc parameter for the
// reveal window, COLOR = (half width in metres, erode 0..1, head 0..1, tail 0..1).
// Expands toward the camera, so the ribbon always shows its full width. Cut-out, not blended.
shader_type spatial;
render_mode unshaded, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

#include "res://shaders/vfx/vfx_common.gdshaderinc"

uniform sampler2D ribbon_tex : filter_linear_mipmap, repeat_disable, hint_default_white;
uniform vec4 fill_color : source_color = vec4(0.957, 0.937, 0.890, 1.0);
uniform vec4 streak_color : source_color = vec4(0.640, 0.625, 0.600, 1.0);
uniform vec4 edge_color : source_color = vec4(0.290, 0.278, 0.270, 1.0);
uniform float cutoff : hint_range(0.0, 1.0) = 0.32;
uniform float streak_amount : hint_range(0.0, 1.0) = 0.5;

varying vec4 v_data;
varying float v_arc;

void vertex() {
	vec3 c = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tv = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 side = cross(tv, normalize(c));
	float l = length(side);
	side = l > 0.00001 ? side / l : vec3(0.0, 1.0, 0.0);
	VERTEX = c + side * COLOR.r * (UV.y * 2.0 - 1.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	v_data = COLOR;
	v_arc = UV2.x;
}

void fragment() {
	if (v_arc > v_data.z || v_arc < v_data.w) {
		discard;
	}
	vec4 t = texture(ribbon_tex, UV);
	float cut = mix(cutoff, 1.0, v_data.y);
	if (t.r < cut) {
		discard;
	}
	vec3 col = ink_in(fill_color.rgb);
	col = mix(col, ink_in(streak_color.rgb), t.g * streak_amount);
	float edge = smoothstep(0.32, 0.0, min(UV.y, 1.0 - UV.y)) * step(UV.y, 0.5);
	col = mix(col, ink_in(edge_color.rgb), edge * 0.85);
	col = mix(col, INK_PAPER, ink_paper_fade(length(VERTEX), 35.0, 140.0) * 0.85);
	ALBEDO = ink_out(col);
}
