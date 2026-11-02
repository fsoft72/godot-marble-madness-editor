// Top surface of a block in the arcade palette style.
// COLOR.r holds the shade level (0..5) / 5 of the triangle.
// pattern: per tile offset map (R = offset * 85 / 255), repeated 3x3 over the block.
// paint: per block map, R = ramp id / 3 (0 gray, 1 red). A = 0.5: decal, only the ramp changes;
// A = 1: absolute texel, G = palette level / 5 replaces level - offset (block "paint" field).
// The output color is ramp[level - offset]; in the sun shadow the level becomes shadow_level.
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

uniform sampler2D pattern : filter_nearest, repeat_enable;
uniform sampler2D paint : filter_nearest, repeat_disable;
uniform int shadow_level = 1;
uniform bool use_shadows = true;

const vec3 GRAY[6] = vec3[](vec3(51.0), vec3(68.0), vec3(102.0), vec3(153.0), vec3(187.0), vec3(221.0));
const vec3 RED[6] = vec3[](vec3(102.0, 0.0, 0.0), vec3(102.0, 34.0, 34.0), vec3(136.0, 34.0, 34.0), vec3(170.0, 34.0, 34.0), vec3(221.0, 51.0, 51.0), vec3(255.0, 136.0, 136.0));

varying vec3 lit_color;
varying vec3 shadow_color;

// sRGB (0..255) to linear, so the final sRGB output is the exact palette value.
vec3 to_linear(vec3 c) {
	vec3 s = c / 255.0;
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s));
}

vec3 ramp_color(int ramp, int level) {
	int l = clamp(level, 0, 5);
	if (ramp == 1) return RED[l];
	return GRAY[l];
}

void fragment() {
	int offset = int(round(texture(pattern, UV * 3.0).r * 3.0));
	vec4 p = texture(paint, UV);
	int ramp = p.a > 0.25 ? int(round(p.r * 3.0)) : 0;
	int level = int(round(COLOR.r * 5.0));
	int lit = level - offset;
	int dark = min(level, shadow_level) - offset;
	if (p.a > 0.75) {
		// Baked texels already hold the reference light and shadow.
		lit = int(round(p.g * 5.0));
		dark = lit;
	}
	lit_color = to_linear(ramp_color(ramp, lit));
	shadow_color = to_linear(ramp_color(ramp, dark));
	ALBEDO = vec3(1.0);
}

void light() {
	bool shadowed = use_shadows && ATTENUATION < 0.5;
	DIFFUSE_LIGHT = shadowed ? shadow_color : lit_color;
}
