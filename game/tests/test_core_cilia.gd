extends SceneTree
func _initialize():
 var drawing=load("res://scripts/core_cilia.gd").new()
 var blood=[{"id":3,"p":Vector2(10,20),"alive":true},{"id":9,"p":Vector2(-30,40),"alive":true}]
 var strength={3:0.25,9:0.75};var original=blood.duplicate(true)
 drawing.prepare(blood,strength)
 assert(drawing.batch.visible_instance_count==2)
 # The headless dummy renderer discards instance transforms/custom data.
 # Exercise readback separately in the browser's actual GL renderer.
 var gpu=DisplayServer.get_name()!="headless"
 if gpu:
  assert(drawing.batch.get_instance_transform_2d(0).origin==blood[0].p)
  assert(drawing.batch.get_instance_custom_data(1)==Color(9,0.75,0,0))
 var mesh=drawing.batch.mesh
 blood[0].alive=false;drawing.prepare(blood,strength)
 assert(drawing.batch.visible_instance_count==1)
 if gpu:assert(drawing.batch.get_instance_transform_2d(0).origin==blood[1].p)
 blood[1].alive=false;drawing.prepare(blood,strength)
 assert(drawing.batch.visible_instance_count==0)
 drawing.prepare(original,{})
 assert(drawing.batch.visible_instance_count==2 and drawing.batch.mesh==mesh)
 if gpu:assert(drawing.batch.get_instance_custom_data(0)==Color(3,0,0,0))
 var saved=original.duplicate(true);drawing.prepare(original,strength)
 assert(original==saved and strength=={3:0.25,9:0.75})
 if gpu:assert(mesh.get_aabb().has_point(Vector3(13.5,0,0)))
 drawing.prepare([],{})
 assert(drawing.batch.visible_instance_count==0)
 print("PASS: ",11 if gpu else 6," Core cilia checks: death, empty, restore, immutable simulation; GPU transforms/strength/bounds=",gpu)
 quit()
