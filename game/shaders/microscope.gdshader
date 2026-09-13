shader_type canvas_item;
uniform float camera_zoom = 0.88;
uniform float flow_time = 0.0;
void fragment() {
 // The minimum zoom still covers the viewport; higher zoom crops into the same image.
 float magnification = camera_zoom / 0.45;
 vec2 uv = (UV - vec2(0.5)) / magnification + vec2(0.5);
 vec2 p = uv * vec2(9.6, 6.0);
 float t = flow_time * 0.12;
 vec2 drift = vec2(sin(p.y * 1.3 + t), cos(p.x * 1.1 - t * 0.8));
 float water = sin(p.x + drift.x + t) * cos(p.y + drift.y - t * 0.7);
 float veins = pow(1.0 - abs(sin(p.x * 1.7 + p.y + water * 1.8 + t * 0.5)), 5.0);
 vec2 ripple = vec2(sin(p.y + t), cos(p.x - t)) * 0.003;
 vec4 base = texture(TEXTURE, clamp(uv + ripple, vec2(0.004), vec2(0.996)));
 base.rgb += vec3(0.035, 0.045, 0.05) * water + vec3(0.065, 0.075, 0.08) * veins;
 COLOR = base;
}
