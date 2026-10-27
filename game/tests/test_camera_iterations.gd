extends SceneTree
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func _initialize():call_deferred("run")
func run():
 var optics=preload("res://scripts/camera_optics.gd").new()
 check(optics.update_focus(Vector2.ZERO,1.5,true,false),"051: near + close opens purchase focus")
 check(optics.update_focus(Vector2.ZERO,1.32,true,false),"051: zoom hysteresis prevents flicker")
 check(not optics.update_focus(Vector2.ZERO,1.2,true,false),"051: zoom out closes purchase focus")
 check(not optics.update_focus(Vector2(400,0),1.5,true,false),"051: leaving start area closes purchase focus")
 check(optics.update_focus(Vector2(400,0),0.5,true,true),"051: pending placement pins purchase focus")
 check(not optics.update_focus(Vector2.ZERO,1.5,false,true),"051: placement cannot open focus in inactive phase")
 optics.update_optics(1,0.1,1,true)
 check(optics.update_optics(1.5,0.01,1,true)>0,"053: actual zoom change triggers refocus")
 check(optics.update_optics(1.5,1,1,true)==0,"053: unchanged zoom settles exactly")
 for i in range(100):optics.update_optics(0.5 if i%2 else 1.5,0.01,1,true)
 check(optics.refocus<=1,"053: rapid reversal is bounded")
 check(optics.update_optics(1,0.01,0,true)==0 and optics.refocus==0,"053: zero intensity clears residue")
 check(optics.update_optics(1.5,0.01,1,false)==0,"053: menu disables refocus")
 var sim=preload("res://scripts/simulation.gd").new()
 sim.reset(42,12)
 var feedback=preload("res://scripts/core_feedback.gd").new()
 feedback.update(sim,0.01)
 for i in range(20):sim.record("camera_blast",{})
 feedback.update(sim,0.01)
 check(is_equal_approx(feedback.shake,0.8),"052: same-step impacts use max, not sum")
 var snapshot=var_to_bytes([sim.cells,sim.blood,sim.viruses,sim.rng.state,sim.elapsed])
 var offset=feedback.offset()
 feedback.update(sim,0)
 check(feedback.offset()==offset,"052: pause freezes impact clock")
 check(snapshot==var_to_bytes([sim.cells,sim.blood,sim.viruses,sim.rng.state,sim.elapsed]),"052: feedback leaves full gameplay state unchanged")
 var rng=sim.rng.state
 feedback.update(sim,2)
 check(feedback.offset()==Vector2.ZERO and sim.rng.state==rng,"052: no residual offset or simulation RNG use")
 var game=load("res://main.tscn").instantiate()
 game.save_path="user://camera-iterations-test.json"
 game.settings_path="user://camera-iterations-test.cfg"
 root.add_child(game)
 await process_frame
 game.set_process(false)
 game.main_menu.hide();game.modal.hide();game.menu_open=false;game.entering_game=false
 game.sim.reset(42,12)
 game.auto_camera=false
 game.view.position=Vector2(400,300)
 game.view.scale=Vector2.ONE*1.5
 game.zoom_target=1.5
 var original_focus=(game.board_rect.get_center()-game.view.position)/1.5
 game.set_automatic_zoom(0)
 for i in range(120):game.advance_camera(1.0/60)
 check(game.overview and game.view.position.distance_to(game.board_rect.get_center())<0.1,"049: Wide centers fixed field origin")
 game.set_automatic_zoom(2)
 for i in range(120):game.advance_camera(1.0/60)
 check(((game.board_rect.get_center()-game.view.position)/game.view.scale.x).distance_to(original_focus)<0.1,"049: Close restores saved focus")
 game.set_automatic_zoom(0)
 game.advance_manual_camera(0.1,Vector2.LEFT)
 check(not game.overview and not game.auto_camera,"049: WASD releases overview")
 game.set_automatic_zoom(0)
 game.begin_camera_pan(Vector2(700,400))
 check(not game.overview and game.panning,"049: RMB releases overview")
 game.panning=false
 game.set_zoom(1.123)
 check(game.zoom_target==1.123,"049: manual zoom remains continuous")
 game.focus_shopping()
 for i in range(120):game.advance_camera(1.0/60)
 check(game.shopping_in_focus(),"051: Focus cells restores shop access")
 game.hud_a._process(0.5)
 check(game.hud_a.shelf.visible and game.hud_a.release.visible,"051: shop and Play accessible near focus")
 game.view.position+=Vector2(2000,0)
 game.advance_camera(1)
 game.hud_a._process(0.5)
 check(not game.hud_a.shelf.visible and game.hud_a.release.visible,"051: distant shop hidden but Play remains available")
 game.start_battle()
 check(game.zoom_target==0.88 and game.auto_camera,"050: launch selects Medium and Auto")
 game.sim.phase="recap"
 game.advance_camera(0.01)
 var held=game.view.position
 game.advance_camera(1)
 check(game.view.position.is_equal_approx(held),"050: result keeps final focus")
 game.sim.phase="shop"
 game.center_preparation_camera()
 game.advance_manual_camera(0.2,Vector2.RIGHT)
 held=game.view.position
 game.advance_camera(0.5)
 check(game.view.position==held and not game.auto_camera,"050: preparation releases after one centering")
 game.optical_intensity=1.0
 game.refocus_intensity=0.0
 game.set_zoom(1.45)
 game.advance_camera(0.01)
 check(not game.refocus_layer.visible,"053: comfort zero bypasses the screen pass")
 game.show_visual_comfort()
 var slider=game.modal_panel.find_child("Comfort_refocus",true,false)
 slider.value=0.3
 check(is_equal_approx(game.refocus_intensity,0.3) and is_equal_approx(float(game.settings.get_value("comfort","refocus")),0.3),"053: dedicated comfort control persists")
 game.main_menu.show()
 var zoom_before=game.zoom_target
 check(not game.set_automatic_zoom(0) and game.zoom_target==zoom_before,"049: presets cannot change main-menu zoom")
 check(game.refocus_layer.get_index()<game.ui.get_node("MicroscopeVignette").get_index(),"053: optical pass stays below visor and HUD")
 quit(failures)
