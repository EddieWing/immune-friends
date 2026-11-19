extends SceneTree
var failures=0
func check(ok,message):
 print(('PASS: ' if ok else 'FAIL: ')+message)
 if not ok:failures+=1
func _initialize():call_deferred('run')
func run():
 var render=preload('res://atlas_integration/renderer.gd').new()
 check(render.data.characters.size()==50,'all 50 atlas characters exported')
 check(render.data.faces.size()==18,'all 18 emotion geometries exported')
 var plans=0
 var all_files=true
 for id in render.data.characters:
  var spec=render.data.characters[id]
  plans+=spec.plans.size()
  for plan in spec.plans.values():
   if not FileAccess.file_exists(render.ROOT+id+'--'+plan.mode+'.png'):all_files=false
 check(plans==432,'all 432 catalogue animation entries mapped')
 check(all_files,'every animation mapping resolves to an exported clip')
 var s=preload('res://scripts/simulation.gd').new();s.reset(42,12)
 var all_types=true
 for id in s.catalog:
  if not render.has_character(id):print('Missing catalogue key: '+id);all_types=false
 check(all_types,'every game cell type has a rig')
 var p=preload('res://atlas_integration/presentation.gd').new()
 var c=s.make_cell('wall',Vector2(100,0));s.cells.append(c)
 p.update(s,0.016)
 var snapshot=var_to_str([s.cells,s.blood,s.links,s.money,s.event_sequence])
 p.update(s,0.1)
 check(snapshot==var_to_str([s.cells,s.blood,s.links,s.money,s.event_sequence]),'presentation leaves gameplay bodies, links, economy and events unchanged')
 s.record('pushed',{'id':c.id,'p':c.p,'from':c.p+Vector2.LEFT*10})
 p.update(s,0.016)
 check(p.states['cell:'+str(c.id)].mode!='hurt','contact without HP damage does not trigger Hurt')
 check(p.states['cell:'+str(c.id)].hit_direction==Vector2.LEFT,'impact preserves real source direction')
 s.record('damage',{'id':c.id,'p':c.p,'amount':1})
 p.update(s,0.016)
 check(p.states['cell:'+str(c.id)].mode=='hurt','real damage starts hurt')
 c.alive=false;s.record('cell_rest',{'id':c.id,'p':c.p})
 p.update(s,0.016)
 var state=p.states['cell:'+str(c.id)]
 check(state.dead and state.mode=='death','dead object retained for presentation only')
 render.advance(state,0.2)
 check(state.weights.hurt>0.8,'death always uses Hurt')
 var a=render.create('virus_basic');render.emotion(a,'angry');render.advance(a,0.4)
 render.emotion(a,'wink');render.advance(a,0.2)
 check(a.reaction=='wink','reaction starts')
 render.advance(a,0.8);render.advance(a,0.4)
 check(a.reaction=='' and a.emotion=='angry' and a.weights.angry>0.9,'reaction returns smoothly to previous state')
 var old_age=a.age;render.advance(a,0)
 check(a.age==old_age,'pause does not advance animation')
 var finite=true
 for name in render.data.faces:
  for key in ['eyes','brows']:
   for side in 2:
    for point in render.face.geometry({name:1.0},key,side):
     if not is_finite(point.x) or not is_finite(point.y):finite=false
 check(finite,'all face contours remain finite at emotion extremes')
 var triangulates=true
 for name in render.data.faces:
  for other in render.data.faces:
   for step in range(1,10):
    for side in 2:
     var poly=render.face.clean_polygon(render.face.geometry({name:step/10.0,other:1-step/10.0},'eyes',side))
     if absf(render.face.area(poly))>0.00001 and Geometry2D.triangulate_polygon(poly).is_empty():triangulates=false
 check(triangulates,'all eye transitions triangulate without duplicated seam vertices')
 for reaction in ['raised_brow','astonished']:
  var reaction_state=render.create('virus_basic');render.emotion(reaction_state,'angry');render.emotion(reaction_state,reaction)
  render.advance(reaction_state,1.5)
  check(reaction_state.reaction==reaction,reaction+' persists beyond one second')
  render.advance(reaction_state,0.6)
  check(reaction_state.reaction=='' and reaction_state.emotion=='angry',reaction+' returns after two seconds')
 var bomb=render.create('bomb');render.action(bomb,'explode');render.advance(bomb,0.4)
 check(bomb.weights.surprised>0.9 and bomb.weights.hurt<0.01,'bomb death starts surprised without Hurt')
 render.advance(bomb,0.3)
 check(bomb.weights.astonished>0.9,'bomb death expands into astonished')
 var wave=render.create('virus_wave');wave.mode='wave';wave.wave_progress=0.5
 check(is_equal_approx(render.visual_angle(wave,0),TAU),'Wave completes a full forward body rotation')
 wave.wave_progress=1.5
 check(is_equal_approx(render.visual_angle(wave,0),-TAU),'Wave reverses full body rotation')
 var links=preload('res://atlas_integration/connections.gd').new(render)
 links.links={'ab':{'ka':'cell:1','kb':'cell:2','release':0,'kind':'immune'},'bc':{'ka':'cell:2','kb':'cell:3','release':0,'kind':'immune'}}
 links.heal('cell:1','cell:3')
 check(links.transfers.size()==1 and links.transfers[0].path.size()==2,'heal swelling follows two existing bonds')
 links.heal('cell:1','cell:99')
 check(links.transfers.size()==1,'no heal path fabricated to disconnected target')
 var hungry=s.make_cell('hungry_bomb',Vector2(200,0));hungry.radius_growth=3.0;s.cells.append(hungry)
 p.update(s,0.016)
 var hungry_state=p.states['cell:'+str(hungry.id)]
 check(hungry_state.fill_fraction>0,'Hungry Bomb displays actual accumulated radius')
 hungry.radius_growth=0.0;s.presentation_revision+=1
 p.update(s,0.016)
 hungry_state=p.states['cell:'+str(hungry.id)]
 check(hungry_state.mode=='reset' and hungry_state.reset_fill>0 and hungry_state.fill_fraction==0,'real battle reset retains previous visual fill for transition')
 print('Atlas integration failures: '+str(failures));quit(failures)
