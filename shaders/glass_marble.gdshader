// Ray traced glass marble.
// Each fragment of the sphere mesh starts an analytic ray trace in view space:
//  - Fresnel (Schlick) split between reflection and refraction at the entry point;
//  - refraction into the sphere (Snell), with one ray per color channel (dispersion);
//  - intersection of the internal ray with the inner core spheres (the eight dots of the
//    arcade marble, they turn with the marble) and an internal reflection on total internal
//    reflection;
//  - exit refraction and a lookup of the screen behind the marble along the exit ray, so the
//    level is seen bent and flipped through the glass;
//  - Beer-Lambert absorption by the length of the path inside the tinted glass;
//  - reflection of an analytic sky with the sun and a soft area light, plus sharp specular
//    highlights and a rim.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_always, cull_back, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform vec3 tint : source_color = vec3(0.9, 0.1, 0.13);
uniform float radius = 0.52;
uniform float ior = 1.52;
uniform float dispersion = 0.035;
uniform float absorption = 2.6;
uniform float specular_power = 420.0;
uniform float behind_distance = 1.2;
uniform vec3 sun_dir_world = vec3(-0.45, 0.75, -0.48);
uniform vec3 sun_color : source_color = vec3(1.0, 0.97, 0.9);
uniform vec3 sky_top : source_color = vec3(0.45, 0.55, 0.75);
uniform vec3 sky_horizon : source_color = vec3(0.85, 0.85, 0.8);
uniform vec3 ground_color : source_color = vec3(0.25, 0.22, 0.2);
uniform float dot_radius = 0.05;
uniform vec3 dot_corner_color : source_color = vec3(1.0, 0.95, 0.46);
uniform vec3 dot_median_color : source_color = vec3(0.28, 0.86, 0.98);
// Rotation of the inner core inside the marble (object space), so it can be tilted.
uniform mat3 core_basis = mat3(1.0);

const int DOT_COUNT = 8;

// Returns the distance along a ray (origin o, unit direction d) to the far side of a sphere
// that contains o, or the near hit of a sphere outside it; -1 for a miss.
float sphere_hit(vec3 o, vec3 d, vec3 c, float r, bool far_side) {
	vec3 oc = o - c;
	float b = dot(oc, d);
	float cc = dot(oc, oc) - r * r;
	float h = b * b - cc;
	if (h < 0.0) return -1.0;
	h = sqrt(h);
	float t = far_side ? -b + h : -b - h;
	return t;
}

// Analytic environment seen along a view space direction.
vec3 environment(vec3 dir_view, mat4 inv_view) {
	vec3 d = normalize((inv_view * vec4(dir_view, 0.0)).xyz);
	vec3 sun = normalize(sun_dir_world);
	float up = d.y;
	vec3 sky = up >= 0.0 ? mix(sky_horizon, sky_top, pow(up, 0.6)) : mix(sky_horizon, ground_color, pow(-up, 0.4));
	float s = max(dot(d, sun), 0.0);
	sky += sun_color * (pow(s, 900.0) * 30.0 + pow(s, 60.0) * 0.6);
	// A soft rectangular area light opposite the sun, for a second window like highlight.
	vec3 fill = normalize(vec3(0.6, 0.5, 0.6));
	float f = max(dot(d, fill), 0.0);
	sky += vec3(0.6, 0.7, 1.0) * smoothstep(0.985, 0.995, f) * 1.5;
	return sky;
}

// Screen color behind the marble along a view space ray leaving the sphere at p.
vec3 behind(vec3 p, vec3 d, mat4 proj, mat4 inv_view) {
	vec3 q = p + d * behind_distance;
	vec4 clip = proj * vec4(q, 1.0);
	vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return environment(d, inv_view);
	return textureLod(screen_tex, uv, 0.0).rgb;
}

// Index of refraction of one color channel (0 red, 1 green, 2 blue).
float channel_ior(int ch) {
	return ior + (float(ch) - 1.0) * dispersion;
}

// Traces one channel through the glass; returns the transmitted color of that channel.
float trace_channel(int ch, vec3 p0, vec3 rd, vec3 c, float r, mat4 model_view, mat4 proj, mat4 inv_view) {
	float eta = channel_ior(ch);
	vec3 n0 = normalize(p0 - c);
	vec3 r1 = refract(rd, n0, 1.0 / eta);
	if (dot(r1, r1) == 0.0) return environment(reflect(rd, n0), inv_view)[ch];
	float t1 = sphere_hit(p0 + r1 * 1e-4, r1, c, r, true);
	// Inner core: the eight dots of the arcade marble, in object space turned with the marble.
	float best = t1;
	vec3 dot_col = vec3(0.0);
	float s = 0.48;
	for (int i = 0; i < DOT_COUNT; i++) {
		vec3 lp;
		if (i == 0) lp = vec3(-s, 0.0, -s);
		else if (i == 1) lp = vec3(s, 0.0, -s);
		else if (i == 2) lp = vec3(s, 0.0, s);
		else if (i == 3) lp = vec3(-s, 0.0, s);
		else if (i == 4) lp = vec3(0.0, 0.0, -s);
		else if (i == 5) lp = vec3(s, 0.0, 0.0);
		else if (i == 6) lp = vec3(0.0, 0.0, s);
		else lp = vec3(-s, 0.0, 0.0);
		vec3 wp = (model_view * vec4(core_basis * lp * radius, 1.0)).xyz;
		float dr = dot_radius * r / radius;
		float th = sphere_hit(p0, r1, wp, dr, false);
		if (th > 0.0 && th < best) {
			best = th;
			vec3 hp = p0 + r1 * th;
			vec3 hn = normalize(hp - wp);
			float lit = 0.35 + 0.65 * max(dot(hn, normalize(-rd + vec3(0.0, 0.6, 0.0))), 0.0);
			dot_col = (i < 4 ? dot_corner_color : dot_median_color) * lit;
		}
	}
	float absorb_len = best;
	vec3 transmit = exp(-absorption * (vec3(1.0) - tint) * absorb_len / r * radius);
	if (best < t1) return dot_col[ch] * transmit[ch] + dot_col[ch] * 0.25;
	vec3 p1 = p0 + r1 * t1;
	vec3 n1 = normalize(p1 - c);
	vec3 r2 = refract(r1, -n1, eta);
	if (dot(r2, r2) == 0.0) {
		// Total internal reflection: bounce once inside and leave on the other side.
		vec3 rr = reflect(r1, -n1);
		float t2 = sphere_hit(p1 + rr * 1e-4, rr, c, r, true);
		vec3 p2 = p1 + rr * t2;
		vec3 r3 = refract(rr, -normalize(p2 - c), eta);
		if (dot(r3, r3) == 0.0) r3 = rr;
		transmit *= exp(-absorption * (vec3(1.0) - tint) * t2 / r * radius);
		return behind(p2, r3, proj, inv_view)[ch] * transmit[ch];
	}
	return behind(p1, r2, proj, inv_view)[ch] * transmit[ch];
}

void fragment() {
	mat4 model_view = VIEW_MATRIX * MODEL_MATRIX;
	vec3 c = (model_view * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float scale = length((model_view * vec4(1.0, 0.0, 0.0, 0.0)).xyz);
	float r = radius * scale;
	bool ortho = PROJECTION_MATRIX[3][3] != 0.0;
	vec3 rd = ortho ? vec3(0.0, 0.0, -1.0) : normalize(VERTEX);
	// Start the trace on the exact sphere, not on the faceted mesh.
	vec3 origin = ortho ? vec3(VERTEX.xy, c.z + 10.0 * r) : vec3(0.0);
	float t0 = sphere_hit(origin, rd, c, r, false);
	if (t0 < 0.0) discard;
	vec3 p0 = origin + rd * t0;
	vec3 n0 = normalize(p0 - c);
	float cos_i = clamp(dot(-rd, n0), 0.0, 1.0);
	float f0 = pow((ior - 1.0) / (ior + 1.0), 2.0);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - cos_i, 5.0);
	vec3 refl = environment(reflect(rd, n0), INV_VIEW_MATRIX);
	vec3 trans;
	trans.r = trace_channel(0, p0, rd, c, r, model_view, PROJECTION_MATRIX, INV_VIEW_MATRIX);
	trans.g = trace_channel(1, p0, rd, c, r, model_view, PROJECTION_MATRIX, INV_VIEW_MATRIX);
	trans.b = trace_channel(2, p0, rd, c, r, model_view, PROJECTION_MATRIX, INV_VIEW_MATRIX);
	// Glass body glow: light scattered inside the tinted glass.
	vec3 body = tint * 0.18 * (1.0 - cos_i * 0.5);
	vec3 col = mix(trans + body, refl, fresnel);
	// Sharp highlights of the sun and of the blue fill light (Blinn-Phong on the exact sphere).
	vec3 l_sun = normalize((VIEW_MATRIX * vec4(normalize(sun_dir_world), 0.0)).xyz);
	vec3 v = -rd;
	col += sun_color * pow(max(dot(n0, normalize(l_sun + v)), 0.0), specular_power) * 4.0;
	col += sun_color * pow(max(dot(n0, normalize(l_sun + v)), 0.0), 40.0) * 0.12;
	vec3 l_fill = normalize((VIEW_MATRIX * vec4(0.6, 0.45, -0.6, 0.0)).xyz);
	col += vec3(0.55, 0.65, 1.0) * pow(max(dot(n0, normalize(l_fill + v)), 0.0), specular_power * 0.5) * 1.2;
	// Rim: a thin bright edge from grazing reflections.
	col += vec3(1.0) * pow(1.0 - cos_i, 8.0) * 0.35;
	ALBEDO = col;
	ALPHA = 1.0;
	// Write the depth of the exact sphere surface.
	vec4 clip = PROJECTION_MATRIX * vec4(p0, 1.0);
	DEPTH = clip.z / clip.w;
}
