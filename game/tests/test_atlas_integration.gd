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
 print('Atlas integration failures: '+str(failures));quit(failures)
