// Phase 0: show the mesh's vertex colour unlit, to compare the raw COLOR read across renderers.
// constant_grey outputs ALBEDO 0.5 instead, to separate input conversion from output conversion.
shader_type spatial;
render_mode unshaded;

uniform bool constant_grey = false;

void fragment() {
	ALBEDO = constant_grey ? vec3(0.5) : COLOR.rgb;
}
