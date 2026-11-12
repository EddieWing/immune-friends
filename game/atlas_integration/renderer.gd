extends RefCounted
# Experimental presentation only. Never writes into simulation bodies or settings.
const ROOT='res://assets/atlas_integration/'
var data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+'manifest.json'))
var face=preload('res://atlas_integration/face.gd').new()
var textures={}
var order=[]
const CACHE_LIMIT=24
func _init():face.poses=data.faces
func has_character(id):return data.characters.has(id)
func create(id):
 return {'id':id,'mode':'idle','age':0.0,'clock':0.0,'weights':{'calm':1.0},'look':Vector2.RIGHT,'emotion':'calm','reaction':'','reaction_age':0.0,'return_emotion':'calm'}
func action(state,mode):
 if mode not in data.characters[state.id].modes:mode='idle'
 if state.mode!=mode:state.mode=mode;state.age=0.0
func emotion(state,name):
 if not data.faces.has(name):return
 if name in ['kiss','wink','blush','raised_brow','astonished']:
  state.return_emotion=state.emotion;state.reaction=name;state.reaction_age=0.0
 else:state.emotion=name;state.reaction=''
func advance(state,dt,target=Vector2.RIGHT):
 state.age+=dt;state.clock+=dt
 state.look=state.look.lerp(target.normalized() if target.length_squared()>0.001 else state.look,1-exp(-12*dt))
 var expression=state.emotion
 if state.reaction!='':
  state.reaction_age+=dt
  var durations={'kiss':1.2,'wink':0.8,'blush':4.2,'raised_brow':1.0,'astonished':1.0}
  if state.reaction_age>=durations[state.reaction]:state.reaction='';state.emotion=state.return_emotion
  else:expression=state.reaction
 if state.mode in ['hurt','death','explode','healDeath','deathPush']:expression='hurt'
 var speed=3.0 if expression=='blush' else 16.0
 for name in data.faces:state.weights[name]=lerpf(float(state.weights.get(name,0)),1.0 if name==expression else 0.0,1-exp(-speed*dt))
func texture_for(id,mode):
 var key=id+'--'+mode
 if textures.has(key):order.erase(key);order.append(key);return textures[key]
 var filename=ROOT+key+'.png'
 if not ResourceLoader.exists(filename):return null
 var texture=load(filename)
 textures[key]=texture;order.append(key)
 if order.size()>CACHE_LIMIT:textures.erase(order.pop_front())
 return texture
func draw(canvas,state,position,body_width,angle=0.0,alpha=1.0):
 if not has_character(state.id):return
 var spec=data.characters[state.id]
 var texture=texture_for(state.id,state.mode)
 if texture==null:return
 var index=mini(int(state.age*data.fps),int(data.frames)-1) if state.mode in ['death','explode','healDeath','deathPush'] else int(state.age*data.fps)%int(data.frames)
 var extent=body_width*128.0/88.0
 canvas.draw_set_transform(position,angle)
 canvas.draw_texture_rect_region(texture,Rect2(Vector2.ONE*(-extent/2),Vector2.ONE*extent),Rect2(Vector2(index%8,index/8)*128,Vector2.ONE*128),Color(1,1,1,alpha))
 canvas.draw_set_transform(Vector2.ZERO)
 var face_anchor=Vector2(spec.face[0],spec.face[1])*body_width/spec.width
 # Position follows body orientation; feature proportions remain independent.
 if alpha>0.08:face.draw(canvas,position+face_anchor.rotated(angle),spec.face[2]*body_width/spec.width,state.weights,state.look,state.clock,spec.no_mouth)
