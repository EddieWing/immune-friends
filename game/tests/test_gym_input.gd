extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.save_path="user://test_gym_input.json"
 root.add_child(game)
 await process_frame
 game.set_process(false);game.modal.hide();game.main_menu.hide();game.entering_game=false;game.launch_remaining=0
 game.gym_mode=true
 for phase in ["shop","battle"]:
  game.sim.reset(42,12);game.sim.phase=phase;game.paused=true;game.pending_offer={}
  for kind in ["cell","virus"]:
   game.gym_tool={"kind":kind,"key":"basic"};game.view.drag_preview=Vector2.ZERO
   var right=InputEventMouseButton.new();right.button_index=MOUSE_BUTTON_RIGHT;right.pressed=true
   game._input(right)
   assert(game.gym_tool.is_empty() and game.view.drag_preview==Vector2.INF and not game.panning,"RMB cancels placement without pan")
  var cell=game.sim.make_cell("wall",Vector2(150,0));game.sim.cells=[cell]
  game.sim.spawn_virus({"type":"basic","lane":0,"p":Vector2(250,100)})
  for body in [cell,game.sim.viruses[0]]:
   var old=body.p
   var down=InputEventMouseButton.new();down.button_index=MOUSE_BUTTON_LEFT;down.pressed=true;down.position=game.view.to_global(old)
   game._unhandled_input(down)
   var move=InputEventMouseMotion.new();move.position=game.view.to_global(old+Vector2(30,25));game._unhandled_input(move)
   assert(body.p.distance_to(old+Vector2(30,25))<0.1,"Gym object moves in "+phase)
   down.pressed=false;game._input(down);game._unhandled_input(down)
   assert(game.dragging_virus.is_empty() and not game.dragging,"Release ends drag")
 game.sim.phase="battle";game.paused=false
 assert(not game.can_edit_field_objects(),"Running battle does not allow reposition")
 print("PASS Gym RMB cancellation, cell/virus dragging in preparation and paused battle")
 quit()
