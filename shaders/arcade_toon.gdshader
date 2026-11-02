// Toon shading in the arcade palette for round elements (guard tubes, cones): the sun light
// N.L picks one of five ramp colors, darkest first; in the sun shadow the darkest two are used.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

uniform vec3 c0 = vec3(102.0, 34.0, 34.0);
uniform vec3 c1 = vec3(136.0, 34.0, 34.0);
uniform vec3 c2 = vec3(170.0, 34.0, 34.0);
uniform vec3 c3 = vec3(221.0, 51.0, 51.0);
uniform vec3 c4 = vec3(255.0, 136.0, 136.0);
// N.L thresholds between the five colors.
uniform vec4 thresholds = vec4(-0.2, 0.2, 0.5, 0.7);
uniform bool use_shadows = true;

vec3 to_linear(vec3 c) {
	vec3 s = c / 255.0;
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s));
}

void fragment() {
	ALBEDO = vec3(1.0);
}

void light() {
	float d = dot(NORMAL, LIGHT);
	vec3 c = c0;
	if (use_shadows && ATTENUATION < 0.5) {
		if (d > thresholds.y) c = c1;
	} else {
		if (d > thresholds.x) c = c1;
		if (d > thresholds.y) c = c2;
		if (d > thresholds.z) c = c3;
		if (d > thresholds.w) c = c4;
	}
	DIFFUSE_LIGHT = to_linear(c);
}
