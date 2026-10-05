extends Node3D
## Adaptador visual unico do personagem Main City para o pacote Third Person Shooter.

const CANONICAL_CHARACTER_HEIGHT: float = 2.45
const COLOR_MASCULINO := Color(0.92, 0.12, 0.10, 1.0)
const COLOR_FEMININO := Color(1.0, 0.28, 0.58, 1.0)
const COLOR_POLICIA := Color(0.08, 0.28, 0.95, 1.0)
const COLOR_MEDICO := Color(1.0, 0.78, 0.08, 1.0)
const COLOR_MILITAR := Color(0.18, 0.72, 0.20, 1.0)
const MotionScript = preload("res://scripts/third_person_motion.gd")

var character_model: Node3D = null
var motion_ready: bool = false
var motion_driver: Node = null
# Alias mantido apenas para o sistema de tiro consultar aim_weight/recoil.
var weapon_animator: Node = null
var police_mode: bool = false
var medical_mode: bool = false
var military_mode: bool = false

var motion_speed: float = 0.0
var motion_input: Vector2 = Vector2.ZERO
var motion_sprinting: bool = false
var motion_crouched: bool = false
var motion_rolling: bool = false
var motion_roll_progress: float = -1.0
var motion_armed: bool = false

func _ready() -> void:
    character_model = self
    _fit_character_to_main_city()
    var skeleton := get_pose_skeleton()
    if skeleton != null:
        motion_driver = MotionScript.new()
        motion_driver.name = "ThirdPersonMotion"
        skeleton.add_child(motion_driver)
        if motion_driver.has_method("setup"):
            motion_driver.call("setup", self)
        weapon_animator = motion_driver
        motion_ready = bool(motion_driver.get("animation_ready"))
    else:
        push_error("Main City Third Person: GeneralSkeleton nao encontrado.")

    var state := get_node_or_null("/root/GameState")
    police_mode = state != null and bool(state.get("is_police"))
    medical_mode = state != null and bool(state.get("is_medic"))
    military_mode = state != null and bool(state.get("is_military"))
    _apply_main_city_color()

func get_pose_skeleton() -> Skeleton3D:
    return get_node_or_null("GeneralSkeleton") as Skeleton3D

func set_motion(speed: float, armed: bool, running_requested: bool = false, _delta: float = 0.016, input_vector: Vector2 = Vector2.ZERO, crouched: bool = false, rolling: bool = false, roll_progress: float = -1.0) -> void:
    motion_speed = maxf(0.0, speed)
    motion_armed = armed
    motion_sprinting = running_requested
    motion_input = input_vector
    motion_crouched = crouched
    motion_rolling = rolling
    motion_roll_progress = roll_progress

func update_pose(_delta: float, aimed: bool, _direction: Vector3, weapon: int, airborne: bool, vertical_speed: float, _landing: float, reload_progress: float = -1.0, switch_progress: float = -1.0) -> void:
    if motion_driver == null or not motion_driver.has_method("set_state"):
        motion_ready = false
        return
    motion_driver.call(
        "set_state",
        motion_speed,
        motion_input,
        motion_sprinting,
        motion_crouched,
        motion_rolling,
        motion_roll_progress,
        motion_armed,
        aimed,
        weapon,
        airborne,
        vertical_speed,
        reload_progress,
        switch_progress
    )
    motion_ready = bool(motion_driver.get("animation_ready"))

func set_police_mode(enabled: bool) -> void:
    police_mode = enabled
    if enabled:
        medical_mode = false
        military_mode = false
    _apply_main_city_color()

func set_medical_mode(enabled: bool) -> void:
    medical_mode = enabled
    if enabled:
        police_mode = false
        military_mode = false
    _apply_main_city_color()

func set_military_mode(enabled: bool) -> void:
    military_mode = enabled
    if enabled:
        police_mode = false
        medical_mode = false
    _apply_main_city_color()

func _selected_gender() -> String:
    var state := get_node_or_null("/root/GameState")
    if state == null:
        return "masculino"
    var value := String(state.get("selected_gender"))
    return value if value in ["masculino", "feminino"] else "masculino"

func _main_city_tint() -> Color:
    if police_mode: return COLOR_POLICIA
    if medical_mode: return COLOR_MEDICO
    if military_mode: return COLOR_MILITAR
    return COLOR_FEMININO if _selected_gender() == "feminino" else COLOR_MASCULINO

func _apply_main_city_color() -> void:
    var skeleton := get_pose_skeleton()
    if skeleton == null:
        return
    var tint := _main_city_tint()
    for item in skeleton.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := item as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var source := mesh_instance.get_active_material(surface_index)
            if source is StandardMaterial3D:
                var material := (source as StandardMaterial3D).duplicate() as StandardMaterial3D
                material.albedo_color = tint
                material.roughness = 0.72
                material.metallic = 0.0
                mesh_instance.set_surface_override_material(surface_index, material)

func _visual_bounds() -> AABB:
    var low := Vector3(INF, INF, INF)
    var high := Vector3(-INF, -INF, -INF)
    var inv := global_transform.affine_inverse()
    for item in find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := item as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        var box: AABB = mesh_instance.get_aabb()
        var local_from_mesh: Transform3D = inv * mesh_instance.global_transform
        for corner in range(8):
            var point: Vector3 = local_from_mesh * box.get_endpoint(corner)
            low = low.min(point)
            high = high.max(point)
    if not is_finite(low.x) or not is_finite(high.x):
        return AABB(Vector3.ZERO, Vector3.ZERO)
    return AABB(low, high - low)

func _fit_character_to_main_city() -> void:
    scale = Vector3.ONE
    position = Vector3.ZERO
    var before := _visual_bounds()
    if before.size.y > 0.01:
        var factor: float = CANONICAL_CHARACTER_HEIGHT / before.size.y
        scale = Vector3.ONE * factor
        position.y = -before.position.y * factor
