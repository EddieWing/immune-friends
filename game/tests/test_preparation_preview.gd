extends SceneTree
var failures=0
func check(ok,label):
 print(('PASS: ' if ok else 'FAIL: ')+label)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var g=load('res://main.tscn').instantiate();g.save_path='user://test_prep_changes.json';root.add_child(g)
 await process_frame
 g.sim.reset(42,12);g.main_menu.hide();g.entering_game=false;g.modal.hide();g.ui_new=true
 g.set_zoom(3.5);check(is_equal_approx(g.camera_requested,3.0),'manual zoom clamps at x3')
 g.set_zoom(3.0);check(is_equal_approx(g.zoom_target,3.0),'manual zoom reaches x3')
 g.buy_offer(0,false);var cell=g.sim.cells[0];g.selected=cell;g.show_cell_card(cell.key,cell);g.hud_a.select_cell(cell.key,cell)
 g.hud_a.refresh_data();g.hud_a._process(0.1);check(g.hud_a.note.visible,'Incoming initially visible')
 g.hud_a.incoming_age=5;g.hud_a._process(0);check(not g.hud_a.note.visible and g.hud_a.incoming_tab.visible,'Incoming collapses to tab')
 check(g.hud_a.incoming_tab.text=='>' and g.hud_a.incoming_tab.size.x==30,'Collapsed Incoming uses only a narrow arrow')
 g.hud_a.incoming_tab.pressed.emit();g.hud_a._process(0);check(g.hud_a.note.visible,'Incoming can reopen')
 var offer=preload('res://scripts/ui/offer.gd').new();offer.game=g;offer.key=cell.key;root.add_child(offer);offer._process(0.1)
 check(not offer.atlas_state.is_empty() and offer.atlas_state.age>0,'shop preview uses animated field renderer')
 g.start_battle();g.hud_a._process(0.01)
 check(not g.detail_panel.visible and not g.hud_a.cell_block.visible and g.hud_a.cell_key=='','launch clears inspection without stale reopening')
 g.sim.phase='battle';g.sim.cells=[];g.sim.blood=[];g.sim.links=[];g.sim.blood_links=[];g.sim.viruses=[]
 var wall=g.sim.make_cell('wall',Vector2(700,0));g.sim.cells=[wall];g.sim.infection_sources=[wall.p];g.sim.physics.step(g.sim,1.0/60)
 check(wall.p.x>690,'source area has no invisible battle boundary')
 g.sim.phase='shop';g.sim.physics.step(g.sim,1.0/60);check(wall.p.x<620,'preparation bounds retained')
 print('Preparation checks failures: ',failures);quit(failures)
