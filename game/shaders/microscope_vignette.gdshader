shader_type canvas_item;
render_mode unshaded;
uniform float aperture = 1.0;
void fragment() {
 vec2 lens = (UV - vec2(0.5)) * vec2(2.0, 1.0);
 float edge = smoothstep(0.91, 1.03, length(lens) / aperture);
 COLOR = vec4(0.025, 0.031, 0.035, edge * 0.98);
}
