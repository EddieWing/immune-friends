extends RefCounted
# Shared by field, shop, catalogue and drag previews. Visuals never mutate simulation.
var style=0
var cache={}
var icon_cache={}
var atlas: Texture2D
const ARCHETYPES=["wall","seeker","orbiter","bodyguard","turret","generator","bandage","bomb"]

func family(key,behavior):
 if behavior=="wall": return 0
 if behavior in ["seek","forward","drop","push"]: return 1
 if behavior in ["orbit","magnet"]: return 2
 if behavior in ["bond","buffer","wild"]: return 3
 if behavior in ["shoot","sniper","spray"]: return 4
 if behavior in ["generator","electric","bank"]: return 5
 if behavior in ["heal","bandage"]: return 6
 return 7

func set_style(value):
 style=clampi(value,0,1)
 cache.clear()
 icon_cache.clear()

func body(key,data):
 if cache.has(key): return cache[key]
 var kind=family(key,data.behavior)
 var texture: Texture2D
 if style==1:
  if atlas==null: atlas=load("res://assets/art/cell-atlas.png")
  var tile=AtlasTexture.new()
  tile.atlas=atlas
  var size=atlas.get_size()/Vector2(4,2)
  tile.region=Rect2(Vector2(kind%4,kind/4)*size,size)
  texture=tile
 else:
  var image=Image.new()
  image.load_svg_from_string(body_svg(kind,data.color))
  texture=ImageTexture.create_from_image(image)
 cache[key]=texture
 return texture

func tint(key,data):
 if style==0 or key in ARCHETYPES: return Color.WHITE
 return Color.WHITE.lerp(Color(data.color),0.38)

func icon(key,data):
 if icon_cache.has(key): return icon_cache[key]
 var image=body(key,data).get_image()
 image.convert(Image.FORMAT_RGBA8)
 image.resize(128,128,Image.INTERPOLATE_LANCZOS)
 var color=tint(key,data)
 if color!=Color.WHITE:
  for y in range(128):
   for x in range(128): image.set_pixel(x,y,image.get_pixel(x,y)*color)
 var face=Image.new()
 face.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><g fill="#35434b"><circle cx="54" cy="61" r="4"/><circle cx="74" cy="61" r="4"/></g><path d="M58 72 Q64 80 70 72" fill="none" stroke="#685463" stroke-width="3"/><g fill="#df8f9e" opacity=".6"><ellipse cx="45" cy="72" rx="5" ry="3"/><ellipse cx="83" cy="72" rx="5" ry="3"/></g></svg>')
 image.blend_rect(face,Rect2i(0,0,128,128),Vector2i.ZERO)
 var texture=ImageTexture.create_from_image(image)
 icon_cache[key]=texture
 return texture

func body_svg(kind,color):
 var shapes=[
  '<rect x="10" y="44" width="108" height="40" rx="19"/>',
  '<path d="M108 64 C78 43 63 19 42 30 C10 46 22 101 57 102 C78 101 97 84 108 64 Z"/>',
  '<path d="M88 25 C23 5 3 94 57 107 C72 111 88 103 99 91 C49 89 46 47 88 25 Z"/>',
  '<path d="M43 20 Q64 12 84 25 L108 53 Q115 65 104 85 L83 105 Q64 115 43 102 L21 81 Q13 65 23 45 Z"/>',
  '<circle cx="60" cy="64" r="39"/><rect x="88" y="53" width="27" height="22" rx="8"/>',
  '<path d="M37 19 C73 1 77 38 91 50 C125 78 101 115 61 108 C19 103 5 38 37 19 Z"/>',
  '<path d="M64 42 C33 -3 0 45 40 64 C-3 87 38 130 64 89 C90 131 130 88 88 64 C130 40 87 -2 64 42 Z"/>',
  '<circle cx="64" cy="64" r="43"/>'
 ]
 var accent=''
 if kind==1: accent='<path d="M34 42 L13 29 M28 55 L7 52 M30 80 L12 95" stroke="'+color+'" stroke-width="4" fill="none"/>'
 if kind==5: accent='<g fill="#e8fbff" opacity=".7"><circle cx="44" cy="37" r="9"/><circle cx="83" cy="81" r="10"/><circle cx="48" cy="87" r="7"/></g>'
 if kind==7: accent='<g fill="#fff5eb" opacity=".4"><circle cx="47" cy="35" r="10"/><circle cx="84" cy="43" r="7"/><circle cx="83" cy="89" r="10"/></g>'
 return '<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128"><g fill="'+color+'" stroke="'+Color(color).darkened(0.22).to_html(false).insert(0,'#')+'" stroke-width="4">'+shapes[kind]+'</g>'+accent+'</svg>'
