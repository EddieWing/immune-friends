extends "res://tests/fixtures/endpoint_comparison.gd"
const PreviousPhysics=preload("res://tests/fixtures/legacy_pair_physics.gd")
func fixture(old):
	var s=super.fixture(false)
	if old:
		var previous=PreviousPhysics.new()
		previous.states=s.physics.states.duplicate(true)
		previous.drives=s.physics.drives.duplicate(true)
		previous.contacts=s.physics.contacts.duplicate(true)
		s.physics=previous
	return s
