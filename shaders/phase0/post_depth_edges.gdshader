// Phase 0 full-screen pass: Sobel on linear depth, multiplied over the frame (blend_mul),
// so it needs no copy of the colour buffer. Proves full-screen quads and the depth texture.
shader_type spatial;
render_mode unshaded, blend_mul, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform float threshold : hint_range(0.0, 1.0) = 0.06;
uniform float strength : hint_range(0.0, 1.0) = 0.85;
uniform float max_depth = 200.0;

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, d) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 v = inv_proj * vec4(ndc, 1.0);
	return min(-v.z / v.w, max_depth);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	vec2 px = 1.0 / VIEWPORT_SIZE;
	float d[9];
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			d[(y + 1) * 3 + (x + 1)] = linear_depth(SCREEN_UV + vec2(float(x), float(y)) * px, INV_PROJECTION_MATRIX);
		}
	}
	float gx = (d[2] + 2.0 * d[5] + d[8]) - (d[0] + 2.0 * d[3] + d[6]);
	float gy = (d[6] + 2.0 * d[7] + d[8]) - (d[0] + 2.0 * d[1] + d[2]);
	float edge = length(vec2(gx, gy)) / max(d[4], 0.001);
	float ink = smoothstep(threshold, threshold * 3.0, edge) * strength;
	ALBEDO = vec3(1.0 - ink);
}
