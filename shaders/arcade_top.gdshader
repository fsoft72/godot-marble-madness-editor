// Top surface of a block in the arcade palette style, lit by the sun.
// The shade level (0..5) of a triangle comes from the sun light: N.L picks level 2..5 with
// shade_thresholds (fitted with the sun direction to assets/level01_ref.png: 88% of the tiles); in the sun shadow the level is at most
// shadow_level. A triangle with an explicit shade (subShades, shade presets) has COLOR.a = 1 and
// its level in COLOR.r * 5.
// pattern: per tile offset map (R = offset / 3: 0 fill, 1 edge, 2 line), repeated 3x3 over the block.
// paint: per block decal map (procedural decals), R = ramp id / 3 (0 gray, 1 red), A > 0.25 painted.
// The output color is ramp[level - offset].
shader_type spatial;
render_mode ambient_light_disabled, specular_disabled, cull_back;

uniform sampler2D pattern : filter_nearest, repeat_enable;
uniform sampler2D paint : filter_nearest, repeat_disable;
uniform int shadow_level = 1;
uniform vec3 shade_thresholds = vec3(0.174, 0.404, 0.597);
uniform bool use_shadows = true;

const vec3 GRAY[6] = vec3[](vec3(51.0), vec3(68.0), vec3(102.0), vec3(153.0), vec3(187.0), vec3(221.0));
const vec3 RED[6] = vec3[](vec3(102.0, 0.0, 0.0), vec3(102.0, 34.0, 34.0), vec3(136.0, 34.0, 34.0), vec3(170.0, 34.0, 34.0), vec3(221.0, 51.0, 51.0), vec3(255.0, 136.0, 136.0));

varying float v_offset;
varying float v_ramp;
varying float v_level;

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
	v_offset = round(texture(pattern, UV * 3.0).r * 3.0);
	vec4 p = texture(paint, UV);
	v_ramp = p.a > 0.25 ? round(p.r * 3.0) : 0.0;
	v_level = COLOR.a > 0.5 ? round(COLOR.r * 5.0) : -1.0;
	ALBEDO = vec3(1.0);
}

void light() {
	int level = int(v_level);
	if (level < 0) {
		float d = dot(NORMAL, LIGHT);
		level = 2;
		if (d > shade_thresholds.x) level = 3;
		if (d > shade_thresholds.y) level = 4;
		if (d > shade_thresholds.z) level = 5;
	}
	if (use_shadows && ATTENUATION < 0.5) level = min(level, shadow_level);
	DIFFUSE_LIGHT = to_linear(ramp_color(int(v_ramp), level - int(v_offset)));
}
