// Phase 0 blob shadow on a quad: the Compatibility-safe alternative to a Decal.
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 shadow_color : source_color = vec4(0.12, 0.10, 0.10, 0.6);
uniform float softness : hint_range(0.0, 1.0) = 0.6;

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	ALBEDO = shadow_color.rgb;
	ALPHA = shadow_color.a * (1.0 - smoothstep(1.0 - softness, 1.0, r));
}
