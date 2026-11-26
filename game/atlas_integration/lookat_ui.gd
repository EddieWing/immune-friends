extends RefCounted
# Thin UI bridge, optional when porting the portable lookat observer.
var last_down=false
var clicked_uid=''
func sample(game,view):
 var observer=view.atlas.lookat
 var cursor=view.get_local_mouse_position()
 var hovered_control=game.get_viewport().gui_get_hovered_control()
 var modal=game.modal.visible or game.main_menu.visible or game.entering_game
 var over=not modal and (hovered_control==null or hovered_control==view.get_parent())
 var hover='';var distance=INF
 for uid in observer.engine.near(cursor,observer.engine.config.near):
  var a=observer.engine.actors[uid];var d=cursor.distance_to(a.body.p)
  if d<maxf(a.radius,observer.engine.config.line_width) and d<distance:distance=d;hover=uid
 var down=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
 clicked_uid=hover if down and not last_down else ''
 last_down=down
 var selected='cell:'+str(game.selected.id) if not game.selected.is_empty() else ''
 var dragged=selected if game.dragging else ''
 if game.dragging_blood>=0:dragged='core:'+str(game.dragging_blood)
 var sell_hover=false
 for button in [game.sell_button,game.hud_a.sell]:
  if is_instance_valid(button) and button.is_visible_in_tree() and button.get_global_rect().has_point(game.get_viewport().get_mouse_position()):sell_hover=true
 var offer=view.preview_offer_key if view.drag_preview!=Vector2.INF else ''
 if not game.pending_offer.is_empty():offer=game.pending_offer.get('key',offer)
 return {'cursor':cursor,'over_field':over,'hover_uid':hover,'clicked_uid':clicked_uid,'selected_uid':selected,'drag_uid':dragged,'rotating_uid':selected if game.rotating else '','sell_hover':sell_hover,'offer_key':offer,'zoom':view.scale.x,'speed':game.playback_speed,'staging':view.staging,'paused':game.paused or game.main_menu.visible}
