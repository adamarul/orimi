// Phase 0 toon probe: three stepped light bands, optional vertex colour albedo,
// optional flat shading from screen-space derivatives (lets meshes keep smooth normals for outlines).
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

uniform vec4 albedo : source_color = vec4(0.86, 0.83, 0.74, 1.0);
uniform bool use_vertex_color = false;
uniform bool flat_from_derivatives = false;
uniform float mid_band : hint_range(0.0, 1.0) = 0.68;
uniform float dark_band : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	vec3 base = albedo.rgb;
	if (use_vertex_color) {
		base *= COLOR.rgb;
	}
	ALBEDO = base;
	if (flat_from_derivatives) {
		vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
		if (dot(n, -VERTEX) < 0.0) {
			n = -n;
		}
		NORMAL = n;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = ndl > 0.45 ? 1.0 : (ndl > 0.05 ? mid_band : dark_band);
	DIFFUSE_LIGHT += band * LIGHT_COLOR * ATTENUATION / PI;
}
