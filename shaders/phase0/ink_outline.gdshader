// Phase 0 inverted-hull outline, used as next_pass. Extrudes along the view-space normal
// projected to clip space, so width is constant in pixels at any distance.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform vec4 ink_color : source_color = vec4(0.05, 0.05, 0.12, 1.0);
uniform float width_px : hint_range(0.0, 16.0) = 3.0;
uniform bool weight_from_vertex_alpha = false;

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir_px = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy * VIEWPORT_SIZE;
	vec2 dir = dir_px / max(length(dir_px), 1e-5);
	float w = width_px * (weight_from_vertex_alpha ? COLOR.a : 1.0);
	clip.xy += dir * w * 2.0 / VIEWPORT_SIZE * clip.w;
	POSITION = clip;
}

void fragment() {
	ALBEDO = ink_color.rgb;
}
