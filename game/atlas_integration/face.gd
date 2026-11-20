extends RefCounted
# Face geometry is sampled from the approved Canvas rig; pupils remain live.
var poses={}
var opacity=1.0
var show_angry_brows=false
var blink=0.0
const INK=Color('#573b31')
const WHITE=Color('#fff2d6')
func geometry(weights,key,side=-1):
 var result=PackedVector2Array()
 for name in weights:
  var weight=float(weights[name])
  if weight<0.0001 or not poses.has(name):continue
  var points=poses[name][key] if side<0 else poses[name][key][side]
  if result.is_empty():result.resize(points.size())
  for i in points.size():result[i]+=Vector2(points[i][0],points[i][1])*weight
 return result
func ellipse(center,radii,count=32):
 var result=PackedVector2Array()
 for i in count:result.append(center+Vector2(cos(i*TAU/count),sin(i*TAU/count))*radii)
 return result
func stroke(canvas,points,width,color=INK,closed=false):
 if points.size()<2:return
 var line=points.duplicate()
 if closed:line.append(line[0])
 canvas.draw_polyline(line,Color(color,color.a*opacity),width,true)
func draw(canvas,position,width,weights,look,time,no_mouth=false):
 var line=maxf(0.55,width*0.020)
 var angry=float(weights.get('angry',0))
 var spiral=float(weights.get('spiral',0))
 var hurt=float(weights.get('hurt',0))
 var cry=float(weights.get('cry',0))
 for side_index in 2:
  var side=-1 if side_index==0 else 1
  var origin=position+Vector2(side*0.215,-0.025 if side==1 else 0)*width
  var eye=clean_polygon(geometry(weights,'eyes',side_index))
  for i in eye.size():eye[i].y=lerpf(eye[i].y,0.025,blink)
  var local_eye=eye.duplicate()
  for i in eye.size():eye[i]=origin+eye[i]*width
  if spiral<0.999:
   var white=WHITE;white.a=1-spiral
   # Collapsed eyes are lines; do not triangulate a zero-area polygon.
   if absf(area(eye))>0.01:
    fill(canvas,eye,white)
    var gx=look.x*0.174*0.48
    var ey=0.221*sqrt(maxf(0,1-pow(gx/0.174,2)))
    var top=maxf(-ey,-side*angry*0.32*gx+lerpf(-0.221*1.2,-0.221*0.42,angry))
    var gy=lerpf(look.y*0.221*0.43,(top+ey)*0.5+look.y*(ey-top)*0.36,smoothstep(0,1,angry))
    var gaze=Vector2(gx,gy)
    for iteration in 16:
     var fits=true
     for j in 24:
      var q=gaze/Vector2(0.174,0.221)+Vector2(cos(j*TAU/24)*0.47,sin(j*TAU/24)*0.61)
      if q.length_squared()>0.86*0.86:fits=false;break
     if fits:break
     gaze*=0.9
    var pupil=ellipse(gaze,Vector2(0.174*0.47,0.221*0.61))
    for clipped in Geometry2D.intersect_polygons(pupil,local_eye):
     for i in clipped.size():clipped[i]=origin+clipped[i]*width
     if clipped.size()>2 and absf(area(clipped))>0.01:fill(canvas,clipped,Color(INK,1-spiral))
   stroke(canvas,eye,line,Color(INK,1-spiral),true)
  if spiral>0.001:
   var points=PackedVector2Array()
   for j in 73:
    var u=j/72.0;var theta=u*TAU*1.8+time*0.8
    points.append(origin+Vector2(cos(theta),sin(theta))*u*0.174*1.14*width)
   stroke(canvas,points,line,Color(INK,spiral))
  var brow=geometry(weights,'brows',side_index)
  for i in brow.size():brow[i]=origin+brow[i]*width
  stroke(canvas,brow,line,Color(INK,1.0 if show_angry_brows else 1-angry))
  if hurt>0.001:
   var cheek=PackedVector2Array()
   for i in 17:
    var t=i/16.0
    var q=Vector2(0.104,0.009)*(1-t)*(1-t)+2*(1-t)*t*Vector2(0.104-0.12*hurt,0.115)+t*t*Vector2(0.104-0.235*hurt,0.11)
    q.x*=-side;cheek.append(origin+q*width)
   stroke(canvas,cheek,line,Color(INK,hurt))
  if cry>0.001:
   canvas.draw_colored_polygon(ellipse(origin+Vector2(0,0.193)*width,Vector2(0.15,0.046*cry)*width),Color('#b8e9f0'))
   var tear=origin+Vector2(side*0.115,0.30+fmod(time*0.8+(side+1)*0.21,1)*0.27)*width
   canvas.draw_colored_polygon(ellipse(tear,Vector2(0.035,0.07)*width*cry),Color('#b8e9f0'))
 var blush=float(weights.get('blush',0))+float(weights.get('kiss',0))
 if blush>0.001:
  for side in [-1,1]:canvas.draw_colored_polygon(ellipse(position+Vector2(side*0.35,0.25)*width,Vector2(0.11,0.045)*width),Color(0.84,0.37,0.47,blush*0.45))
 if not no_mouth:
  var mouth=geometry(weights,'mouth')
  for i in mouth.size():mouth[i]=position+mouth[i]*width
  if absf(area(mouth))>0.01:fill(canvas,mouth,INK)
  stroke(canvas,mouth,line,INK,true)
func area(points):
 var value=0.0
 for i in points.size():value+=points[i].cross(points[(i+1)%points.size()])
 return value*0.5

func clean_polygon(points):
 var result=PackedVector2Array()
 for p in points:
  if result.is_empty() or p.distance_squared_to(result[-1])>0.000000000001:result.append(p)
 if result.size()>1 and result[0].distance_squared_to(result[-1])<0.000000000001:result.remove_at(result.size()-1)
 return result
func fill(canvas,points,color):
 var cleaned=clean_polygon(points)
 if cleaned.size()>2 and not Geometry2D.triangulate_polygon(cleaned).is_empty():canvas.draw_colored_polygon(cleaned,Color(color,color.a*opacity))
