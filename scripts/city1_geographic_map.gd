extends Control
## MAIN CITY / CITY 1
## Mapa geografico exclusivo da nova cidade.
## Gera o desenho a partir da geometria atualmente carregada em NovaCidade_City1.
## Nao usa city_map.json nem dados do mapa antigo.

signal destination_selected(world_location: Vector2)

const MAP_MARGIN := 16.0
const BACKGROUND_COLOR := Color("08131e")
const LAND_COLOR := Color("19352f")
const ROAD_COLOR := Color("59636d")
const BUILDING_COLOR := Color("9ca8b5")
const WATER_COLOR := Color("235a73")
const OUTLINE_COLOR := Color("54cdb6")
const PLAYER_COLOR := Color("ffffff")
const ROUTE_COLOR := Color("4decc0")
const DESTINATION_COLOR := Color("ffb454")

const ROAD_WORDS := ["road", "street", "tarmac", "highway", "sidewalk", "pavement", "parking", "bridge", "ramp", "lane", "avenue", "rua"]
const WATER_WORDS := ["water", "river", "lake", "canal", "sea", "agua"]
const LAND_WORDS := ["ground", "terrain", "grass", "land", "dirt", "solo", "terreno"]
const IGNORE_WORDS := ["lamp", "light", "wire", "cable", "sign", "decal", "leaf", "leaves", "tree", "antenna"]

var features: Array[Dictionary] = []
var world_bounds := Rect2(Vector2(-500, -500), Vector2(1000, 1000))
var navigation: Variant = null
var player: Node3D = null
var _elapsed := 0.0
var _map_ready := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, 315.0)
	var scene := get_tree().current_scene
	if scene != null:
		navigation = scene.get_node_or_null("GPSNavigation")
		player = scene.get_node_or_null("Player") as Node3D
		if navigation != null and navigation.has_signal("route_changed"):
			navigation.route_changed.connect(queue_redraw)
	resized.connect(queue_redraw)
	call_deferred("_rebuild_geographic_map")

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.25:
		_elapsed = 0.0
		if visible:
			queue_redraw()

func _rebuild_geographic_map() -> void:
	features.clear()
	_map_ready = false
	var scene := get_tree().current_scene
	if scene == null:
		queue_redraw()
		return
	var city := scene.get_node_or_null("NovaCidade_City1") as Node3D
	if city == null:
		# Fallback: procura pelo nome caso a cena tenha sido reparentada.
		city = scene.find_child("NovaCidade_City1", true, false) as Node3D
	if city == null:
		push_warning("MAIN CITY: NovaCidade_City1 nao encontrada para gerar mapa geografico.")
		queue_redraw()
		return

	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	var meshes := city.find_children("*", "MeshInstance3D", true, false)
	for raw_node in meshes:
		var mesh_node := raw_node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null or not mesh_node.visible:
			continue
		var lname := str(mesh_node.name).to_lower()
		if _contains_any(lname, IGNORE_WORDS):
			continue
		var footprint := _mesh_footprint(mesh_node)
		if footprint.size() < 4:
			continue
		var footprint_bounds := _polygon_bounds(footprint)
		if footprint_bounds.size.x < 0.35 and footprint_bounds.size.y < 0.35:
			continue

		var kind := "building"
		if _contains_any(lname, ROAD_WORDS):
			kind = "road"
		elif _contains_any(lname, WATER_WORDS):
			kind = "water"
		elif _contains_any(lname, LAND_WORDS):
			kind = "land"
		features.append({"points": footprint, "kind": kind})
		for p in footprint:
			min_pos.x = minf(min_pos.x, p.x)
			min_pos.y = minf(min_pos.y, p.y)
			max_pos.x = maxf(max_pos.x, p.x)
			max_pos.y = maxf(max_pos.y, p.y)

	if features.is_empty() or not is_finite(min_pos.x) or not is_finite(max_pos.x):
		world_bounds = Rect2(Vector2(-500, -500), Vector2(1000, 1000))
	else:
		var span := max_pos - min_pos
		var pad := maxf(8.0, maxf(span.x, span.y) * 0.035)
		world_bounds = Rect2(min_pos - Vector2.ONE * pad, span + Vector2.ONE * pad * 2.0)
		_map_ready = true
	queue_redraw()

func _mesh_footprint(mesh_node: MeshInstance3D) -> PackedVector2Array:
	var aabb := mesh_node.get_aabb()
	var y := aabb.position.y
	var local_points := [
		Vector3(aabb.position.x, y, aabb.position.z),
		Vector3(aabb.end.x, y, aabb.position.z),
		Vector3(aabb.end.x, y, aabb.end.z),
		Vector3(aabb.position.x, y, aabb.end.z)
	]
	var result := PackedVector2Array()
	for local_point in local_points:
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

func _contains_any(text: String, words: Array) -> bool:
	for word in words:
		if text.contains(str(word)):
			return true
	return false

func _map_rect() -> Rect2:
	var available := size - Vector2.ONE * MAP_MARGIN * 2.0
	return Rect2(Vector2.ONE * MAP_MARGIN, Vector2(maxf(10.0, available.x), maxf(10.0, available.y)))

func _world_draw_rect() -> Rect2:
	var rect := _map_rect()
	var sx := rect.size.x / maxf(1.0, world_bounds.size.x)
	var sy := rect.size.y / maxf(1.0, world_bounds.size.y)
	var scale := minf(sx, sy)
	var draw_size := world_bounds.size * scale
	return Rect2(rect.position + (rect.size - draw_size) * 0.5, draw_size)

func _to_screen(world: Vector2) -> Vector2:
	var draw_rect := _world_draw_rect()
	var normalized := (world - world_bounds.position) / world_bounds.size
	return draw_rect.position + normalized * draw_rect.size

func _to_world(screen: Vector2) -> Vector2:
	var draw_rect := _world_draw_rect()
	var normalized := (screen - draw_rect.position) / draw_rect.size
	return world_bounds.position + normalized * world_bounds.size

func _screen_polygon(world_points: PackedVector2Array) -> PackedVector2Array:
	var screen_points := PackedVector2Array()
	for p in world_points:
		screen_points.append(_to_screen(p))
	return screen_points

func _feature_color(kind: String) -> Color:
	match kind:
		"road": return ROAD_COLOR
		"water": return WATER_COLOR
		"land": return LAND_COLOR
		_: return BUILDING_COLOR

func _current_player_position() -> Vector2:
	if is_instance_valid(player):
		return Vector2(player.global_position.x, player.global_position.z)
	if navigation != null and navigation.has_method("current_position"):
		return navigation.current_position()
	return world_bounds.get_center()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR)
	var map_area := _world_draw_rect()
	draw_rect(map_area, Color("0f2027"))

	for wanted_kind in ["land", "water", "road", "building"]:
		for feature in features:
			if str(feature.get("kind", "building")) != wanted_kind:
				continue
			var points: PackedVector2Array = feature.get("points", PackedVector2Array())
			if points.size() >= 3:
				draw_colored_polygon(_screen_polygon(points), _feature_color(wanted_kind))

	if navigation != null and bool(navigation.get("has_destination")):
		var route: PackedVector2Array = navigation.get_route()
		var last := _to_screen(navigation.current_position())
		for point in route:
			var next_point := _to_screen(point)
			draw_line(last, next_point, ROUTE_COLOR, 3.0, true)
			last = next_point
		if navigation.has_method("get_destination"):
			var destination := _to_screen(navigation.get_destination())
			draw_circle(destination, 7.0, Color("132339"))
			draw_circle(destination, 5.0, DESTINATION_COLOR)

	var me := _to_screen(_current_player_position())
	draw_circle(me, 8.0, Color("08131e"))
	draw_circle(me, 5.0, PLAYER_COLOR)
	draw_rect(map_area, OUTLINE_COLOR, false, 1.5)

	var font := get_theme_default_font()
	draw_string(font, map_area.position + Vector2(10, 20), "MAIN CITY • CITY 1", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dcecf3"))
	draw_string(font, map_area.position + Vector2(map_area.size.x - 22, 20), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, OUTLINE_COLOR)

	if not _map_ready:
		draw_string(font, size * 0.5 - Vector2(132, 0), "Gerando mapa geografico da City 1...", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dcecf3"))

func _gui_input(event: InputEvent) -> void:
	var click := Vector2.ZERO
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT or not mouse.pressed:
			return
		click = mouse.position
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			return
		click = touch.position
	else:
		return
	if not _world_draw_rect().has_point(click):
		return
	destination_selected.emit(_to_world(click))
	accept_event()
