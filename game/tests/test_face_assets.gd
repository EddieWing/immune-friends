extends SceneTree
var errors=0
func check(ok,label):
 print(('PASS: ' if ok else 'FAIL: ')+label)
 if not ok:errors+=1
func _initialize():
 var r=preload('res://atlas_integration/renderer.gd').new()
 var cells=r.face_set_for('core');var viruses=r.face_set_for('virus_basic')
 check(cells.poses==r.data.faces,'Cell poses preserve the approved geometry exactly')
 check(cells.poses.size()==18 and viruses.poses.size()==18,'Both families cover all 18 emotions')
 var valid=true
 for emotion in cells.poses:
  valid=valid and cells.poses[emotion].mouth==viruses.poses[emotion].mouth
  for key in ['eyes','brows']:
   for side in 2:
    var a=cells.poses[emotion][key][side];var b=viruses.poses[emotion][key][side]
    valid=valid and a.size()==b.size()
    for i in a.size():
     valid=valid and Vector2(b[i][0],b[i][1]).is_finite()
 check(valid,'Virus assets change only eye/brow proportions; mouths and morph topology stay intact')
 var ratio=0.174*viruses.eye_scale[0]/(0.221*viruses.eye_scale[1])
 check(absf(ratio-1.0)<0.02,'Virus open eye silhouette is round')
 var selected=true
 for id in r.data.characters:
  selected=selected and r.face_set_for(id).family==('viruses' if id.begins_with('virus_') else 'cells')
 check(viruses.eye_scale[0]<0.85 and viruses.eye_scale[1]<0.7,'Virus eyes are visibly smaller than cell eyes')
 check(viruses.poses.calm.eyes!=cells.poses.calm.eyes,'Virus resting expression uses distinct threatening lids')
 check(selected and r.face_set_for('zapper').family=='cells','Every character selects the correct family, including friendly Zapper')
 var blends=true
 for family in [cells,viruses]:
  r.face.poses=family.poses
  for emotion in family.poses:
   for step in 11:
    var weights={'calm':1.0-step/10.0};weights[emotion]=weights.get(emotion,0.0)+step/10.0
    for side in 2:
     for p in r.face.geometry(weights,'eyes',side):blends=blends and p.is_finite()
 check(blends,'Every expression blends continuously with finite matching geometry')
 quit(errors)
