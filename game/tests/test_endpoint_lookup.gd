extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Old=preload("res://tests/fixtures/legacy_endpoint_lookup.gd")
var failures=0
func check(ok,message):
 print(("PASS: " if ok else "FAIL: ")+message)
 if not ok:failures+=1
func _initialize():
 var s=Sim.new();s.reset(42,12)
 var old=Old.new()
 s.cells=[{"id":1,"alive":false,"label":"first"},{"id":1,"alive":true,"label":"duplicate"},{"id":2,"alive":true}]
 s.viruses=[{"id":1,"alive":true,"label":"virus collision"},{"id":3,"alive":true},{"id":3,"alive":true,"label":"duplicate"}]
 s.blood=[{"id":0,"alive":false},{"id":0,"alive":true},{"id":1,"alive":true}]
 old.cells=s.cells;old.viruses=s.viruses;old.blood=s.blood
 s.step_lookups_active=true
 for id in [-100,-3,-2,-1,0,1,2,3,100,1.0,-2.0]:
  check(s.cell_by_id(id)==old.cell_by_id(id) and s.endpoint_by_id(id)==old.endpoint_by_id(id),"Same lookup / priority for ID "+str(id))
 s.cells[0].alive=true;s.cells[0].label="changed"
 check(s.endpoint_by_id(1).label=="changed","Index retains live object reference")
 s.cells.append({"id":4,"alive":true});s.viruses.append({"id":5,"alive":true});s.blood.append({"id":2,"alive":true})
 check(s.cell_by_id(4)==s.cells.back() and s.endpoint_by_id(5)==s.viruses.back() and s.endpoint_by_id(-4)==s.blood.back(),"Growth refreshes all endpoint groups")
 s.cells.remove_at(0);s.viruses.remove_at(1);s.blood.remove_at(0)
 check(s.cell_by_id(1).label=="duplicate" and s.endpoint_by_id(3).label=="duplicate" and s.endpoint_by_id(-2).alive,"Removal reveals next match")
 s.step_lookups_active=false
 s.cells[0]={"id":99,"alive":true}
 check(s.cell_by_id(1).is_empty() and s.cell_by_id(99)==s.cells[0],"Outside update same-size edits are immediate")
 s.cells=[{"id":1.0,"alive":true,"label":"JSON float"},{"id":1,"alive":true,"label":"later int"},{"id":2.5,"alive":true}]
 s.viruses=[{"id":2.0,"alive":true},{"id":2,"alive":true,"label":"later int"}]
 old.cells=s.cells;old.viruses=s.viruses
 s.lookup_sizes=Vector3i(-1,-1,-1);s.step_lookups_active=true
 for id in [1,2,1.0,2.0,2.5]:
  check(s.cell_by_id(id)==old.cell_by_id(id) and s.endpoint_by_id(id)==old.endpoint_by_id(id),"Loaded numeric ID "+str(id))
 for phase in ["shop","recap","win","lose"]:
  var empty=Sim.new();empty.reset(42,12);empty.phase=phase;empty.update(0)
  check(not empty.step_lookups_active and empty.cell_lookup.is_empty(),"Cache released after "+phase)
 var result=preload("res://tests/fixtures/endpoint_comparison.gd").new().run()
 print(result);check(result.passed,"Complete state equality across 240 ticks")
 quit(1 if failures else 0)
