shader_type canvas_item;
render_mode unshaded;
void fragment() {
 vec2 lens = (UV - vec2(0.5)) * 2.0;
 float distance_from_center = length(lens);
 float edge = smoothstep(0.58, 1.38, distance_from_center);
 COLOR = vec4(0.035, 0.09, 0.13, edge * edge * 0.52);
}
