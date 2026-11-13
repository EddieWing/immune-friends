extends "res://scripts/simulation.gd"
var batch_passes=0
func advance_projectiles_web(delta,movement_delta):
	batch_passes+=1
	super(delta,movement_delta)
