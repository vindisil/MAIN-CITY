extends Node
## Navegacao urbana v0.0.12. Grafo de cruzamentos gerado uma vez.
## Apenas trechos de ruas fazem parte da rota; o destino selecionado
## no interior de uma quadra e projetado na via mais proxima.

signal route_changed
const UPDATE_EVERY_SECONDS: float = 0.90
const RECALCULATE_AFTER_METERS: float = 28.0
const FINISH_DISTANCE_METERS: float = 15.0

var streets: PackedFloat32Array = PackedFloat32Array()
var navigation_graph: AStar2D = AStar2D.new()
var route_points: PackedVector2Array = PackedVector2Array()
var destination: Vector2 = Vector2.ZERO
var requested_location: Vector2 = Vector2.ZERO
var has_destination: bool = false
var player: Node3D
var _clock: float = 0.0
var _last_player_position: Vector2 = Vector2(INF, INF)

func _ready() -> void:
    player = get_parent().get_node_or_null("Player") as Node3D
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/city_map.json"))
    if not parsed is Dictionary:
        push_warning("GPS: dados de ruas indisponiveis.")
        return
    var values: Array = parsed.get("roads", [])
    for item in values:
        streets.append(float(item))
    streets.sort()
    var count: int = streets.size()
    for xi in range(count):
        for zi in range(count):
            var point_id: int = xi * count + zi
            navigation_graph.add_point(point_id, Vector2(streets[xi], streets[zi]))
            if xi > 0:
                navigation_graph.connect_points(point_id, (xi - 1) * count + zi)
            if zi > 0:
                navigation_graph.connect_points(point_id, xi * count + zi - 1)

func _process(delta: float) -> void:
    if get_tree().paused or not has_destination or not is_instance_valid(player):
        return
    _clock += delta
    if _clock < UPDATE_EVERY_SECONDS:
        return
    _clock = 0.0
    var current: Vector2 = current_position()
    if current.distance_to(destination) <= FINISH_DISTANCE_METERS:
        clear_destination()
        return
    if current.distance_to(_last_player_position) >= RECALCULATE_AFTER_METERS:
        _rebuild_route(current)

func current_position() -> Vector2:
    if not is_instance_valid(player):
        return Vector2.ZERO
    var tracked: Node3D = player
    var vehicle: Node3D = player.get("vehicle") as Node3D
    if is_instance_valid(vehicle):
        tracked = vehicle
    return Vector2(tracked.global_position.x, tracked.global_position.z)

func set_destination(clicked: Vector2) -> void:
    if streets.is_empty():
        return
    requested_location = clicked
    var info: Dictionary = _nearest_street(clicked)
    destination = info["point"]
    has_destination = true
    _rebuild_route(current_position())

func clear_destination() -> void:
    has_destination = false
    route_points.clear()
    route_changed.emit()

func get_route() -> PackedVector2Array:
    return route_points

func get_destination() -> Vector2:
    return destination

func get_requested_location() -> Vector2:
    return requested_location

func remaining_distance() -> float:
    if not has_destination:
        return 0.0
    var sum: float = 0.0
    var origin: Vector2 = current_position()
    for point in route_points:
        sum += origin.distance_to(point)
        origin = point
    return sum

func _nearest_road_index(v: float) -> int:
    var nearest: int = 0
    var distance: float = INF
    for i in range(streets.size()):
        var error: float = absf(v - streets[i])
        if error < distance:
            distance = error
            nearest = i
    return nearest

func _nearest_street(pos: Vector2) -> Dictionary:
    var x_index: int = _nearest_road_index(pos.x)
    var z_index: int = _nearest_road_index(pos.y)
    var x_street: float = streets[x_index]
    var z_street: float = streets[z_index]
    var x_clamped: float = clampf(pos.x, streets[0], streets[streets.size()-1])
    var z_clamped: float = clampf(pos.y, streets[0], streets[streets.size()-1])
    if absf(pos.x - x_street) <= absf(pos.y - z_street):
        # Rua vertical (eixo Z); conectar a intersecao mais proxima.
        var junction_z: int = _nearest_road_index(z_clamped)
        return {"point": Vector2(x_street, z_clamped), "id": x_index * streets.size() + junction_z}
    # Rua horizontal (eixo X).
    var junction_x: int = _nearest_road_index(x_clamped)
    return {"point": Vector2(x_clamped, z_street), "id": junction_x * streets.size() + z_index}

func _append_unique(point: Vector2) -> void:
    if route_points.is_empty() or route_points[route_points.size() - 1].distance_to(point) > 0.15:
        route_points.append(point)

func _rebuild_route(origin: Vector2) -> void:
    if not has_destination or streets.is_empty():
        return
    _last_player_position = origin
    route_points.clear()
    var start: Dictionary = _nearest_street(origin)
    var goal: Dictionary = _nearest_street(destination)
    var entry: Vector2 = start["point"]
    var exit_road: Vector2 = goal["point"]
    _append_unique(entry)
    var road_path: PackedVector2Array = navigation_graph.get_point_path(int(start["id"]), int(goal["id"]))
    for point in road_path:
        _append_unique(point)
    _append_unique(exit_road)
    # Nao inventar atalho atravessando construcao: ponto final sempre na rua.
    route_changed.emit()
