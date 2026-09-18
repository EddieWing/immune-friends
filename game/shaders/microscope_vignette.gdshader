shader_type canvas_item;
render_mode unshaded;
uniform float aperture = 1.0;
uniform float radius = 0.54;
uniform float visibility = 1.0;
uniform float optical_intensity = 1.0;
uniform float bleeding = 0.0;
uniform float preparation = 0.0;
void fragment() {
 vec2 lens = (UV - vec2(0.5)) * vec2(1.6, 1.0);
 float d = length(lens);
 float r = radius * aperture;
 float edge = smoothstep(r - mix(0.10,0.045,preparation), r + mix(0.16,0.065,preparation), d);
 float rim = exp(-pow((d-r+0.035)/0.032,2.0))*0.11*optical_intensity;
 vec3 color = mix(mix(vec3(0.30,0.43,0.51),vec3(0.025,0.031,0.045),preparation),vec3(0.70,0.86,0.94),rim);
 vec2 screen_edge=abs(UV-vec2(0.5))*2.0;
 float border=smoothstep(0.55,1.0,max(screen_edge.x,screen_edge.y));
 float organic=0.78+0.22*sin(UV.x*37.0+sin(UV.y*29.0)*2.0);
 float blood_alpha=border*organic*bleeding*0.22;
 float lens_alpha=edge*mix(0.16,0.97,preparation);
 float alpha=blood_alpha+lens_alpha*(1.0-blood_alpha);
 vec3 composite=(vec3(0.72,0.12,0.24)*blood_alpha+color*lens_alpha*(1.0-blood_alpha))/max(alpha,0.0001);
 COLOR = vec4(composite,alpha*visibility);
}
