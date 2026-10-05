extends Node3D
## Runtime editor data: separate from streamed scenes so saved placements survive unloading.
## res:// stores development defaults; user:// stores edits made in exported builds.
const PROJECT_FILE := "res://world_edits.json"
const USER_FILE := "user://world_edits_v013.json"
const TYPES: Array[String] = ["predio", "casa", "arvore", "montanha", "rocha", "poste", "muro", "cerca", "placa", "banco", "barreira", "caixa", "cone"]
var created: Dictionary = {} # stable object id -> saved description
var changed: Dictionary = {} # stable existing scene path -> saved local transform/visibility
var world: Node3D
var city: Node3D
var scan_clock: float = 0.0
var next_id: int = 1

func _ready() -> void:
    world = Node3D.new()
    world.name = "ObjetosEditados"
    get_parent().call_deferred("add_child", world)
    city = get_parent().get_node_or_null("Cidade") as Node3D
    _load()
    call_deferred("_restore_created")

func _load() -> void:
    var source: String = USER_FILE if FileAccess.file_exists(USER_FILE) else PROJECT_FILE
    if not FileAccess.file_exists(source):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
    if not (raw is Dictionary):
        return
    var loaded_created: Variant = raw.get("created", {})
    var loaded_changed: Variant = raw.get("changed", {})
    created = {}
    changed = {}
    if loaded_created is Dictionary:
        created = loaded_created
    if loaded_changed is Dictionary:
        changed = loaded_changed
    next_id = maxi(1, int(raw.get("next_id", 1)))

func _process(delta: float) -> void:
    scan_clock += delta
    if scan_clock < 1.0 or city == null:
        return
    scan_clock = 0.0
    # Apply to each streamed chunk after its scene is instantiated; cache makes
    # this idempotent and prevents overwriting unsaved live edits every second.
    for chunk in city.get_children():
        if chunk is Node3D and chunk.get_meta("world_edit_applied", false) == false:
            _apply_to_chunk(chunk)
            chunk.set_meta("world_edit_applied", true)
    # Imported districts and standalone buildings are streamed at main-scene level.
    for extra in get_parent().get_children():
        if extra is Node3D and extra != self and extra != city and extra != world and not (extra is VehicleBody3D) and extra.scene_file_path != "" and not extra.get_meta("world_edit_applied", false):
            _apply_to_chunk(extra)
            extra.set_meta("world_edit_applied", true)

func _apply_to_chunk(chunk: Node) -> void:
    for key in changed.keys():
        var prefix: String = String(chunk.name) + "|"
        if not String(key).begins_with(prefix):
            continue
        var relative: String = String(key).substr(prefix.length())
        var target: Node3D = chunk.get_node_or_null(NodePath(relative)) as Node3D
        if target != null:
            apply_data(target, changed[key])

func key_of(target: Node3D) -> String:
    if target == null or not is_instance_valid(target) or city == null:
        return ""
    var root: Node = target
    var scene_root: Node = get_parent()
    while root != null and root.get_parent() != city and root.get_parent() != scene_root:
        root = root.get_parent()
    if root == null or root == city or root == self or root == world or root == target.get_tree().current_scene:
        return ""
    if root.get_parent() == scene_root:
        # Do not expose Player, WorldStreamer, lights, vehicles or the ground as
        # standalone building objects; only imported individual scene roots.
        if root is VehicleBody3D or root.scene_file_path == "" or String(root.name) in ["Player", "Cidade", "WorldStreamer", "WorldEditStore", "StreetLamps", "BrasiliaDayNight"]:
            return ""
    if target == root:
        return "%s|." % String(root.name)
    return "%s|%s" % [String(root.name), str(root.get_path_to(target))]

func _vec(v: Vector3) -> Array:
    return [snappedf(v.x, 0.001), snappedf(v.y, 0.001), snappedf(v.z, 0.001)]

func _read_vec(v: Variant, default: Vector3) -> Vector3:
    if v is Array and v.size() == 3:
        return Vector3(float(v[0]), float(v[1]), float(v[2]))
    return default

func capture(target: Node3D) -> Dictionary:
    return {"pos": _vec(target.position), "rot": _vec(target.rotation_degrees), "size": _vec(target.scale), "visible": target.visible}

func apply_data(target: Node3D, data: Dictionary) -> void:
    target.position = _read_vec(data.get("pos", []), target.position)
    target.rotation_degrees = _read_vec(data.get("rot", []), target.rotation_degrees)
    target.scale = _read_vec(data.get("size", []), target.scale)
    set_visible_state(target, bool(data.get("visible", true)))

func set_visible_state(target: Node3D, value: bool) -> void:
    target.visible = value
    # Hiding a building must also disable its physical walls, otherwise
    # the player would collide with an invisible object after an edit.
    for collider in target.find_children("*", "CollisionShape3D", true, false):
        (collider as CollisionShape3D).set_deferred("disabled", not value)

func remember_existing(target: Node3D) -> bool:
    var key: String = key_of(target)
    if key.is_empty():
        return false
    changed[key] = capture(target)
    return true

func forget_existing(target: Node3D) -> void:
    var key: String = key_of(target)
    changed.erase(key)

func add_object(kind: String, location: Vector3) -> Node3D:
    if not TYPES.has(kind) or world == null or not is_instance_valid(world):
        return null
    var object_id: String = "obj_%06d" % next_id
    next_id += 1
    var item: Node3D = _make_object(kind)
    item.name = object_id
    item.set_meta("world_editor_kind", kind)
    world.add_child(item)
    item.global_position = location
    created[object_id] = {"kind": kind, "transform": capture(item)}
    return item

func remember_created(item: Node3D) -> void:
    if not item.is_inside_tree() or not item.get_parent() == world:
        return
    var object_id: String = String(item.name)
    if created.has(object_id):
        var info: Dictionary = created[object_id]
        info["transform"] = capture(item)
        created[object_id] = info

func remove_created(item: Node3D) -> bool:
    if item == null or item.get_parent() != world:
        return false
    created.erase(String(item.name))
    item.queue_free()
    return true

func _restore_created() -> void:
    if world == null or not is_instance_valid(world):
        return
    for object_id in created.keys():
        var info: Dictionary = created[object_id]
        var kind: String = String(info.get("kind", ""))
        if not TYPES.has(kind):
            continue
        var item: Node3D = _make_object(kind)
        item.name = String(object_id)
        item.set_meta("world_editor_kind", kind)
        world.add_child(item)
        apply_data(item, info.get("transform", {}))

func save() -> Dictionary:
    var text_json: String = JSON.stringify({"version": 1, "created": created, "changed": changed, "next_id": next_id}, "  ")
    var user_err: int = _write(USER_FILE, text_json)
    var project_err: int = _write(PROJECT_FILE, text_json) if OS.has_feature("editor") or OS.has_feature("standalone") else ERR_UNAVAILABLE
    return {"local": user_err, "project": project_err}

func _write(path: String, contents: String) -> int:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(contents)
    var result: int = file.get_error()
    file.close()
    return result

func _mesh(body: Node3D, name_value: String, mesh: Mesh, color: Color, pos: Vector3) -> void:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.93
    var visual := MeshInstance3D.new()
    visual.name = name_value
    visual.mesh = mesh
    visual.material_override = material
    visual.position = pos
    body.add_child(visual)

func _solid_box(root: StaticBody3D, label: String, box_size: Vector3, at: Vector3, color: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = box_size
    _mesh(root, label, mesh, color, at)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = box_size
    shape.shape = box
    shape.position = at
    root.add_child(shape)

func _make_object(kind: String) -> Node3D:
    var body := StaticBody3D.new()
    body.collision_layer = 1
    body.collision_mask = 1
    match kind:
        "predio":
            _solid_box(body, "Predio", Vector3(9.0, 19.0, 9.0), Vector3(0, 9.5, 0), Color("738ca1"))
            for floor_index in range(1, 6):
                for side in [-1, 1]:
                    var glass := BoxMesh.new()
                    glass.size = Vector3(1.8, 1.3, 0.055)
                    _mesh(body, "Janela", glass, Color("467f9e"), Vector3(float(side) * 2.25, float(floor_index) * 3.0, -4.53))
        "casa":
            _solid_box(body, "Casa", Vector3(8, 5, 7), Vector3(0, 2.5, 0), Color("b5ada1"))
            _solid_box(body, "Telhado", Vector3(8.6, 0.40, 7.6), Vector3(0, 5.15, 0), Color("883b45"))
        "arvore":
            var trunk := CylinderMesh.new()
            trunk.top_radius = 0.36
            trunk.bottom_radius = 0.50
            trunk.height = 4.6
            trunk.radial_segments = 8
            _mesh(body, "Tronco", trunk, Color("73503a"), Vector3(0, 2.3, 0))
            var crown := SphereMesh.new()
            crown.radius = 2.25
            crown.height = 4.5
            crown.radial_segments = 10
            crown.rings = 5
            _mesh(body, "Copa", crown, Color("2c693d"), Vector3(0, 5.5, 0))
            var shape := CollisionShape3D.new()
            var capsule := CapsuleShape3D.new()
            capsule.radius = 0.48
            capsule.height = 4.7
            shape.shape = capsule
            shape.position.y = 2.35
            body.add_child(shape)
        "montanha":
            var peak := CylinderMesh.new()
            peak.top_radius = 0.0
            peak.bottom_radius = 16.0
            peak.height = 27.0
            peak.radial_segments = 7
            _mesh(body, "Montanha", peak, Color("746f61"), Vector3(0, 13.5, 0))
            var terrain := CollisionShape3D.new()
            var shape := CylinderShape3D.new()
            shape.radius = 11.5
            shape.height = 15.0
            terrain.shape = shape
            terrain.position.y = 7.5
            body.add_child(terrain)
        "rocha":
            var rock := SphereMesh.new()
            rock.radius = 2.0
            rock.height = 3.2
            rock.radial_segments = 7
            rock.rings = 4
            _mesh(body, "Rocha", rock, Color("88847d"), Vector3(0, 1.4, 0))
            var shape := CollisionShape3D.new()
            var sphere := SphereShape3D.new()
            sphere.radius = 1.6
            shape.shape = sphere
            shape.position.y = 1.4
            body.add_child(shape)
        "poste":
            _solid_box(body, "Poste", Vector3(0.22, 6.0, 0.22), Vector3(0, 3, 0), Color("525d6a"))
            _solid_box(body, "Luminaria", Vector3(1.4, 0.17, 0.55), Vector3(0.6, 6.1, 0), Color("f5e4ae"))
        "muro":
            _solid_box(body, "Muro", Vector3(8.0, 2.4, 0.28), Vector3(0, 1.2, 0), Color("9a9b96"))
        "cerca":
            _solid_box(body, "BaseCerca", Vector3(8.0, 0.16, 0.18), Vector3(0, 0.15, 0), Color("59636d"))
            for x in [-3.8, -1.9, 0.0, 1.9, 3.8]:
                _solid_box(body, "Haste", Vector3(0.10, 2.2, 0.10), Vector3(float(x), 1.1, 0), Color("697781"))
            for y in [0.65, 1.2, 1.75]:
                _solid_box(body, "Travessa", Vector3(8.0, 0.07, 0.07), Vector3(0, float(y), 0), Color("697781"))
        "placa":
            _solid_box(body, "Haste", Vector3(0.12, 2.5, 0.12), Vector3(0, 1.25, 0), Color("59636d"))
            _solid_box(body, "Placa", Vector3(1.6, 0.85, 0.10), Vector3(0, 2.25, 0), Color("3f79a5"))
        "banco":
            _solid_box(body, "Assento", Vector3(2.2, 0.18, 0.65), Vector3(0, 0.62, 0), Color("71513c"))
            _solid_box(body, "Encosto", Vector3(2.2, 0.85, 0.16), Vector3(0, 1.02, 0.28), Color("71513c"))
            _solid_box(body, "PeEsq", Vector3(0.16, 0.62, 0.50), Vector3(-0.78, 0.31, 0), Color("4d545b"))
            _solid_box(body, "PeDir", Vector3(0.16, 0.62, 0.50), Vector3(0.78, 0.31, 0), Color("4d545b"))
        "barreira":
            _solid_box(body, "Barreira", Vector3(2.7, 0.85, 0.65), Vector3(0, 0.425, 0), Color("d4a43d"))
        "caixa":
            _solid_box(body, "Caixa", Vector3(1.15, 1.15, 1.15), Vector3(0, 0.575, 0), Color("8a6546"))
        "cone":
            var cone := CylinderMesh.new()
            cone.top_radius = 0.08
            cone.bottom_radius = 0.38
            cone.height = 0.90
            cone.radial_segments = 10
            _mesh(body, "Cone", cone, Color("e56b2e"), Vector3(0, 0.45, 0))
            var cone_shape := CollisionShape3D.new()
            var cone_collision := CylinderShape3D.new()
            cone_collision.radius = 0.34
            cone_collision.height = 0.90
            cone_shape.shape = cone_collision
            cone_shape.position.y = 0.45
            body.add_child(cone_shape)
    return body
