// Toon (cel) shader: 3 lighting bands from the sun, soft pools from lamps,
// a rim highlight on the lit side, and an optional world-space surface pattern
// (floor tiles / wall panels) for level geometry.
// Works on the Compatibility (OpenGL ES 3) renderer and the Mobile renderer.
//
// Exposure notes (why the old version looked washed out):
//  - the rim used to be EMISSION (unlit glow) on every surface; floors and walls
//    seen at a grazing angle - which is how a third-person camera sees them -
//    glowed with 30 % of their colour. Now the rim is a lighting term, only on
//    the lit side, and level surfaces use rim_strength 0.
//  - fully shadowed pixels used to land in the middle of the first band
//    (smoothstep at 0 = 0.5), so shadows barely darkened anything. Now shadows
//    blend toward the shadow band.
//  - lamps used the sun's hard bands and made bright discs on the walls; now
//    they add a soft falloff.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.12;  // sunlight kept in the darkest band
uniform float mid_level : hint_range(0.0, 1.0) = 0.58;     // sunlight in the middle band
uniform float band_soft : hint_range(0.001, 0.2) = 0.04;   // edge softness between bands
uniform float emission_amount : hint_range(0.0, 2.0) = 0.0;
// 0 = plain, 1 = floor tiles (checker + grout), 2 = wall panels (seams)
uniform int pattern = 0;
uniform float pattern_scale = 1.0;      // tile / panel size in metres
uniform float pattern_strength = 0.14;  // how much darker grout / alternate tiles are

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// 1 on the grout lines of a unit grid, 0 inside the tiles.
float grid_line(vec2 uv, float width) {
	vec2 f = abs(fract(uv) - 0.5);
	float d = max(f.x, f.y);
	return smoothstep(0.5 - width, 0.5 - width * 0.35, d);
}

void fragment() {
	vec3 col = albedo.rgb;
	if (pattern > 0) {
		// Project onto the plane the surface faces (works for floors on walls too).
		vec3 n = abs(world_nrm);
		vec2 uv = world_pos.xy;
		if (n.y >= n.x && n.y >= n.z) {
			uv = world_pos.xz;
		} else if (n.x >= n.z) {
			uv = world_pos.zy;
		}
		uv /= pattern_scale;
		if (pattern == 1) {
			float checker = mod(floor(uv.x) + floor(uv.y), 2.0);
			col *= 1.0 - pattern_strength * 0.5 * checker;
			col *= 1.0 - pattern_strength * grid_line(uv, 0.035);
		} else {
			col *= 1.0 - pattern_strength * 0.8 * grid_line(vec2(uv.x * 0.5, uv.y), 0.02);
		}
	}
	ALBEDO = col;
	ROUGHNESS = 1.0;
	EMISSION = col * emission_amount;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit;
	if (LIGHT_IS_DIRECTIONAL) {
		float b1 = smoothstep(-band_soft, band_soft, ndl);
		float b2 = smoothstep(0.45 - band_soft, 0.45 + band_soft, ndl);
		lit = mix(mix(shadow_level, mid_level, b1), 1.0, b2);
		// In a cast shadow: drop to the darkest band (soft edge).
		lit = mix(shadow_level, lit, smoothstep(0.15, 0.85, ATTENUATION));
	} else {
		lit = smoothstep(-0.1, 0.7, ndl) * ATTENUATION;
	}
	float rim = smoothstep(0.62, 1.0, 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0));
	lit += rim * rim_strength * clamp(ndl + 0.4, 0.0, 1.0) * min(ATTENUATION * 2.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
