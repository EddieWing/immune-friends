shader_type canvas_item;
uniform bool new_style = false;
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
 if(new_style) {
  float band1=abs(uv.y-(0.40+0.065*sin(uv.x*7.0+t*0.22)));
  float band2=abs(uv.y-(0.78+0.065*sin(uv.x*6.0-t*0.17)));
  float bands=1.0-smoothstep(0.018,0.024,min(band1,band2));
  base=mix(vec3(0.76,0.85,0.90),vec3(0.85,0.92,0.96),0.5+0.5*sin(uv.y*3.0));
  base=mix(base,vec3(0.93,0.97,0.99),bands*0.55);
  vec2 bubbles=uv*vec2(23.0,15.0)+vec2(t*0.02,t*0.035);
  vec2 cell=floor(bubbles);
  float random=fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453);
  float bubble=(1.0-smoothstep(0.06,0.095,length(fract(bubbles)-vec2(0.2+0.6*random,0.2+0.6*fract(random*7.0)))))*step(0.78,random);
  base=mix(base,vec3(0.98),bubble*0.4);
 }
 COLOR=vec4(base,1.0);
}
