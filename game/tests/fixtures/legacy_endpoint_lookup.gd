extends "res://scripts/simulation.gd"
# Previous lookup paths, used with the same simulation algorithms.
func cell_by_id(id):
	for c in cells:
		if c.id==id:return c
	return {}
func endpoint_by_id(id):
	if id < -1:
		for b in blood:
			if -2-int(b.id)==id:return b
		return {}
	var cell=cell_by_id(id)
	if not cell.is_empty():return cell
	for v in viruses:
		if v.id==id:return v
	return {}
