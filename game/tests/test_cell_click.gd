extends SceneTree
func _initialize():call_deferred("run")
func run():
 var game=load("res://main.tscn").instantiate()
 game.save_path="user://test_click_only.json"
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.modal.hide();game.main_menu.hide();game.entering_game=false;game.launch_remaining=0
 game.sim.reset(42,12)
 var cell=game.sim.make_cell("seeker",Vector2.ZERO)
 game.sim.cells=[cell]
 for modern in [false,true]:
  game.ui_new=modern
  for gym in [false,true]:
   game.gym_mode=gym
   game.gym_tool={}
   game.pending_offer={}
   var event=InputEventMouseButton.new()
   event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
   event.position=game.view.to_global(cell.p)
   game._unhandled_input(event)
   assert(game.selected==cell and game.inspected_cell==-1,"Single click selects only")
   event.pressed=false;game._unhandled_input(event)
   event.pressed=true;event.double_click=true;game._unhandled_input(event)
   assert(game.inspected_cell==cell.id,"Double click inspects")
 print("PASS single/double click in both HUDs and Gym")
 quit()
