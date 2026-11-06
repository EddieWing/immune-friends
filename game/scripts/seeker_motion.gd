extends RefCounted
# Demo 1.0.0: ReturnHome waits 1.1 s, retaining the last direction while
# waiting; outside 10 physics units it then steers toward the spawn position.
# The body/reference unit adapter is the same 26 / 3.5 used by source geometry.
const RETURN_DELAY=1.1
const HOME_RADIUS=10.0*26.0/3.5
static func reset(cell):
	cell["seeker_home"]=cell.p
	cell["seeker_return_timer"]=RETURN_DELAY
	cell["seeker_direction"]=Vector2.ZERO
	cell["seeker_returning"]=false
static func direction(sim,cell,target,delta):
	if not cell.has("seeker_home"):reset(cell)
	if not target.is_empty():
		# Retain Microcosm's existing direct pursuit and target selection.
		cell.seeker_direction=cell.p.direction_to(target.p)
		cell.seeker_return_timer=RETURN_DELAY
		cell.seeker_returning=false
	else:
		var crossing=cell.seeker_return_timer>0
		cell.seeker_return_timer-=delta
		if cell.seeker_return_timer<=0:
			var offset: Vector2=cell.seeker_home-cell.p
			if offset.length()>HOME_RADIUS:
				cell.seeker_direction=offset.normalized()
				cell.seeker_returning=true
				if crossing:sim.record("cell_return",{"id":cell.id,"p":cell.p,"home":cell.seeker_home})
			else:
				cell.seeker_direction=Vector2.ZERO
				cell.seeker_returning=false
	return cell.seeker_direction
