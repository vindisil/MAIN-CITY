extends Node3D
## v0.0.2 — estacao ferroviaria leve e exploravel baseada nas texturas do pacote enviado.
## O arquivo de origem .blend pode ser exportado posteriormente para GLB e substituir
## este modelo substituto. Esta cena nao simula trens ou viagens.
const BASE_PATH: String = "res://assets/v002_estacao_tram/"
var batches: Dictionary = {} # material name -> {"mesh": BoxMesh, "transforms": Array[Transform3D]}
var materials: Dictionary = {}

func _ready() -> void:
    materials["concrete"] = _mat("concrete.png", Color(0.86, 0.85, 0.80))
    materials["platform"] = _mat("perron.png", Color(0.85, 0.85, 0.84))
    materials["gravel"] = _mat("gravel.png", Color(0.65, 0.65, 0.63))
    materials["rail"] = _mat("railtracks.png", Color(0.67, 0.70, 0.72))
    materials["wall"] = _mat("t_modular.png", Color(0.90, 0.92, 0.92))
    var steel := StandardMaterial3D.new()
    steel.albedo_color = Color(0.21, 0.24, 0.27)
    steel.metallic = 0.56
    steel.roughness = 0.47
    materials["steel"] = steel
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color(0.40, 0.67, 0.74, 0.68)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.roughness = 0.18
    glass.metallic = 0.12
    materials["glass"] = glass
    var sign := StandardMaterial3D.new()
    sign.albedo_color = Color(0.04, 0.16, 0.30)
    sign.roughness = 0.70
    materials["sign"] = sign
    var yellow := StandardMaterial3D.new()
    yellow.albedo_color = Color(0.98, 0.79, 0.17)
    yellow.roughness = 0.80
    materials["yellow"] = yellow
    # Yard/track bed and two accessible side platforms, in a 124 m reserved urban lot.
    _box("concrete", Vector3(0.0, 0.12, 0.0), Vector3(118.0, 0.24, 117.0), true)
    for track_z in [-7.0, 7.0]:
        _box("gravel", Vector3(0.0, 0.28, track_z), Vector3(115.0, 0.22, 4.6))
        for rail_z in [-0.86, 0.86]:
            _box("steel", Vector3(0.0, 0.48, track_z + rail_z), Vector3(115.0, 0.12, 0.13))
        for i in range(54):
            _box("rail", Vector3(-55.0 + float(i) * 2.05, 0.34, track_z), Vector3(0.30, 0.13, 3.50))
    for side in [-1.0, 1.0]:
        var z: float = side * 24.0
        _box("platform", Vector3(0.0, 0.50, z), Vector3(110.0, 0.76, 12.0), true)
        _box("yellow", Vector3(0.0, 0.90, z - side * 5.55), Vector3(109.0, 0.03, 0.20))
        # lightweight roof and beams: group by material, no real-time light nodes.
        _box("steel", Vector3(0.0, 5.20, z), Vector3(106.0, 0.24, 10.5))
        _box("wall", Vector3(0.0, 5.36, z), Vector3(107.0, 0.16, 11.8))
        for k in range(10):
            var px: float = -48.0 + float(k) * 10.5
            for rz in [-3.8, 3.8]:
                _box("steel", Vector3(px, 2.95, z + rz), Vector3(0.22, 4.5, 0.24))
            if k % 2 == 0:
                _bench(Vector3(px + 3.0, 0.95, z + side * 2.5))
    # Ticket hall, doors open on platform side; avoid a big invisible collision wall.
    _box("concrete", Vector3(0.0, 0.60, 45.0), Vector3(53.0, 0.82, 24.0), true)
    _box("wall", Vector3(0.0, 6.40, 45.0), Vector3(55.0, 0.45, 25.0))
    for x in [-26.0, 26.0]:
        _box("wall", Vector3(x, 3.35, 45.0), Vector3(0.65, 5.8, 24.0), true)
    _box("wall", Vector3(0.0, 3.35, 56.5), Vector3(53.0, 5.8, 0.65), true)
    for x in [-17.0, 17.0]:
        _box("wall", Vector3(x, 3.35, 33.5), Vector3(18.0, 5.8, 0.65), true)
    _box("glass", Vector3(0.0, 4.20, 33.6), Vector3(15.0, 3.4, 0.08))
    _box("sign", Vector3(0.0, 6.80, 33.28), Vector3(23.0, 1.80, 0.16))
    # Raised entrance platform and clock / signs (visual only).
    _box("platform", Vector3(0.0, 0.40, 30.0), Vector3(16.0, 0.5, 7.5), true)
    _box("wall", Vector3(0.0, 9.25, 45.0), Vector3(8.0, 6.0, 8.0))
    _box("sign", Vector3(0.0, 9.5, 40.94), Vector3(4.2, 3.7, 0.12))
    _sign("ESTACAO DE TREM", Vector3(0.0, 6.77, 33.12), 0.56)
    _sign("ESTAÇÃO CENTRAL", Vector3(0.0, 9.45, 40.86), 0.30)
    for side in [-1.0, 1.0]:
        _box("sign", Vector3(-2.0, 3.45, side * 24.0), Vector3(5.2, 1.15, 0.14))
        _sign("PLATAFORMA %d" % (1 if side < 0 else 2), Vector3(-2.0, 3.45, side * 24.0 + (0.12 if side < 0 else -0.12)), 0.33)
    _render_batches()

func _mat(file: String, tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.albedo_texture = load(BASE_PATH + file) as Texture2D
    mat.roughness = 0.89
    mat.uv1_triplanar = true
    mat.uv1_world_triplanar = true
    mat.uv1_scale = Vector3(0.40, 0.40, 0.40)
    return mat

func _box(material_name: String, center: Vector3, size: Vector3, solid: bool = false) -> void:
    var key: String = material_name
    if not batches.has(key):
        batches[key] = []
    # MultiMesh has one 1-m BoxMesh per material with scale in each Transform3D.
    var transform := Transform3D(Basis.from_scale(size), center)
    batches[key].append(transform)
    if solid:
        var collider := StaticBody3D.new()
        collider.name = "Colisao_%s" % material_name
        add_child(collider)
        var shape := CollisionShape3D.new()
        var block := BoxShape3D.new()
        block.size = size
        shape.shape = block
        shape.position = center
        collider.add_child(shape)

func _bench(where: Vector3) -> void:
    _box("steel", where + Vector3(0.0, 0.20, 0.0), Vector3(2.5, 0.14, 0.62))
    _box("wall", where + Vector3(0.0, 0.56, 0.24), Vector3(2.5, 0.82, 0.12))
    for dx in [-1.0, 1.0]:
        _box("steel", where + Vector3(dx, -0.27, 0.0), Vector3(0.12, 0.83, 0.12))

func _sign(message: String, where: Vector3, pixel: float) -> void:
    var board := Label3D.new()
    board.name = "Placa"
    board.text = message
    board.pixel_size = pixel * 0.015
    board.font_size = 64
    board.modulate = Color(1.0, 0.96, 0.85)
    board.no_depth_test = false
    board.billboard = BaseMaterial3D.BILLBOARD_DISABLED
    board.position = where
    board.visibility_range_end = 120.0
    add_child(board)

func _render_batches() -> void:
    for key in batches.keys():
        var mesh := BoxMesh.new()
        mesh.size = Vector3.ONE
        mesh.material = materials[key]
        var transforms: Array = batches[key]
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.mesh = mesh
        batch.instance_count = transforms.size()
        for i in range(transforms.size()):
            batch.set_instance_transform(i, transforms[i])
        var instance := MultiMeshInstance3D.new()
        instance.name = "Lote_%s" % key
        instance.multimesh = batch
        instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        instance.visibility_range_end = 340.0
        add_child(instance)
