// Cosmic sludge: wobbly, glowing lime-to-purple goo. Toxic but cute.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 lime : source_color = vec4(0.6, 1.0, 0.25, 1.0);
uniform vec4 purple : source_color = vec4(0.55, 0.2, 0.75, 1.0);
uniform float wobble = 0.06;
uniform float glow = 0.45;

varying float v_mix;

void vertex() {
	float t = TIME * 3.0 + VERTEX.x * 7.0 + VERTEX.z * 5.0;
	VERTEX += NORMAL * sin(t) * wobble;
	v_mix = clamp(VERTEX.y * 2.0 + 0.5 + sin(TIME + VERTEX.x * 4.0) * 0.2, 0.0, 1.0);
}

void fragment() {
	vec3 c = mix(purple.rgb, lime.rgb, v_mix);
	ALBEDO = c;
	ROUGHNESS = 0.3;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = lime.rgb * (glow * 0.5 + smoothstep(0.4, 1.0, rim) * glow);
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float lit = mix(0.25, 1.0, smoothstep(0.05, 0.15, ndl));
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
