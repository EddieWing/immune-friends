extends Control
var game
var dragging=false
func _ready():
 mouse_filter=Control.MOUSE_FILTER_STOP
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 focus_mode=Control.FOCUS_ALL
 tooltip_text="Нажмите или перетащите для изменения масштаба"
func set_from_y(y):
 var ratio=clampf((230.0-y)/200.0,0,1)
 game.view.scale=Vector2.ONE*(0.45+ratio*1.05)
 game.update_zoom()
func _gui_input(event):
 if game.modal.visible: return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index==MOUSE_BUTTON_LEFT:
   dragging=true
   grab_focus()
   set_from_y(event.position.y)
   accept_event()
  elif event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
   var factor=1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.1
   game.view.scale=Vector2.ONE*clampf(game.view.scale.x*factor,0.45,1.5)
   game.update_zoom()
   accept_event()
 if event is InputEventKey and event.pressed and event.keycode in [KEY_UP,KEY_DOWN,KEY_HOME,KEY_END]:
  var value=game.view.scale.x
  if event.keycode==KEY_UP: value+=0.0525
  if event.keycode==KEY_DOWN: value-=0.0525
  if event.keycode==KEY_HOME: value=0.45
  if event.keycode==KEY_END: value=1.5
  game.view.scale=Vector2.ONE*clampf(value,0.45,1.5)
  game.update_zoom()
  accept_event()
func _input(event):
 if not dragging: return
 if game.modal.visible:
  dragging=false
  return
 if event is InputEventMouseMotion:
  set_from_y((get_global_transform().affine_inverse()*event.position).y)
  get_viewport().set_input_as_handled()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
  dragging=false
  get_viewport().set_input_as_handled()
func _draw():
 var ratio=clampf((game.view.scale.x-0.45)/1.05,0,1)
 var ink=Color("#385265")
 var font=ThemeDB.fallback_font
 draw_string(font,Vector2(1,14),"Зум",HORIZONTAL_ALIGNMENT_LEFT,-1,13,ink)
 draw_style_box(track_style(Color(0.94,0.97,1,0.8)),Rect2(9,30,10,200))
 draw_style_box(track_style(Color("#678fab")),Rect2(9,230-200*ratio,10,200*ratio))
 for tick in range(11):
  var y=230-tick*20
  draw_line(Vector2(24,y),Vector2(31 if tick%5==0 else 28,y),ink,1,true)
 draw_circle(Vector2(14,230-200*ratio),6,Color("#fff5d8"))
 draw_string(font,Vector2(0,252),str(roundi(ratio*100))+"%",HORIZONTAL_ALIGNMENT_LEFT,-1,12,ink)
func track_style(color):
 var box=StyleBoxFlat.new()
 box.bg_color=color
 box.set_corner_radius_all(5)
 return box
