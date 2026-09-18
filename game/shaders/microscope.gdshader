shader_type canvas_item;
uniform float camera_zoom = 0.88;
uniform float flow_time = 0.0;
uniform vec2 camera_offset = vec2(0.0);
uniform float optical_intensity = 1.0;
void fragment() {
 float magnification = camera_zoom / 0.45;
 vec2 uv = (UV-vec2(0.5))/magnification+vec2(0.5)+camera_offset*0.00012;
 vec2 p=uv*vec2(9.6,6.0);
 float t=flow_time*0.1;
 vec2 drift=vec2(sin(p.y*1.3+t),cos(p.x*1.1-t*0.8));
 float water=sin(p.x+drift.x+t)*cos(p.y+drift.y-t*0.7);
 float veins=pow(1.0-abs(sin(p.x*1.7+p.y+water*1.8)),12.0);
 float periphery=smoothstep(0.12,0.65,length(UV-vec2(0.5)));
 vec2 ripple=vec2(sin(p.y+t),cos(p.x-t))*0.002*periphery*optical_intensity;
 vec3 base=texture(TEXTURE,clamp(uv+ripple,vec2(0.004),vec2(0.996))).rgb;
 base=mix(vec3(0.68,0.79,0.87),base,0.45);
 base+=vec3(0.014,0.020,0.025)*water+vec3(0.027,0.031,0.035)*veins;
 COLOR=vec4(base,1.0);
}
