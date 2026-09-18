shader_type canvas_item;
render_mode unshaded;
uniform float aperture = 1.0;
uniform float radius = 0.54;
uniform float visibility = 1.0;
uniform float optical_intensity = 1.0;
void fragment() {
 vec2 lens = (UV - vec2(0.5)) * vec2(1.6, 1.0);
 float d = length(lens);
 float r = radius * aperture;
 float edge = smoothstep(r - 0.10, r + 0.16, d);
 float rim = exp(-pow((d-r+0.035)/0.032,2.0))*0.11*optical_intensity;
 vec3 color = mix(vec3(0.30,0.43,0.51),vec3(0.70,0.86,0.94),rim);
 COLOR = vec4(color,edge*0.16*visibility);
}
