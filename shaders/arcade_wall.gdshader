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
// Baked shadow (TextureFactory.make_baked_wall_material): per row and 1/8 unit, a depth interval
// below the wall top edge that is in the shadow. UV2 = (top edge height, row or -1).
uniform sampler2D wall_shadow : filter_nearest, repeat_disable;
uniform bool has_wall_shadow = false;
const float SHADOW_RANGE = 64.0;
varying float baked;

varying vec3 lit_color;
varying vec3 shadow_color;

vec3 to_linear(vec3 c) {
	vec3 s = c / 255.0;
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s));
}

void fragment() {
	baked = -1.0;
	if (has_wall_shadow && UV2.y > -0.5) {
		float world_y = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).y;
		float depth = UV2.x - world_y;
		ivec2 texel = ivec2(clamp(int(floor(UV.x * 8.0)), 0, 23), int(round(UV2.y)));
		vec2 iv = texelFetch(wall_shadow, texel, 0).rg * SHADOW_RANGE;
		if (iv.x >= 0.0) baked = (depth >= iv.x && depth < iv.y) ? 1.0 : 0.0;
	}
	float f = fract(UV.x + seam_width * 0.5);
	bool seam = f < seam_width;
	lit_color = to_linear(seam ? seam_lit : stripe_lit);
	shadow_color = to_linear(seam ? seam_shadow : stripe_shadow);
	ALBEDO = vec3(1.0);
}

void light() {
	bool shadowed = baked >= 0.0 ? baked > 0.5 : (use_shadows && ATTENUATION < 0.5);
	DIFFUSE_LIGHT = shadowed ? shadow_color : lit_color;
}
