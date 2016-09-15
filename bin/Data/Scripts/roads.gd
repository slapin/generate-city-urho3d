
extends Reference

var road_width
var sidewalk_width
var max_loop_count

func add_obj(d, name, data):
	d.append({"name": name, "data": data})
func split_building_v(obj):
	var objs = []
	var op = obj["data"]
	var road = Rect2(op.pos.x + (op.size.x - road_width) / 2.0, op.pos.y, road_width, op.size.y)
	var building1 = Rect2(op.pos.x, op.pos.y, (op.size.x - road_width) / 2.0, op.size.y)
	var building2 = Rect2(op.pos.x + op.size.x / 2.0 + road_width / 2.0 , op.pos.y, (op.size.x - road_width) / 2.0, op.size.y)
	add_obj(objs, "road", road)
	add_obj(objs, "buildings", building1)
	add_obj(objs, "buildings", building2)
	return objs
func split_building_h(obj):
	var objs = []
	var op = obj["data"]
	var road = Rect2(op.pos.x, op.pos.y + (op.size.y - road_width) / 2.0, op.size.x, road_width)
	var building1 = Rect2(op.pos.x, op.pos.y, op.size.x, (op.size.y - road_width) / 2.0)
	var building2 = Rect2(op.pos.x, op.pos.y + op.size.y / 2.0 + road_width / 2.0, op.size.x, (op.size.y - road_width) / 2.0)
	add_obj(objs, "buildings", building1)
	add_obj(objs, "buildings", building2)
	add_obj(objs, "road", road)
	return objs
func hsplit3(o, a1, a2, width):
	var objs = []
	var op = o["data"]
	var s1 = Rect2(op.pos.x, op.pos.y, width, op.size.y)
	var s2 = Rect2(op.pos.x + width, op.pos.y, op.size.x - 2 * width, op.size.y)
	var s3 = Rect2(op.pos.x + op.size.x - width, op.pos.y, width, op.size.y)
	add_obj(objs, a2, s1)
	add_obj(objs, a1, s2)
	add_obj(objs, a2, s3)
	return objs
func vsplit3(o, a1, a2, width):
	var objs = []
	var op = o["data"]
	var s1 = Rect2(op.pos.x, op.pos.y, op.size.x, width)
	var s2 = Rect2(op.pos.x, op.pos.y + width,  op.size.x, op.size.y - 2 * width)
	var s3 = Rect2(op.pos.x, op.pos.y + op.size.y - width, op.size.x, width)
	add_obj(objs, a2, s1)
	add_obj(objs, a1, s2)
	add_obj(objs, a2, s3)
	return objs
func split9(o, a1, a2, width):
	var objs = []
	var objs1 = vsplit3(o, a1, a2, width)
	var objs2 = hsplit3(objs1[0], a2, a2, width)
	var objs3 = hsplit3(objs1[1], a1, a2, width)
	var objs4 = hsplit3(objs1[2], a2, a2, width)
	for p in [objs2, objs3, objs4]:
		for q in p:
			objs.append(q)
	return objs

func split_sidewalk(obj):
	return split9(obj, "lot", "sidewalk", sidewalk_width)

func grow(o):
	var objs = []
	if o["name"] == "city":
		objs = split9(o, "city2", "sidewalk", sidewalk_width)
	if o["name"] == "city2":
		var op = o["data"]
		objs = split9(o, "buildings", "road", road_width)
	elif o["name"] == "buildings":
		var op = o["data"]
		var vo
		var sprandom = randf() * 100
		var varsize = randf() * 150
		if op.size.length() > 100 + varsize:
			if op.size.x / op.size.y > 1.0:
				vo = split_building_v(o)
			elif op.size.y / op.size.x > 1.0:
				vo = split_building_h(o)
			else:
				vo = split_building_h(o)
			for h in vo:
				objs.append(h)
		else:
			add_obj(objs, "build_space", op)
	elif o["name"] == "build_space":
		var vo = split_sidewalk(o)
		for h in vo:
			objs.append(h)
	return objs

func build(objects, road_width, sidewalk_width, max_loop_count):
	# Called every time the node is added to the scene.
	# Initialization here
	self.road_width = road_width
	self.sidewalk_width = sidewalk_width
	self.max_loop_count = max_loop_count
	if !road_width || !sidewalk_width || !max_loop_count:
		return
	var finals = []
	while objects.size() > 0:
		var exobjs = []
		var o = objects[0]
		objects.remove(objects.find(o))
		var newobjs = grow(o)
		if newobjs.size() == 0:
			finals.append(o)
		for h in newobjs:
			objects.append(h)
	for h in finals:
		objects.append(h)
func _ready():
	pass


