// Cliff wall in the arcade palette style: vertical stripes, one per world unit along the wall,
// with a seam centered on each integer coordinate. In the sun shadow the shadow colors are used.
// UV.x runs along the wall in world units.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

uniform vec3 stripe_lit = vec3(204.0, 204.0, 0.0);
uniform vec3 seam_lit = vec3(102.0, 102.0, 102.0);
uniform vec3 stripe_shadow = vec3(204.0, 102.0, 0.0);
uniform vec3 seam_shadow = vec3(51.0, 51.0, 51.0);
uniform float seam_width = 0.25;
uniform bool use_shadows = true;

varying vec3 lit_color;
varying vec3 shadow_color;

vec3 to_linear(vec3 c) {
	vec3 s = c / 255.0;
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s));
}

void fragment() {
	float f = fract(UV.x + seam_width * 0.5);
	bool seam = f < seam_width;
	lit_color = to_linear(seam ? seam_lit : stripe_lit);
	shadow_color = to_linear(seam ? seam_shadow : stripe_shadow);
	ALBEDO = vec3(1.0);
}

void light() {
	bool shadowed = use_shadows && ATTENUATION < 0.5;
	DIFFUSE_LIGHT = shadowed ? shadow_color : lit_color;
}
