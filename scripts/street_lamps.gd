extends Node3D
## Postes das esquinas, agrupados por setor de cidade.
## Multimesh combina as hastes e luminarias; ate 8 OmniLight3D SEM sombras
## funcionam somente perto do jogador, evitando centenas de luzes simultaneas.

const CELL_SIZE: float = 320.0
const BLOCK_SIZE: float = 160.0
const SIDEWALK_INSET: float = 16.0
const WORLD_EDGE: float = 1212.0
const SCAN_INTERVAL: float = 0.40
const MAX_REAL_LIGHTS: int = 8
const ACTIVE_RADIUS_SQUARED: float = 70.0 * 70.0

var player: Node3D
var cells: Dictionary = {}  # Vector2i -> Array[Dictionary] (posicao da cabeca)
var light_pool: Array[OmniLight3D] = []
var scan_elapsed: float = SCAN_INTERVAL
var night_level: float = 0.0
var pole_mesh: BoxMesh
var arm_mesh: BoxMesh
var cover_mesh: BoxMesh
var bulb_mesh: BoxMesh
var bulb_material: StandardMaterial3D

func _ready() -> void:
    player = get_parent().get_node_or_null("Player") as Node3D
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.17, 0.20, 0.22)
    metal.metallic = 0.48
    metal.roughness = 0.46
    var bulb := StandardMaterial3D.new()
    bulb.albedo_color = Color(1.0, 0.90, 0.62)
    bulb.emission_enabled = true
    bulb.emission = Color(1.0, 0.73, 0.37)
    bulb.emission_energy_multiplier = 0.0
    bulb_material = bulb
    pole_mesh = _box(Vector3(0.22, 6.3, 0.22), metal)
    arm_mesh = _box(Vector3(3.6, 0.14, 0.18), metal)
    cover_mesh = _box(Vector3(0.94, 0.22, 0.66), metal)
    bulb_mesh = _box(Vector3(0.60, 0.08, 0.40), bulb)
    for i in range(MAX_REAL_LIGHTS):
        var lamp := OmniLight3D.new()
        lamp.name = "LuzUrbana_%02d" % i
        lamp.light_color = Color(1.0, 0.79, 0.52)
        lamp.light_energy = 0.0
        lamp.omni_range = 28.0
        lamp.omni_attenuation = 1.2
        lamp.shadow_enabled = false
        lamp.visible = false
        add_child(lamp)
        light_pool.append(lamp)

func _box(size: Vector3, material: Material) -> BoxMesh:
    var result := BoxMesh.new()
    result.size = size
    result.material = material
    return result

func _instance_mesh(chunk: Node3D, label_name: String, source_mesh: Mesh, positions: Array[Transform3D]) -> void:
    if positions.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = source_mesh
    multi.instance_count = positions.size()
    for i in range(positions.size()):
        multi.set_instance_transform(i, positions[i])
    var renderer := MultiMeshInstance3D.new()
    renderer.name = label_name
    renderer.multimesh = multi
    renderer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    renderer.visibility_range_end = 260.0
    chunk.add_child(renderer)

func register_cell(cell: Vector2i, chunk: Node3D) -> void:
    if cells.has(cell):
        return
    var pole_transforms: Array[Transform3D] = []
    var arm_transforms: Array[Transform3D] = []
    var cover_transforms: Array[Transform3D] = []
    var bulb_transforms: Array[Transform3D] = []
    var lights: Array[Vector3] = []
    # Uma luminaria em cada um dos quatro cantos de cada quadra de 160 m.
    # Ao passar de um setor a outro, as celulas tem cantos exclusivos.
    for block_x in range(2):
        for block_z in range(2):
            var block_origin_x: float = float(cell.x) * CELL_SIZE + float(block_x) * BLOCK_SIZE
            var block_origin_z: float = float(cell.y) * CELL_SIZE + float(block_z) * BLOCK_SIZE
            for corner_x in range(2):
                for corner_z in range(2):
                    var x: float = block_origin_x + (SIDEWALK_INSET if corner_x == 0 else BLOCK_SIZE - SIDEWALK_INSET)
                    var z: float = block_origin_z + (SIDEWALK_INSET if corner_z == 0 else BLOCK_SIZE - SIDEWALK_INSET)
                    if absf(x) > WORLD_EDGE or absf(z) > WORLD_EDGE:
                        continue
                    # Bases de serviço usam iluminação própria. Evita postes urbanos atravessando os lotes.
                    if x >= -790.0 and x <= -650.0 and z >= -790.0 and z <= -650.0:
                        continue
                    # Hospital Santa Luz: lote centralizado em (240, -224), com margem para calçada/garagem.
                    if x >= 196.0 and x <= 284.0 and z >= -260.0 and z <= -188.0:
                        continue
                    # Base do Exército: lote reformado em (880, 946), mantendo a rua norte livre.
                    # A iluminação urbana não deve atravessar o pátio, garagens ou área de treinamento militar.
                    if x >= 810.0 and x <= 950.0 and z >= 912.0 and z <= 1032.0:
                        continue
                    # Parque + concessionária da quadra inicial usam iluminação própria e organizada.
                    # Mantém os postes urbanos fora de calçadas, estacionamento e gramado do parque.
                    if x >= 16.0 and x <= 150.0 and z >= 16.0 and z <= 150.0:
                        continue
                    var arm_direction: float = -1.0 if corner_x == 0 else 1.0
                    var post := Vector3(x, 0.14, z)
                    pole_transforms.append(Transform3D(Basis.IDENTITY, post + Vector3(0.0, 3.15, 0.0)))
                    arm_transforms.append(Transform3D(Basis.IDENTITY, post + Vector3(arm_direction * 1.85, 6.26, 0.0)))
                    cover_transforms.append(Transform3D(Basis.IDENTITY, post + Vector3(arm_direction * 3.65, 6.17, 0.0)))
                    bulb_transforms.append(Transform3D(Basis.IDENTITY, post + Vector3(arm_direction * 3.65, 6.02, 0.0)))
                    lights.append(post + Vector3(arm_direction * 3.65, 5.93, 0.0))
    # Os quatro desenhos sao agrupados, sem um Node3D por poste.
    _instance_mesh(chunk, "Postes_Hastes", pole_mesh, pole_transforms)
    _instance_mesh(chunk, "Postes_Bracos", arm_mesh, arm_transforms)
    _instance_mesh(chunk, "Postes_Coberturas", cover_mesh, cover_transforms)
    _instance_mesh(chunk, "Postes_Lampadas", bulb_mesh, bulb_transforms)
    cells[cell] = lights
    scan_elapsed = SCAN_INTERVAL

func unregister_cell(cell: Vector2i) -> void:
    cells.erase(cell)
    scan_elapsed = SCAN_INTERVAL

func set_night_level(value: float) -> void:
    night_level = clampf(value, 0.0, 1.0)
    if bulb_material != null:
        bulb_material.emission_energy_multiplier = night_level * 1.8
    if night_level <= 0.05:
        for lamp in light_pool:
            lamp.visible = false
        return
    for lamp in light_pool:
        if lamp.visible:
            lamp.light_energy = night_level * 1.55

func _process(delta: float) -> void:
    scan_elapsed += delta
    if scan_elapsed < SCAN_INTERVAL:
        return
    scan_elapsed = 0.0
    if not is_instance_valid(player) or night_level <= 0.05:
        return
    var p: Vector3 = player.global_position
    var vehicle: Node = player.get("vehicle") as Node
    if is_instance_valid(vehicle) and vehicle is Node3D:
        p = (vehicle as Node3D).global_position
    var options: Array[Dictionary] = []
    for list_of_posts in cells.values():
        for post_position in list_of_posts:
            var lamp_position: Vector3 = post_position
            var squared_distance: float = p.distance_squared_to(lamp_position)
            if squared_distance <= ACTIVE_RADIUS_SQUARED:
                options.append({"position": lamp_position, "distance": squared_distance})
    options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
    for i in range(light_pool.size()):
        var lamp: OmniLight3D = light_pool[i]
        if i < options.size():
            lamp.global_position = options[i]["position"]
            lamp.light_energy = night_level * 1.55
            lamp.visible = true
        else:
            lamp.visible = false
