extends RefCounted
# Reference 500 screen pixels / 12 pixels per world unit, adapted to Core size.
const SHOP_DISTANCE=500.0/12.0*(26.0/3.5)
const SHOP_ZOOM_ENTER=1.35
const SHOP_ZOOM_EXIT=1.30
var focused=false
var refocus=0.0
var previous_zoom=-1.0
func update_focus(center: Vector2,zoom: float,preparation: bool,placing: bool):
 if not preparation: focused=false
 elif placing: focused=true
 elif focused: focused=zoom>=SHOP_ZOOM_EXIT and center.length()<SHOP_DISTANCE+15.0
 else: focused=zoom>=SHOP_ZOOM_ENTER and center.length()<SHOP_DISTANCE
 return focused
func update_optics(zoom: float,delta: float,intensity: float,enabled: bool):
 if previous_zoom<0:previous_zoom=zoom
 var change=absf(zoom-previous_zoom)
 previous_zoom=zoom
 if not enabled or intensity<=0:refocus=0.0
 else:refocus=minf(1.0,maxf(0.0,refocus-delta*4.0)+change*3.0)
 return refocus*clampf(intensity,0,1)
