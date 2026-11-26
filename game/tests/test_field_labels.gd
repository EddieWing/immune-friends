extends SceneTree
func _initialize():call_deferred('run')
func run():
	var node=Node2D.new();root.add_child(node)
	for zoom in [0.9,1.0,1.5,2.0,3.0]:
		node.scale=Vector2.ONE*zoom;node.position=Vector2(30.3,44.7)
		var labels=preload('res://scripts/field_labels.gd')
		var result=labels.layout(node,Vector2(18,34),10)
		var physical_scale=(root.get_final_transform()*node.get_global_transform_with_canvas()).get_scale().y
		assert(result.size==maxi(1,roundi(10*physical_scale)),'Font rasterization must follow displayed zoom and window scaling')
		assert(result.point==result.point.round(),'Label baseline must align to viewport pixels')
		var composite=result.transform*result.transform.affine_inverse()
		assert(composite.is_equal_approx(Transform2D.IDENTITY),'Label drawing must cancel world scaling')
	print('PASS: field label raster size, pixel alignment and transform at x0.9/x1/x1.5/x2/x3');quit()
