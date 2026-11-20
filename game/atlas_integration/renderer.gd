extends RefCounted
# Experimental presentation only. Never writes into simulation bodies or settings.
const ROOT='res://assets/atlas_integration/'
var data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+'manifest.json'))
var warp=preload('res://atlas_integration/body_warp.gd').new()
var face=preload('res://atlas_integration/face.gd').new()
var textures={}
var order=[]
const CACHE_LIMIT=24
func _init():face.poses=data.faces
func has_character(id):return data.characters.has(id)
func create(id):
 return {'id':id,'mode':'idle','age':0.0,'clock':0.0,'weights':{'calm':1.0},'look':Vector2.RIGHT,'emotion':'calm','reaction':'','reaction_age':0.0,'return_emotion':'calm','feed_age':99.0,'hit_age':99.0,'hit_direction':Vector2.RIGHT}
func action(state,mode):
 if mode not in data.characters[state.id].modes:mode='idle'
 if state.mode!=mode:state.mode=mode;state.age=0.0
func emotion(state,name):
 if not data.faces.has(name):return
 if name in ['kiss','wink','blush','raised_brow','astonished']:
  state.return_emotion=state.emotion;state.reaction=name;state.reaction_age=0.0
 else:state.emotion=name;state.reaction=''
func advance(state,dt,target=Vector2.RIGHT):
 state.age+=dt;state.clock+=dt;state.hit_age+=dt;state.feed_age+=dt
 # Interpolate direction on the circle: opposite vectors must not pass through zero.
 var wanted=target.angle() if target.length_squared()>0.001 else state.look.angle()
 state.look=Vector2.RIGHT.rotated(lerp_angle(state.look.angle(),wanted,1-exp(-12*dt)))
 advance_rotation(state,dt)
 var expression=state.emotion
 if state.reaction!='':
  state.reaction_age+=dt
  var durations={'kiss':1.2,'wink':0.8,'blush':4.2,'raised_brow':2.0,'astonished':2.0}
  if state.reaction_age>=durations[state.reaction]:state.reaction='';state.emotion=state.return_emotion
  else:expression=state.reaction
 if state.mode in ['hurt','death','healDeath','deathPush']:expression='hurt'
 if state.mode=='explode':expression='surprised' if state.age<0.55 else 'astonished'
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
func target_angle(state,angle):
 if state.id=='virus_wave' and state.mode in ['wave','waveImpact','move']:
  return angle+TAU*sin(float(state.get('wave_progress',state.clock*0.5))*PI)
 if state.id=='orbiter' and state.mode in ['orbit','turn','move']:
  var velocity=state.get('velocity',Vector2.ZERO)
  return velocity.angle()-PI if velocity.length()>0.1 else state.look.angle()-PI
 if state.id in ['virus_hungry','virus_jumper','virus_avoider','virus_seeker','seeker','tackle','virus_swarmer'] and state.mode not in ['idle','death','tagged']:
  return state.look.angle()
 return angle
func advance_rotation(state,dt):
 var angle=float(state.get('angle',0.0))
 var wave=state.id=='virus_wave' and state.mode in ['wave','waveImpact','move']
 var offset=TAU*sin(float(state.get('wave_progress',state.clock*0.5))*PI) if wave else 0.0
 var desired=angle if wave else target_angle(state,angle)
 if not state.has('body_angle'):
  state.turn_angle=desired;state.body_angle=desired+offset;state.turn_wave=wave
  return
 if state.mode in ['death','explode','healDeath','deathPush']:return
 # Keep Wave's continuous full revolutions; only smooth its underlying heading.
 if state.turn_wave!=wave:state.turn_angle=state.body_angle-offset
 var error=wrapf(desired-state.turn_angle,-PI,PI)
 state.turn_angle+=clampf(error*(1-exp(-10*dt)),-8*dt,8*dt)
 state.body_angle=state.turn_angle+offset;state.turn_wave=wave
func visual_angle(state,angle):
 return float(state.body_angle) if state.has('body_angle') else target_angle(state,angle)
func resting_scale(state):
 # Low-amplitude continuous motion stays readable below a sprite-sheet pixel.
 # Approved clips remain unchanged; no idle pulse is added during an action.
 if not state.get('preparing',false) or state.mode not in ['idle','coreIdle','passive']:return 1.0
 if state.mode in data.characters[state.id].get('protected_modes',[]):return 1.0
 return 1.0+0.022*sin(state.clock*1.8+float(state.get('idle_phase',0.0)))
func draw(canvas,state,position,body_width,angle=0.0,alpha=1.0):
 if not has_character(state.id):return
 body_width*=resting_scale(state)
 var spec=data.characters[state.id]
 var protected=state.mode in spec.get('protected_modes',[])
 var mode='idle' if state.mode=='hurt' and not protected else state.mode
 var accumulated=state.id=='hungry_bomb' and state.mode in ['idle','feed','reset']
 if accumulated:mode='feed'
 var texture=texture_for(state.id,mode)
 if texture==null:return
 var frame_age=state.age
 if state.get('preparing',false) and state.mode not in ['placement','merge','hurt','death','explode','healDeath','deathPush']:
  frame_age=state.clock*state.get('idle_speed',1.0)+state.get('idle_phase',0.0)*6.0/TAU
 var index=mini(int(state.age*data.fps),int(data.frames)-1) if state.mode in ['death','explode','healDeath','deathPush'] else int(frame_age*data.fps)%int(data.frames)
 if accumulated:
  var amount=float(state.get('fill_fraction',0.0))
  if state.mode=='reset':amount=float(state.get('reset_fill',0.0))*(1-smoothstep(0,1.4,state.age))
  index=clampi(int(amount*1.8*data.fps),0,int(data.frames)-1)
 var tile=texture.get_width()/8.0
 var extent=body_width*128.0/88.0
 var rotation=visual_angle(state,angle)
 canvas.draw_set_transform(position,rotation)
 if state.hit_age<0.6 and not protected and state.mode not in ['death','explode','healDeath','deathPush']:
  warp.draw(canvas,texture,extent,index,state.hit_direction.rotated(-rotation),state.hit_age,alpha)
 else:
  canvas.draw_texture_rect_region(texture,Rect2(Vector2.ONE*(-extent/2),Vector2.ONE*extent),Rect2(Vector2(index%8,int(index/8))*tile,Vector2.ONE*tile),Color(1,1,1,alpha))
 canvas.draw_set_transform(Vector2.ZERO)
 if state.feed_age<0.4 and state.has('feed_from'):
  var direction=Vector2.RIGHT.rotated(rotation);var lumen=position+direction*body_width*0.27
  var u=smoothstep(0.0,0.4,state.feed_age)
  canvas.draw_circle(state.feed_from.lerp(lumen,u),maxf(1.0,body_width*0.04)*(1-smoothstep(0.75,1.0,u)),Color('#f5d273'))
 var layout=spec.get('protected_face',spec.face) if protected else spec.face
 var frames=spec.get('frame_faces',{}).get(mode,[])
 if not frames.is_empty():layout=frames[index]
 var face_anchor=Vector2(layout[0],layout[1])*body_width/spec.width
 var opacity=alpha*(float(layout[3]) if layout.size()>3 else 1.0)
 face.opacity=opacity;face.show_angry_brows=state.id=='orbiter'
 if opacity>0.01:face.draw(canvas,position+face_anchor.rotated(rotation),layout[2]*body_width/spec.width,state.weights,state.look,state.clock,spec.no_mouth)
 face.opacity=1.0

func bottom_extent(state,width):
 var spec=data.characters[state.id]
 var angle=visual_angle(state,state.get('angle',0.0))
 var result=0.0
 for point in spec.body_bounds:
  result=maxf(result,(Vector2(point[0],point[1])*width*resting_scale(state)/spec.width).rotated(angle).y)
 return result
