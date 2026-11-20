extends TextureRect
var game
var character_key=""
var state={}
func _process(delta):
 if not is_visible_in_tree() or game==null or character_key=="":return
 var renderer=game.view.atlas.renderer
 if state.is_empty() or state.id!=character_key:
  state=renderer.create(character_key)
  state.preparing=true
  renderer.action(state,game.view.atlas.rest_mode(state,{},false,"shop"))
 renderer.advance(state,delta)
 queue_redraw()
func _draw():
 if game==null or state.is_empty():return
 game.view.atlas.renderer.draw(self,state,size*0.5,minf(size.x,size.y)*0.68)
