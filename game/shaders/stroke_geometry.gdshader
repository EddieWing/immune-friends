shader_type canvas_item;
render_mode unshaded;
uniform float arena_scale=1.0;
uniform float cilia_time=0.0;
void vertex() {
 // Only cached strokes encode an extrusion vector above the texture UV range.
 // Ordinary sprites, lines and polygons retain the default canvas transform.
 // Cilia and cached arcs have disjoint UV markers; regular art is untouched.
 if (UV.x>1500.0) {
  float i=UV.x-2000.0;
  float angle=i*6.283185307179586/30.0;
  vec2 n=vec2(cos(angle),sin(angle));
  vec2 root=n*10.7+vec2(n.y,-n.x)*sin(cilia_time*1.8+INSTANCE_CUSTOM.r+i)*0.22;
  vec2 tip=n*13.0;
  vec2 axis=normalize(root-tip);
  vec2 side=vec2(axis.y,-axis.x);
  float cap=VERTEX.y<0.0?0.46875:(VERTEX.y>1.0?-0.46875:0.0);
  VERTEX=(VERTEX.y<0.5?root:tip)+side*VERTEX.x+axis*cap;
  vec2 light=vec2(cos(cilia_time*0.12-3.141592653589793*0.6),sin(cilia_time*0.12-3.141592653589793*0.6));
  float weight=INSTANCE_CUSTOM.g*0.32+max(0.0,dot(n,light))*0.12;
  COLOR.rgb=mix(vec3(185.0,107.0,130.0)/255.0,vec3(230.0,182.0,199.0)/255.0,weight);
  UV=vec2(0.0);
 } else if (UV.x>500.0) {
  // The mesh transform scales the unit path; cancel that scale for its width.
  float radius=max(0.00001,length(MODEL_MATRIX[0].xy)/arena_scale);
  VERTEX+=(UV-vec2(1000.0))/radius;
  UV=vec2(0.0);
 }
}
