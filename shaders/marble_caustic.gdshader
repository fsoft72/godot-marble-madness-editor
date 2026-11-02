// Caustic of the glass marble on the floor: the light focused by the sphere, a bright tinted
// spot with a soft ring, drawn additively on a quad lying on the floor.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.9, 0.1, 0.13);
uniform float strength = 1.4;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float core = exp(-r * r * 18.0);
	float ring = exp(-pow((r - 0.55) * 7.0, 2.0)) * 0.35;
	vec3 c = mix(tint, vec3(1.0, 0.95, 0.85), core) * (core * 1.6 + ring) * strength;
	ALBEDO = c * smoothstep(1.0, 0.8, r);
}
