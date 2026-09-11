extends Control
var game
func _can_drop_data(_at_position,data):
	return game.sim.phase=="shop" and data is Dictionary and data.get("kind","")=="cell_offer"
func _drop_data(at_position,data):
	var screen=global_position+at_position
	var world=game.view.get_global_transform().affine_inverse()*screen
	game.buy_offer_at(data.index,data.reward,world)

