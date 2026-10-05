extends Control
## MAIN CITY / CITY 1
## Minimap exclusivo da cidade nova. Desenha a geometria real próxima ao jogador
## e não usa mais city_map.json, bairros ou qualquer dado do mapa antigo.

signal pause_requested

const ROAD_COLOR := Color("627c91")
const BUILDING_COLOR := Color("2a4055")
const LAND_COLOR := Color("213c35")
const WATER_COLOR := Color("235a73")
const ROAD_WORDS := ["road", "street", "tarmac", "highway", "sidewalk", "pavement", "parking", "bridge", "ramp", "lane", "avenue", "rua"]
const WATER_WORDS := ["water", "river", "lake", "canal", "sea", "agua"]
const LAND_WORDS := ["ground", "terrain", "grass", "land", "dirt", "solo", "terreno"]
const IGNORE_WORDS := ["lamp", "light", "wire", "cable", "sign", "decal", "leaf", "leaves", "tree", "antenna"]

var target: Node3D
var zoom_radius: float = 150.0
var heading: float = 0.0
var redraw_interval := 0.10
var redraw_timer := 0.0
var origin := Vector3.ZERO
var features: Array[Dictionary] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Abrir mapa da City 1"
	clip_contents = true
	custom_minimum_size = Vector2(196,196)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; varying vec2 local_position; uniform vec2 center = vec2(98.0); uniform float radius = 97.0; void vertex(){ local_position = VERTEX; } void fragment(){ COLOR.a *= 1.0-smoothstep(radius-1.0,radius,distance(local_position,center)); }"
	var circular := ShaderMaterial.new()
	circular.shader = shader
	material = circular
	resized.connect(_resize_circle)
	_resize_circle()
	call_deferred("_rebuild_city1_features")

func set_target(node: Node3D) -> void:
	target = node

func _contains_any(text: String, words: Array) -> bool:
	for word in words:
		if text.contains(str(word)):
			return true
	return false

func _rebuild_city1_features() -> void:
	features.clear()
	var scene := get_tree().current_scene
	if scene == null:
		return
	var city := scene.get_node_or_null("NovaCidade_City1") as Node3D
	if city == null:
		city = scene.find_child("NovaCidade_City1", true, false) as Node3D
	if city == null:
		push_warning("MAIN CITY: City 1 não encontrada para o minimapa.")
		return

	for raw_node in city.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := raw_node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null or not mesh_node.visible:
			continue
		var lname := str(mesh_node.name).to_lower()
		if _contains_any(lname, IGNORE_WORDS):
			continue
		var points := _mesh_footprint(mesh_node)
		if points.size() < 4:
			continue
		var bounds := _polygon_bounds(points)
		if bounds.size.x < 0.45 and bounds.size.y < 0.45:
			continue
		var kind := "building"
		if _contains_any(lname, ROAD_WORDS):
			kind = "road"
		elif _contains_any(lname, WATER_WORDS):
			kind = "water"
		elif _contains_any(lname, LAND_WORDS):
			kind = "land"
		features.append({"points": points, "center": bounds.get_center(), "kind": kind})
	queue_redraw()

func _mesh_footprint(mesh_node: MeshInstance3D) -> PackedVector2Array:
	var aabb := mesh_node.get_aabb()
	var y := aabb.position.y
	var locals := [
		Vector3(aabb.position.x, y, aabb.position.z),
		Vector3(aabb.end.x, y, aabb.position.z),
		Vector3(aabb.end.x, y, aabb.end.z),
		Vector3(aabb.position.x, y, aabb.end.z)
	]
	var result := PackedVector2Array()
	for local_point in locals:
		var world_point: Vector3 = mesh_node.global_transform * local_point
		result.append(Vector2(world_point.x, world_point.z))
	return result

func _polygon_bounds(points: PackedVector2Array) -> Rect2:
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for p in points:
		min_pos.x = minf(min_pos.x, p.x)
		min_pos.y = minf(min_pos.y, p.y)
		max_pos.x = maxf(max_pos.x, p.x)
		max_pos.y = maxf(max_pos.y, p.y)
	return Rect2(min_pos, max_pos - min_pos)

func _process(delta: float) -> void:
	redraw_timer += delta
	if redraw_timer < redraw_interval:
		return
	redraw_timer = 0.0
	if is_instance_valid(target):
		origin = target.global_position
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		heading = camera.global_rotation.y
	queue_redraw()

func _world_to_map_v2(pos: Vector2) -> Vector2:
	var offset := Vector2(pos.x - origin.x, pos.y - origin.z)
	return size * 0.5 + offset.rotated(heading) * minf(size.x, size.y) / (2.0 * zoom_radius)

func _world_to_map(pos: Vector3) -> Vector2:
	return _world_to_map_v2(Vector2(pos.x, pos.z))

func _screen_polygon(world_points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in world_points:
		result.append(_world_to_map_v2(p))
	return result

func _feature_color(kind: String) -> Color:
	match kind:
		"road": return ROAD_COLOR
		"water": return WATER_COLOR
		"land": return LAND_COLOR
		_: return BUILDING_COLOR

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("101c2b"))
	var origin2 := Vector2(origin.x, origin.z)
	for wanted_kind in ["land", "water", "road", "building"]:
		for feature in features:
			if str(feature.get("kind", "building")) != wanted_kind:
				continue
			var feature_center: Vector2 = feature.get("center", Vector2.ZERO)
			if feature_center.distance_to(origin2) > zoom_radius * 1.8:
				continue
			var points: PackedVector2Array = feature.get("points", PackedVector2Array())
			if points.size() >= 3:
				draw_colored_polygon(_screen_polygon(points), _feature_color(wanted_kind))

	var gps: Variant = null
	if get_tree().current_scene != null:
		gps = get_tree().current_scene.get_node_or_null("GPSNavigation")
	if gps != null and bool(gps.get("has_destination")):
		var route: PackedVector2Array = gps.get_route()
		var current: Vector2 = gps.current_position()
		var last := _world_to_map_v2(current)
		for point in route:
			var next_point := _world_to_map_v2(point)
			draw_line(last, next_point, Color("4decc0"), 3.0, true)
			last = next_point
		var destination: Vector2 = gps.get_destination()
		draw_circle(_world_to_map_v2(destination), 6.0, Color("ffb454"))

	for car in get_tree().get_nodes_in_group("vehicle"):
		if not (car is Node3D):
			continue
		var marker := _world_to_map((car as Node3D).global_position)
		if Rect2(Vector2(7,7),size-Vector2(14,14)).has_point(marker):
			draw_rect(Rect2(marker-Vector2(3,4),Vector2(6,8)),Color("f4d686"))

	var center := size * 0.5
	draw_circle(center,9,Color(0,0,0,0.6))
	draw_colored_polygon(PackedVector2Array([center+Vector2(0,-8),center+Vector2(5,6),center+Vector2(0,3),center+Vector2(-5,6)]),Color("ffffff"))
	draw_arc(center,size.x*.5-3,0,TAU,96,Color("55e4bf"),2.0,true)
	draw_arc(center,size.x*.5-8,0,TAU,96,Color(.5,.8,.8,.18),1.0,true)

func _resize_circle() -> void:
	if material:
		material.set_shader_parameter("center",size*.5)
		material.set_shader_parameter("radius",minf(size.x,size.y)*.5)
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size*.5) <= minf(size.x,size.y)*.5

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventScreenTouch and event.pressed) or event.is_action_pressed("ui_accept"):
		pause_requested.emit()
		accept_event()
