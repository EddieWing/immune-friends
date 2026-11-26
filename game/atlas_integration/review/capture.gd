extends SceneTree
class Sample extends Node2D:
 var renderer=preload('res://atlas_integration/renderer.gd').new()
 var family='cells'
 var emotion='calm'
 func _draw():
  draw_rect(Rect2(0,0,320,250),Color('#100a19'))
  var profile=renderer.face_sets[family]
  renderer.face.poses=profile.poses
  renderer.face.eye_scale=Vector2(profile.eye_scale[0],profile.eye_scale[1])
  renderer.face.draw(self,Vector2(160,70),150,{emotion:1.0},Vector2(0.7,-0.2),0.0)
  for i in 3:
   var s=renderer.create('core' if family=='cells' else 'virus_basic')
   s.weights={emotion:1.0};s.look=Vector2(0.7,-0.2)
   renderer.draw(self,s,Vector2(70+i*90,210),[24,30,32][i])
func _initialize():call_deferred('run')
func run():
 var vp=SubViewport.new();vp.size=Vector2i(320,250);vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(vp)
 var sample=Sample.new();vp.add_child(sample)
 for family in ['cells','viruses']:
  for emotion in sample.renderer.face_sets[family].poses:
   sample.family=family;sample.emotion=emotion;sample.queue_redraw()
   await process_frame
   await RenderingServer.frame_post_draw
   vp.get_texture().get_image().save_png('res://atlas_integration/review/'+family+'-'+emotion+'.png')
 quit()
