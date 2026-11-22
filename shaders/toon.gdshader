// Toon (cel) shader: 3 flat lighting bands, soft rim light, flat colour.
// Works on the Compatibility (OpenGL) renderer and the Mobile renderer.
shader_type spatial;
render_mode specular_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_strength : hint_range(0.0, 1.0) = 0.3;
uniform float shadow_level : hint_range(0.0, 1.0) = 0.0;   // light kept in the darkest band
uniform float mid_level : hint_range(0.0, 1.0) = 0.55;     // light in the middle band
uniform float band_soft : hint_range(0.001, 0.2) = 0.03;   // edge softness between bands
uniform float emission_amount : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = 1.0;
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	EMISSION = albedo.rgb * (smoothstep(0.6, 1.0, rim) * rim_strength + emission_amount);
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float b1 = smoothstep(0.0 - band_soft, 0.0 + band_soft, ndl);
	float b2 = smoothstep(0.5 - band_soft, 0.5 + band_soft, ndl);
	float lit = mix(shadow_level, mid_level, b1);
	lit = mix(lit, 1.0, b2);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
}
