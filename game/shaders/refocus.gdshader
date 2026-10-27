shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength=0.0;
void fragment(){
 vec2 step_uv=SCREEN_PIXEL_SIZE*strength*1.25;
 vec3 c=texture(screen_texture,SCREEN_UV).rgb*0.4;
 c+=texture(screen_texture,SCREEN_UV+vec2(step_uv.x,0)).rgb*0.15;
 c+=texture(screen_texture,SCREEN_UV-vec2(step_uv.x,0)).rgb*0.15;
 c+=texture(screen_texture,SCREEN_UV+vec2(0,step_uv.y)).rgb*0.15;
 c+=texture(screen_texture,SCREEN_UV-vec2(0,step_uv.y)).rgb*0.15;
 COLOR=vec4(c,1.0);
}
