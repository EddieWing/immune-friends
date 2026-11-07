extends RefCounted
# Demo 1.0.0 numerical geometry; no original images/resources.
const SCALE=26.0/3.5
const MASS_UNIT=SCALE*SCALE/(PI*18.0*18.0)
const IMPULSE_UNIT=SCALE*MASS_UNIT
static var geometry=JSON.parse_string(FileAccess.get_file_as_string("res://data/body_geometry.json"))
static func size(body):
 if not body.has("key"):return Vector2.ONE*(float(body.get("physics_diameter",2.0))*SCALE if body.has("type") else 26.0)
 var pixels=geometry[body.key]
 return Vector2(pixels[0],pixels[1])*(SCALE/12.0)
static func impulse(value):return value*IMPULSE_UNIT
