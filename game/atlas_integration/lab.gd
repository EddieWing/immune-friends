extends Node2D
var renderer=preload('res://atlas_integration/renderer.gd').new()
var state
var character=OptionButton.new()
var action_picker=OptionButton.new()
var emotions=OptionButton.new()
var playing=true
var ids=[]
var modes=[]
var emotion_names=[]
var descriptions=Label.new()
func _ready():
 var background=ColorRect.new();background.z_index=-1;background.color=Color('#110a1c');background.size=Vector2(1440,900);background.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(background);move_child(background,0)
 var panel=HBoxContainer.new();panel.position=Vector2(30,28);panel.add_theme_constant_override('separation',14);add_child(panel)
 for control in [character,action_picker,emotions]:panel.add_child(control)
 for id in renderer.data.characters:ids.append(id);character.add_item(renderer.data.characters[id].name)
 for name in renderer.data.faces:emotion_names.append(name);emotions.add_item(name)
 var pause=Button.new();pause.text='Pause / Play';pause.pressed.connect(func():playing=not playing);panel.add_child(pause)
 var replay=Button.new();replay.text='Replay';replay.pressed.connect(func():state.age=0;renderer.emotion(state,emotion_names[emotions.selected]));panel.add_child(replay)
 character.item_selected.connect(select_character)
 action_picker.item_selected.connect(func(index):renderer.action(state,modes[index]);state.age=0)
 emotions.item_selected.connect(func(index):renderer.emotion(state,emotion_names[index]))
 descriptions.position=Vector2(30,80);add_child(descriptions)
 select_character(0)
func select_character(index):
 state=renderer.create(ids[index]);action_picker.clear();modes.clear()
 var spec=renderer.data.characters[state.id]
 for plan in spec.plans.values():action_picker.add_item(plan.title);modes.append(plan.mode)
 descriptions.text=spec.name+' — native Godot integration / '+str(spec.plans.size())+' actions / 18 expressions\nLarge + 24 / 32 / 48 / 72 px. Pointer controls continuous gaze. Test controls do not change gameplay.'
 emotions.select(0)
func _process(dt):
 if state==null:return
 if playing:renderer.advance(state,minf(dt,0.05),get_global_mouse_position()-Vector2(350,410))
 queue_redraw()
func _draw():
 if state==null:return
 renderer.draw(self,state,Vector2(350,410),280)
 var sizes=[24,32,48,72]
 for i in sizes.size():
  var p=Vector2(740+i*150,330)
  renderer.draw(self,state,p,sizes[i])
  draw_string(ThemeDB.fallback_font,p+Vector2(-20,80),str(sizes[i])+' px',HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color('#d2bddc'))
 draw_string(ThemeDB.fallback_font,Vector2(30,760),'Mode: '+state.mode+'  |  Emotion: '+state.emotion+'  |  Frame: '+str(int(state.age*12)%72),HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color('#d2bddc'))
