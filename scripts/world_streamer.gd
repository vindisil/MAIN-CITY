extends Node3D
## v0.0.1 - Carregamento progressivo da cidade em blocos de 320 m.
## Somente as instâncias de cenas são criadas/removidas na thread principal.
## O carregamento dos arquivos (incluindo modelos) usa ResourceLoader em thread.

const CELL_SIZE: float = 320.0
const REFRESH_SECONDS: float = 0.18
const CITY_PATH: String = "res://scenes/city_chunks/cell_%d_%d.tscn"
const EXTRA_SCENES: Array[Dictionary] = [
    {"name": "ExpansaoUrbanaV29_1", "path": "res://scenes/v29_1_expansao.tscn", "point": Vector2(90.0, 60.0), "radius": 345.0},
    {"name": "QuadraConcessionariaV29_3", "path": "res://scenes/v29_3_quadra.tscn", "point": Vector2(90.0, 100.0), "radius": 335.0},
    {"name": "BMWV19", "path": "res://scenes/v24_bmw.tscn", "point": Vector2(0.0, 70.0), "radius": 235.0, "position": Vector3(0.0, 0.90, 70.0)},
    {"name": "MercedesGLSV19", "path": "res://scenes/v24_gls.tscn", "point": Vector2(0.0, 88.0), "radius": 235.0, "position": Vector3(0.0, 1.0, 88.0)},
    {"name": "FordF150Raptor", "path": "res://scenes/v30_6_raptor_dirigivel.tscn", "point": Vector2(-3.25, 104.0), "radius": 235.0, "position": Vector3(-3.25, 0.95, 104.0)},
    {"name": "FordF150RaptorPolicial", "vehicle_name": "FORD RAPTOR POLICIAL", "path": "res://scenes/v0_0_1_raptor_policial.tscn", "point": Vector2(-3.25, 117.0), "radius": 235.0, "position": Vector3(-3.25, 0.95, 117.0)},
    {"name": "BlindadoPolicial1", "vehicle_name": "BLINDADO POLICIAL 1", "path": "res://scenes/v30_6_blindado_dirigivel.tscn", "point": Vector2(-3.25, 143.0), "radius": 235.0, "position": Vector3(-3.25, 1.10, 143.0)},
    {"name": "BlindadoPolicial2", "vehicle_name": "BLINDADO POLICIAL 2", "path": "res://scenes/v0_0_1_blindado_2.tscn", "point": Vector2(3.25, 143.0), "radius": 235.0, "position": Vector3(3.25, 1.10, 143.0)},
    # v0.0.50: user-provided parked vehicles, loaded near the existing BMW / GLS / Raptor.
    # Two Duster instances reuse ONE imported GLB.
    # v0.0.60: same street location; now a driveable Urus with the four original wheels.
    {"name": "UrusRuaV50", "path": "res://scenes/v50_urus.tscn", "point": Vector2(3.25, 78.0), "radius": 90.0, "position": Vector3(3.25, 0.13, 78.0)},
    {"name": "DusterPoliciaRuaV50_A", "path": "res://scenes/v50_duster_policia.tscn", "point": Vector2(3.25, 103.0), "radius": 90.0, "position": Vector3(3.25, 0.03, 103.0)},
    {"name": "DusterPoliciaRuaV50_B", "path": "res://scenes/v50_duster_policia.tscn", "point": Vector2(3.25, 130.0), "radius": 90.0, "position": Vector3(3.25, 0.03, 130.0)},
    {"name": "AmbulanciaRuaNascimento", "path": "res://scenes/v60_ambulancia_rua.tscn", "point": Vector2(3.25, 160.0), "radius": 90.0, "position": Vector3(3.25, 0.02, 160.0)},
    {"name": "HammerMilitarRuaNascimento", "path": "res://scenes/v70_hammer_militar_rua.tscn", "point": Vector2(-3.25, 178.0), "radius": 260.0, "position": Vector3(-3.25, 0.36, 178.0)},
    {"name": "CaminhaoMilitarRuaNascimento", "path": "res://scenes/v70_caminhao_militar_rua.tscn", "point": Vector2(3.25, 194.0), "radius": 260.0, "position": Vector3(3.25, 0.40, 194.0)},
    {"name": "BairroImportadoV19", "path": "res://scenes/v19_bairro_importado.tscn", "point": Vector2(1340.0, 0.0), "radius": 435.0}
]

var player: Node3D
var city_root: Node3D
var loaded_cells: Dictionary = {}
var pending_cells: Dictionary = {}
var loaded_extras: Dictionary = {}
var pending_extras: Dictionary = {}
var prepared_extras: Dictionary = {}
var refresh_clock: float = REFRESH_SECONDS
var refresh_interval: float = REFRESH_SECONDS
var mobile_streaming: bool = false
var frame_counter: int = 0
var recent_velocity: Vector3 = Vector3.ZERO
var last_pos: Vector3 = Vector3.ZERO
var startup_age: float = 0.0
var persistent_vehicles: Dictionary = {}

func keep_vehicle(vehicle: VehicleBody3D) -> void:
    if not is_instance_valid(vehicle):
        return
    for cell in loaded_cells:
        var chunk: Node = loaded_cells[cell]
        if is_instance_valid(chunk) and chunk.is_ancestor_of(vehicle):
            var key := "%s:%s" % [cell, chunk.get_path_to(vehicle)]
            persistent_vehicles[key] = vehicle
            vehicle.set_meta("stream_origin_key", key)
            vehicle.reparent(get_parent(), true)
            return

func _preserve_used_vehicles(chunk: Node) -> void:
    for vehicle in get_tree().get_nodes_in_group("vehicle"):
        if vehicle is VehicleBody3D and chunk.is_ancestor_of(vehicle):
            if vehicle.get("driver") != null or bool(vehicle.get_meta("has_been_driven", false)):
                keep_vehicle(vehicle)

func _remove_returned_vehicle_duplicates(chunk: Node, cell: Vector2i) -> void:
    for vehicle in chunk.find_children("*", "VehicleBody3D", true, false):
        var key := "%s:%s" % [cell, chunk.get_path_to(vehicle)]
        if persistent_vehicles.has(key) and is_instance_valid(persistent_vehicles[key]):
            vehicle.queue_free()

func _ready() -> void:
    player = get_parent().get_node_or_null("Player") as Node3D
    city_root = get_parent().get_node_or_null("Cidade") as Node3D
    if player != null:
        last_pos = player.global_position
    mobile_streaming = OS.has_feature("mobile")
    refresh_interval = 0.34 if mobile_streaming else REFRESH_SECONDS
    if mobile_streaming:
        var sun: DirectionalLight3D = get_parent().get_node_or_null("Sun") as DirectionalLight3D
        if sun != null:
            sun.directional_shadow_max_distance = 95.0
    # The global ground is part of main.tscn; there is always collision under the player.
    set_process(player != null and city_root != null)

func _process(delta: float) -> void:
    if not is_instance_valid(player):
        return
    frame_counter += 1
    startup_age += delta
    var current_pos: Vector3 = _player_world_position()
    recent_velocity = (current_pos - last_pos) / maxf(delta, 0.001)
    last_pos = current_pos
    refresh_clock += delta
    if refresh_clock >= refresh_interval:
        refresh_clock = 0.0
        _refresh_needed()
    # Em mobile, leitura/instanciação são distribuídas em mais frames.
    if not mobile_streaming or frame_counter % 3 == 0:
        _instantiate_one_ready_scene()
    if not mobile_streaming or frame_counter % 5 == 0:
        _activate_one_prepared_extra()

func _player_world_position() -> Vector3:
    var current_vehicle: Node = player.get("vehicle") as Node
    if is_instance_valid(current_vehicle) and current_vehicle is Node3D:
        return (current_vehicle as Node3D).global_position
    return player.global_position

func _player_cell() -> Vector2i:
    var pos: Vector3 = _player_world_position()
    return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

func _cell_distance_squared(cell: Vector2i) -> float:
    var pos: Vector3 = _player_world_position()
    var x: float = (float(cell.x) + 0.5) * CELL_SIZE - pos.x
    var z: float = (float(cell.y) + 0.5) * CELL_SIZE - pos.z
    return x * x + z * z

func _cell_path(cell: Vector2i) -> String:
    return CITY_PATH % [cell.x, cell.y]

func _refresh_needed() -> void:
    var center: Vector2i = _player_cell()
    var current_pos: Vector3 = _player_world_position()
    # Fast cars get an additional ring ahead of them, before entering a new area.
    var fast: bool = recent_velocity.length_squared() > 144.0 or player.get("vehicle") != null
    var radius: int = 2 if fast else 1
    var candidates: Array[Vector2i] = []
    for x in range(center.x - radius, center.x + radius + 1):
        for z in range(center.y - radius, center.y + radius + 1):
            if x < -4 or x > 3 or z < -4 or z > 3:
                continue
            var cell := Vector2i(x, z)
            if loaded_cells.has(cell) or pending_cells.has(cell):
                continue
            candidates.append(cell)
    candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_distance_squared(a) < _cell_distance_squared(b))
    # Request only a few new files per update. A loader thread parses the scene
    # while the player can keep moving; the engine main thread remains responsive.
    for cell in candidates:
        var initial_limit: int = 2 if mobile_streaming else (2 if startup_age < 1.5 else 5)
        if pending_cells.size() >= initial_limit:
            break
        var path := _cell_path(cell)
        if not ResourceLoader.exists(path):
            continue
        var error := ResourceLoader.load_threaded_request(path, "PackedScene", true)
        if error == OK or error == ERR_BUSY:
            pending_cells[cell] = path
        elif error != ERR_BUSY:
            push_warning("Nao foi possivel solicitar setor: %s (erro %d)" % [path, error])
    # Remove sectors only when safely outside the nearby area, avoiding repeated
    # creation/destruction when the player crosses a grid boundary.
    for cell in loaded_cells.keys():
        if maxi(absi(cell.x - center.x), absi(cell.y - center.y)) > 3:
            var chunk: Node = loaded_cells[cell]
            if is_instance_valid(chunk):
                _preserve_used_vehicles(chunk)
            loaded_cells.erase(cell)
            var lamps: Node = get_parent().get_node_or_null("StreetLamps")
            if lamps != null:
                lamps.call("unregister_cell", cell)
            if is_instance_valid(chunk):
                chunk.queue_free()
    # Não dispute leitura/CPU com o personagem durante a entrada.
    if startup_age < 2.4:
        return

    for entry in EXTRA_SCENES:
        var entry_name: String = entry["name"]
        var target: Vector2 = entry["point"]
        var dist: float = Vector2(current_pos.x,current_pos.z).distance_to(target)
        var spawn_radius: float = float(entry["radius"])

        # V0.4.5: primeiro carrega em thread bem antes; só depois instancia.
        # Veículos pesados não começam mais a carregar a 75-90 m do jogador.
        var is_vehicle_scene: bool = (
            entry_name.contains("BMW") or entry_name.contains("Mercedes") or
            entry_name.contains("FordF150") or entry_name.contains("Blindado") or
            entry_name.contains("Urus") or entry_name.contains("Duster") or
            entry_name.contains("Hammer") or entry_name.contains("Caminhao")
        )
        var request_radius: float = spawn_radius + (260.0 if is_vehicle_scene else 120.0)
        request_radius += minf(recent_velocity.length()*3.0,150.0)
        var warm_radius: float = spawn_radius + (115.0 if is_vehicle_scene else 35.0)

        if dist < request_radius and not loaded_extras.has(entry_name) and not prepared_extras.has(entry_name) and not pending_extras.has(entry_name):
            if pending_extras.size() < (2 if mobile_streaming else 4):
                var path: String = entry["path"]
                var error := ResourceLoader.load_threaded_request(path,"PackedScene",true,ResourceLoader.CACHE_MODE_REUSE)
                if error == OK or error == ERR_BUSY:
                    pending_extras[entry_name] = path
                elif error != ERR_BUSY:
                    push_warning("Nao foi possivel solicitar modelo: %s (erro %d)" % [path,error])

        # O recurso preparado pode ficar em memória sem estar na árvore.
        # A ativação real é feita em _activate_one_prepared_extra, uma por vez.
        if dist > request_radius + 260.0 and prepared_extras.has(entry_name):
            prepared_extras.erase(entry_name)

        if dist > warm_radius + 260.0 and loaded_extras.has(entry_name):
            var object: Node = loaded_extras[entry_name]
            if object is VehicleBody3D and (object.get("driver") != null or object.get_meta("has_been_driven",false)):
                continue
            loaded_extras.erase(entry_name)
            if is_instance_valid(object):
                object.queue_free()

func _instantiate_one_ready_scene() -> void:
    var best_cell := Vector2i.ZERO
    var best_distance: float = INF
    var has_best_cell: bool = false
    for cell in pending_cells.keys():
        var status := ResourceLoader.load_threaded_get_status(pending_cells[cell])
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            push_warning("Falha ao carregar setor: %s" % pending_cells[cell])
            pending_cells.erase(cell)
            continue
        if status != ResourceLoader.THREAD_LOAD_LOADED:
            continue
        var d := _cell_distance_squared(cell)
        if d < best_distance:
            best_distance = d
            best_cell = cell
            has_best_cell = true
    if has_best_cell:
        var path: String = pending_cells[best_cell]
        pending_cells.erase(best_cell)
        var scene: PackedScene = ResourceLoader.load_threaded_get(path) as PackedScene
        if scene == null:
            return
        var chunk: Node3D = scene.instantiate() as Node3D
        if chunk != null:
            chunk.name = "Setor_%d_%d" % [best_cell.x, best_cell.y]
            city_root.add_child(chunk)
            loaded_cells[best_cell] = chunk
            _remove_returned_vehicle_duplicates(chunk, best_cell)
            var lamps: Node = get_parent().get_node_or_null("StreetLamps")
            if lamps != null:
                lamps.call("register_cell", best_cell, chunk)
        return
    # Recursos extras são apenas preparados aqui; não entram na árvore no
    # mesmo frame em que terminam a leitura. Isso evita pico de CPU/GPU.
    if loaded_cells.is_empty():
        return
    for entry in EXTRA_SCENES:
        var entry_name: String = entry["name"]
        if not pending_extras.has(entry_name):
            continue
        var path: String = pending_extras[entry_name]
        var status := ResourceLoader.load_threaded_get_status(path)
        if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            pending_extras.erase(entry_name)
            push_warning("Falha ao carregar modelo: %s" % path)
            continue
        if status != ResourceLoader.THREAD_LOAD_LOADED:
            continue
        pending_extras.erase(entry_name)
        var scene := ResourceLoader.load_threaded_get(path) as PackedScene
        if scene != null:
            prepared_extras[entry_name] = scene
        return

func _activate_one_prepared_extra() -> void:
    if prepared_extras.is_empty() or not is_instance_valid(player):
        return
    var current_pos := _player_world_position()
    for entry in EXTRA_SCENES:
        var entry_name: String = entry["name"]
        if not prepared_extras.has(entry_name) or loaded_extras.has(entry_name):
            continue
        var dist: float = Vector2(current_pos.x,current_pos.z).distance_to(entry["point"])
        var is_vehicle_scene: bool = (
            entry_name.contains("BMW") or entry_name.contains("Mercedes") or
            entry_name.contains("FordF150") or entry_name.contains("Blindado") or
            entry_name.contains("Urus") or entry_name.contains("Duster") or
            entry_name.contains("Hammer") or entry_name.contains("Caminhao")
        )
        var warm_radius: float = float(entry["radius"]) + (115.0 if is_vehicle_scene else 35.0)
        if dist > warm_radius:
            continue

        var scene := prepared_extras[entry_name] as PackedScene
        prepared_extras.erase(entry_name)
        if scene == null:
            return
        var object := scene.instantiate() as Node3D
        if object == null:
            return
        object.name = entry_name
        if entry.has("position"):
            object.position = entry["position"]
        if entry.has("vehicle_name"):
            object.set("vehicle_name",entry["vehicle_name"])
        get_parent().add_child(object)
        loaded_extras[entry_name] = object
        return
