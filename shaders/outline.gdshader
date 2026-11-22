// Inverted-hull outline: drawn as a second pass (next_pass) with the mesh
// pushed out along its normals and only the back faces shown.
// Use on characters and interactive props only, not whole levels.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, specular_disabled;

uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.1, 1.0);
uniform float thickness = 0.025;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
