shader_type canvas_item;
render_mode unshaded;
uniform float arena_scale=1.0;
void vertex() {
 // Only cached strokes encode an extrusion vector above the texture UV range.
 // Ordinary sprites, lines and polygons retain the default canvas transform.
 if (UV.x>500.0) {
  // The mesh transform scales the unit path; cancel that scale for its width.
  float radius=max(0.00001,length(MODEL_MATRIX[0].xy)/arena_scale);
  VERTEX+=(UV-vec2(1000.0))/radius;
  UV=vec2(0.0);
 }
}
