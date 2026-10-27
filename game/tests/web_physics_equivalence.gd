# Browser-only regression scene. Run from a disposable Web test export; excluded from the production preset.
extends Node
func _ready():
 if not OS.has_feature("web"):
  push_error("Export this test scene to Web: the oracle must use the same WebAssembly math library.")
  get_tree().quit(1);return
 var s=load("res://scripts/simulation.gd").new()
 var physics=load("res://tests/legacy_body_solver.gd").new()
 var rng=RandomNumberGenerator.new();rng.seed=91377
 var cases=[]
 for sample in range(1000):
  s.reset(sample,12);physics.clear();s.cells.clear();s.blood.clear();s.viruses.clear();s.links.clear()
  if sample>=300:
   s.rules.body_physics.motor_response=rng.randf_range(0,30)
   s.rules.body_physics.motor_force=rng.randf_range(0,1300)
   s.rules.body_physics.linear_damping=rng.randf_range(0,5)
   s.rules.body_physics.angular_damping=rng.randf_range(0,5)
   s.rules.body_physics.restitution=rng.randf_range(0,1)
   s.rules.body_physics.spring_stiffness=rng.randf_range(5,200)
   s.rules.body_physics.spring_damping=rng.randf_range(0,30)
   s.rules.body_physics.contact_impulse_scale=rng.randf_range(.3,2)
   s.tuning["wall"]={"physics/density":rng.randf_range(.01,10)}
  var bodies=[];var rows=[]
  for i in range(4+sample%27):
   var body={"id":i,"p":Vector2(rng.randf_range(-640,640) if sample>=600 else rng.randf_range(-100,100),rng.randf_range(-390,390) if sample>=600 else rng.randf_range(-100,100)),"alive":true}
   if i%3==0:
    body=s.make_cell("wall" if i%2==0 else "turret",body.p);body.id=i;body.angle=rng.randf_range(-PI,PI);s.cells.append(body)
   elif i%3==1:
    body.type="basic";s.viruses.append(body)
   else:s.blood.append(body)
   body.jump=i%19==0;body.emerging=i%23==0;body.freeze=1 if i%11==0 else 0;body.host=0 if i%13==0 else -1
   var st=physics.state(body);st.v=Vector2(rng.randf_range(-250,250),rng.randf_range(-250,250));st.w=rng.randf_range(-8,8)
   if i%3==2:s.blood_velocity[s.blood.size()-1]=st.v
   physics.drive(body,Vector2(rng.randf_range(-60,60),rng.randf_range(-60,60)))
  bodies=s.cells+s.viruses+s.blood
  for body in bodies:
   var st=physics.state(body);var axis=Vector2.RIGHT.rotated(float(body.get("angle",0))) if physics.is_box(s,body) else Vector2.RIGHT
   var target=physics.drives[physics.id_of(body)]
   rows.append([body.p.x,body.p.y,st.v.x,st.v.y,st.w,physics.radius(body),physics.is_box(s,body),body.has("key"),body.has("type"),1.0/physics.mass(s,body),1.0/physics.inertia(s,body),physics.parameter(s,body,"restitution"),physics.id_of(body),axis.x,axis.y,not body.jump and not body.emerging,float(body.get("angle",0)),target.x,target.y,body.emerging,body.freeze>0 or body.host>=0,physics.parameter(s,body,"motor_response"),physics.parameter(s,body,"motor_force"),physics.mass(s,body),physics.parameter(s,body,"linear_damping"),physics.parameter(s,body,"angular_damping"),physics.parameter(s,body,"max_speed"),physics.parameter(s,body,"max_angular_speed"),physics.inertia(s,body),exp(-physics.parameter(s,body,"linear_damping")*(1.0/60.0/maxi(1,ceili((1.0/60.0)/float(s.rules.body_physics.max_step))))),exp(-physics.parameter(s,body,"angular_damping")*(1.0/60.0/maxi(1,ceili((1.0/60.0)/float(s.rules.body_physics.max_step)))))])
  var test_links=[]
  for i in range(s.cells.size()-1):
   if sample%2==0:
    s.links.append({"a":s.cells[i].id,"b":s.cells[i+1].id,"rest":rng.randf_range(30,110)})
    test_links.append([i,i+1,s.links.back().rest])
  var delta=1.0/60.0;var steps=maxi(1,ceili(delta/float(s.rules.body_physics.max_step)))
  physics.step(s,delta)
  var result=[]
  for body in bodies:
   var st=physics.state(body);result.append_array([body.p.x,body.p.y,st.v.x,st.v.y,st.w,body.get("angle",0)])
  for pair in physics.contacts:result.append_array([pair.x,pair.y])
  var flat=PackedFloat64Array()
  for row in rows:
   for value in row:flat.append(float(value))
  var buffer=s.physics.web_kernel.advanceBinary(Marshalls.raw_to_base64(flat.to_byte_array()),JSON.stringify([delta,steps,s.rules.body_physics.contact_impulse_scale,s.rules.body_physics.spring_stiffness,s.rules.body_physics.spring_damping],"",true,true),JSON.stringify(test_links,"",true,true))
  var actual=JavaScriptBridge.js_buffer_to_packed_byte_array(buffer).to_float64_array()
  if actual.size()!=result.size():print("RANDOM_WEB_FAIL count ",sample);return
  for i in range(result.size()):
   if actual[i]!=float(result[i]):print("RANDOM_WEB_FAIL sample=",sample," column=",i," actual=",actual[i]," expected=",result[i]);return
  if sample%20==19:await get_tree().process_frame
 print("RANDOM_WEB_PASS 1000 randomized physics fixtures, exact values")
