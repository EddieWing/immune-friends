extends RefCounted
# Reference selection: Demo 1.0.0 ChainRange=6; same unit adapter as sources.
# Rigid pose projection is our solver implementation, not a Box2D port.
var groups=[]
var membership={}
func eligible(s,origin,other):
	var reach=float(s.rules.get("bond_query_radius",6.0*26.0/3.5))
	if not s.physics.is_box(s,other):
		return origin.distance_to(other.p)<=reach+s.physics.radius(other)
	var offset=other.p-origin
	for axis in [Vector2.RIGHT,Vector2.DOWN]+s.physics.axes(other):
		if absf(offset.dot(axis))>reach*(absf(axis.x)+absf(axis.y))+s.physics.extent(s,other,axis):return false
	return true
func rebuild(s):
	if s.phase=="battle":return
	s.links.clear()
	var candidates=[]
	for body in s.cells+s.blood:
		if body.alive:candidates.append(body)
	for cell in s.cells:
		if not cell.alive or s.catalog[cell.key].behavior!="bond":continue
		var near=candidates.filter(func(other):return other!=cell and eligible(s,cell.p,other))
		near.sort_custom(func(a,b):
			var da=cell.p.distance_squared_to(a.p);var db=cell.p.distance_squared_to(b.p)
			return da<db if not is_equal_approx(da,db) else s.physics.id_of(a)<s.physics.id_of(b))
		var count=int(s.constant_of(cell,"maxBonds",2))
		for other in near.slice(0,count):
			var id=s.physics.id_of(other)
			if not s.links.any(func(link):return (link.a==cell.id and link.b==id) or (link.b==cell.id and link.a==id)):
				s.links.append({"a":cell.id,"b":id,"rest":cell.p.distance_to(other.p),"owner":cell.id})
func lock(s):
	for link in s.links:
		var a=s.endpoint_by_id(link.a);var b=s.endpoint_by_id(link.b)
		link.offset=(b.p-a.p).rotated(-float(a.get("angle",0)))
		link.relative_angle=wrapf(float(b.get("angle",0))-float(a.get("angle",0)),-PI,PI)
		link.locked=true
func prepare(s):
	groups.clear();membership.clear()
	if s.phase!="battle":return
	s.links=s.links.filter(func(link):
		var a=s.endpoint_by_id(link.a);var b=s.endpoint_by_id(link.b)
		return not a.is_empty() and not b.is_empty() and a.alive and b.alive)
	var adjacency={}
	for link in s.links:
		if not link.get("locked",false):continue
		for id in [link.a,link.b]:
			if not adjacency.has(id):adjacency[id]=[]
			adjacency[id].append(link)
	for root in adjacency:
		if membership.has(root):continue
		var group=[]
		var queue=[{"id":root,"p":Vector2.ZERO,"angle":0.0}]
		membership[root]=groups.size()
		while not queue.is_empty():
			var node=queue.pop_front()
			group.append(node)
			for link in adjacency[node.id]:
				var forward=link.a==node.id
				var other=link.b if forward else link.a
				if membership.has(other):continue
				var angle=node.angle+(link.relative_angle if forward else -link.relative_angle)
				var offset=link.offset.rotated(node.angle) if forward else -link.offset.rotated(angle)
				queue.append({"id":other,"p":node.p+offset,"angle":angle})
				membership[other]=groups.size()
		groups.append(group)
func same_group(a,b):
	return membership.has(a) and membership.get(a)==membership.get(b)
func project(s):
	for group in groups:
		var mass=0.0
		var center=Vector2.ZERO;var rest_center=Vector2.ZERO;var velocity=Vector2.ZERO
		for node in group:
			var body=s.endpoint_by_id(node.id)
			var m=s.physics.mass(s,body)
			mass+=m;center+=body.p*m;rest_center+=node.p*m;velocity+=s.physics.velocity(body)*m
		center/=mass;rest_center/=mass;velocity/=mass
		var cosine=0.0;var sine=0.0
		for node in group:
			var body=s.endpoint_by_id(node.id)
			var rest=node.p-rest_center;var actual=body.p-center
			var m=s.physics.mass(s,body);var inertia=s.physics.inertia(s,body)
			var angle=float(body.get("angle",0))-node.angle
			cosine+=m*rest.dot(actual)+inertia*cos(angle)
			sine+=m*rest.cross(actual)+inertia*sin(angle)
		var rotation=atan2(sine,cosine)
		var angular_momentum=0.0;var group_inertia=0.0
		for node in group:
			var body=s.endpoint_by_id(node.id)
			var m=s.physics.mass(s,body);var inertia=s.physics.inertia(s,body)
			angular_momentum+=inertia*s.physics.angular_velocity(body)+m*(body.p-center).cross(s.physics.velocity(body)-velocity)
			group_inertia+=inertia+m*(node.p-rest_center).length_squared()
		var spin=angular_momentum/maxf(group_inertia,0.001)
		for node in group:
			var body=s.endpoint_by_id(node.id)
			var offset=(node.p-rest_center).rotated(rotation)
			body.p=center+offset
			body.angle=wrapf(rotation+node.angle,-PI,PI)
			var state=s.physics.state(body)
			state.v=velocity+Vector2(-offset.y,offset.x)*spin
			state.w=spin
