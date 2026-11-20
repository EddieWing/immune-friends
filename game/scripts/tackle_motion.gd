extends RefCounted
const OUTBOUND_SECONDS=5.0
const ARRIVAL_GAP=18.0
static func reset(cell):
	cell.tackle_age=0.0
	cell.tackle_returning=false
static func direction(sim,cell,delta):
	cell.tackle_age=float(cell.get("tackle_age",0.0))+delta
	if cell.tackle_age<OUTBOUND_SECONDS:
		return Vector2.RIGHT.rotated(cell.angle)
	if not cell.get("tackle_returning",false):
		cell.tackle_returning=true
		sim.record("cell_return",{"id":cell.id,"p":cell.p})
	var nearest={}
	var distance=INF
	for core in sim.blood:
		if core.alive and cell.p.distance_squared_to(core.p)<distance:
			nearest=core;distance=cell.p.distance_squared_to(core.p)
	if nearest.is_empty():return Vector2.ZERO
	var gap=cell.p.distance_to(nearest.p)-sim.physics.radius(cell)-sim.physics.radius(nearest)
	if gap<=ARRIVAL_GAP:return Vector2.ZERO
	return cell.p.direction_to(nearest.p)*clampf((gap-ARRIVAL_GAP)/35.0,0,1)
