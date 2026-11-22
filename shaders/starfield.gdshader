// Procedural space sky: twinkling stars, a nebula gradient and a big slowly
// orbiting gas-giant planet. `storm` (0..1) tints the sky during gravity storms.
shader_type sky;

uniform vec3 deep_color : source_color = vec3(0.02, 0.02, 0.08);
uniform vec3 nebula_a : source_color = vec3(0.35, 0.1, 0.45);
uniform vec3 nebula_b : source_color = vec3(0.05, 0.3, 0.45);
uniform vec3 planet_color : source_color = vec3(1.0, 0.55, 0.3);
uniform vec3 planet_band : source_color = vec3(0.85, 0.3, 0.35);
uniform vec3 storm_color : source_color = vec3(0.6, 0.05, 0.08);
uniform float planet_size = 0.32;      // angular radius in radians
uniform float planet_speed = 0.01;     // radians per second around the station
uniform float star_density = 0.985;    // higher = fewer stars
uniform float storm = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(mix(mix(n000, n100, f.x), mix(n010, n110, f.x), f.y),
		mix(mix(n001, n101, f.x), mix(n011, n111, f.x), f.y), f.z);
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// Nebula: two soft noise layers blended with a vertical gradient.
	float n = noise3(d * 3.0) * 0.6 + noise3(d * 7.0) * 0.4;
	vec3 col = deep_color;
	col = mix(col, nebula_a, smoothstep(0.45, 0.9, n) * 0.55);
	col = mix(col, nebula_b, smoothstep(0.5, 1.0, noise3(d * 2.0 + 5.0)) * 0.5);
	// Stars and the planet are skipped in the cheap cubemap (reflection) pass.
	if (!AT_CUBEMAP_PASS) {
		// Stars: hash on a grid of directions.
		vec3 sp = d * 140.0;
		vec3 cell = floor(sp);
		float h = hash3(cell);
		if (h > star_density) {
			vec3 f = fract(sp) - 0.5;
			float tw = 0.7 + 0.3 * sin(TIME * (2.0 + h * 5.0) + h * 40.0);
			col += vec3(1.0, 0.95, 0.85) * smoothstep(0.35, 0.0, length(f)) * tw;
		}
		// Planet slowly orbits around the station.
		float a = TIME * planet_speed;
		vec3 pdir = normalize(vec3(cos(a), -0.15, sin(a)));
		float ang = acos(clamp(dot(d, pdir), -1.0, 1.0));
		if (ang < planet_size) {
			float r = ang / planet_size;
			vec3 up = vec3(0.0, 1.0, 0.0);
			float lat = dot(d - pdir, up) / planet_size;
			float bands = sin(lat * 18.0 + noise3(d * 20.0) * 2.0) * 0.5 + 0.5;
			vec3 pc = mix(planet_color, planet_band, bands * 0.6);
			// Cartoon terminator: lit side toward +x of the planet.
			vec3 side = normalize(cross(up, pdir));
			float lit = smoothstep(-0.2, 0.25, dot(d - pdir, side) / planet_size + 0.3);
			pc *= mix(0.35, 1.0, lit);
			pc = mix(pc, pc * 0.6, smoothstep(0.8, 1.0, r));
			col = mix(col, pc, smoothstep(1.0, 0.97, r));
		} else if (ang < planet_size * 1.15) {
			// thin glowing atmosphere ring
			float g = 1.0 - (ang - planet_size) / (planet_size * 0.15);
			col += planet_color * g * g * 0.35;
		}
	}
	COLOR = mix(col, col * 0.6 + storm_color * 0.5, storm);
}
