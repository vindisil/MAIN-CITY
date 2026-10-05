extends Node3D
## Editor-only vehicle placements: saved separately from the streamed city.
## Spawns are always complete driveable scenes, not decorative meshes.
const PROJECT_FILE := "res://vehicle_edits.json"
const USER_FILE := "user://vehicle_edits_v013.json"
const MODELS: Array[String] = [
    "res://scenes/v24_bmw.tscn",
    "res://scenes/v24_gls.tscn",
    "res://scenes/v30_6_raptor_dirigivel.tscn",
    "res://scenes/v0_0_1_raptor_policial.tscn",
    "res://scenes/v30_6_blindado_dirigivel.tscn",
    "res://scenes/v0_0_1_blindado_2.tscn",
    "res://scenes/v50_urus.tscn",
    "res://scenes/v51_duster_policia_dirigivel.tscn"
]
const LABELS: Array[String] = ["BMW", "MERCEDES GLS", "FORD RAPTOR", "RAPTOR POLICIAL", "BLINDADO", "BLINDADO 2", "URUS", "DUSTER POLICIAL"]
var spawned: Dictionary = {}
var parked: Dictionary = {}
var next_id: int = 1
var spawned_root: Node3D
var update_clock: float = 0.0

func _ready() -> void:
    spawned_root = Node3D.new()
    spawned_root.name = "VeiculosCriados"
    add_child(spawned_root)
    _load()
    call_deferred("_restore_spawned")

func _load() -> void:
    var source: String = USER_FILE if FileAccess.file_exists(USER_FILE) else PROJECT_FILE
    if not FileAccess.file_exists(source):
        return
    var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(source))
    if not (raw is Dictionary):
        return
    var loaded_spawned: Variant = raw.get("spawned", {})
    var loaded_parked: Variant = raw.get("parked", {})
    spawned = {}
    parked = {}
    if loaded_spawned is Dictionary:
        spawned = loaded_spawned
    if loaded_parked is Dictionary:
        parked = loaded_parked
    next_id = maxi(1, int(raw.get("next_id", 1)))

func _process(delta: float) -> void:
    update_clock += delta
    if update_clock < 0.35:
        return
    update_clock = 0.0
    # Vehicles appear after WorldStreamer adds them. Apply a parked position
    # once per instance (never continuously reset a car that has been driven).
    for item in get_tree().get_nodes_in_group("vehicle"):
        var car: VehicleBody3D = item as VehicleBody3D
        if car == null or car.is_queued_for_deletion():
            continue
        if car.get_meta("vehicle_edit_applied", false):
            continue
        car.set_meta("vehicle_edit_applied", true)
        var key: String = str(car.name)
        if car.get_parent() != spawned_root and parked.has(key) and car.get("driver") == null and not car.get_meta("has_been_driven", false):
            apply_data(car, parked[key])

func _finite_number(value: Variant, fallback: float) -> float:
    if not (value is int or value is float):
        return fallback
    var number: float = float(value)
    return number if is_finite(number) else fallback

func _vector_is_finite(value: Vector3) -> bool:
    return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)

func _transform_is_finite(value: Transform3D) -> bool:
    return _vector_is_finite(value.origin) and _vector_is_finite(value.basis.x) and _vector_is_finite(value.basis.y) and _vector_is_finite(value.basis.z)

func _remember_safe_transform(car: VehicleBody3D) -> void:
    if car == null or not is_instance_valid(car):
        return
    if _transform_is_finite(car.global_transform):
        car.set_meta("vehicle_edit_last_safe_transform", car.global_transform)

func ensure_vehicle_finite(car: VehicleBody3D) -> bool:
    if car == null or not is_instance_valid(car):
        return false
    var okay: bool = _transform_is_finite(car.global_transform)
    if not okay:
        var saved: Variant = car.get_meta("vehicle_edit_last_safe_transform", null)
        if saved is Transform3D and _transform_is_finite(saved as Transform3D):
            car.global_transform = saved as Transform3D
            car.linear_velocity = Vector3.ZERO
            car.angular_velocity = Vector3.ZERO
        else:
            # During world startup a rigid body may still be settling/importing.
            # Never teleport an uninitialized vehicle to the world origin.
            return false
    if not _vector_is_finite(car.linear_velocity):
        car.linear_velocity = Vector3.ZERO
    if not _vector_is_finite(car.angular_velocity):
        car.angular_velocity = Vector3.ZERO
    _remember_safe_transform(car)
    return okay

func _ensure_wheel_baseline(wheel: VehicleWheel3D) -> void:
    if wheel == null or not is_instance_valid(wheel):
        return
    if not wheel.has_meta("vehicle_edit_base_position") and _vector_is_finite(wheel.position):
        wheel.set_meta("vehicle_edit_base_position", wheel.position)
    if not wheel.has_meta("vehicle_edit_base_radius") and is_finite(wheel.wheel_radius) and wheel.wheel_radius > 0.001:
        wheel.set_meta("vehicle_edit_base_radius", wheel.wheel_radius)
    if not wheel.has_meta("vehicle_edit_base_rest") and is_finite(wheel.wheel_rest_length):
        wheel.set_meta("vehicle_edit_base_rest", wheel.wheel_rest_length)
    if not wheel.has_meta("vehicle_edit_base_travel") and is_finite(wheel.suspension_travel):
        wheel.set_meta("vehicle_edit_base_travel", wheel.suspension_travel)
    for child in wheel.get_children():
        if child is Node3D:
            var visual: Node3D = child as Node3D
            if not visual.has_meta("vehicle_edit_safe_scale") and _vector_is_finite(visual.scale):
                visual.set_meta("vehicle_edit_safe_scale", visual.scale)

func _repair_wheel(wheel: VehicleWheel3D) -> void:
    _ensure_wheel_baseline(wheel)
    if not _vector_is_finite(wheel.position):
        var base_pos: Variant = wheel.get_meta("vehicle_edit_base_position", Vector3.ZERO)
        wheel.position = base_pos as Vector3 if base_pos is Vector3 and _vector_is_finite(base_pos as Vector3) else Vector3.ZERO
    if not is_finite(wheel.wheel_radius) or wheel.wheel_radius <= 0.001:
        wheel.wheel_radius = _finite_number(wheel.get_meta("vehicle_edit_base_radius", 0.40), 0.40)
    if not is_finite(wheel.wheel_rest_length):
        wheel.wheel_rest_length = _finite_number(wheel.get_meta("vehicle_edit_base_rest", 0.22), 0.22)
    if not is_finite(wheel.suspension_travel):
        wheel.suspension_travel = _finite_number(wheel.get_meta("vehicle_edit_base_travel", 0.22), 0.22)
    for child in wheel.get_children():
        if child is Node3D:
            var visual: Node3D = child as Node3D
            if not _vector_is_finite(visual.scale):
                var safe_scale: Variant = visual.get_meta("vehicle_edit_safe_scale", Vector3.ONE)
                visual.scale = safe_scale as Vector3 if safe_scale is Vector3 and _vector_is_finite(safe_scale as Vector3) else Vector3.ONE

func _wheels(car: VehicleBody3D) -> Array[VehicleWheel3D]:
    var result: Array[VehicleWheel3D] = []
    if car == null or not is_instance_valid(car):
        return result
    for suffix in ["FL", "FR", "RL", "RR"]:
        var wheel: VehicleWheel3D = car.get_node_or_null("Wheel" + suffix) as VehicleWheel3D
        if wheel != null:
            _repair_wheel(wheel)
            result.append(wheel)
    return result

func wheel_metrics(car: VehicleBody3D) -> Dictionary:
    var wheels: Array[VehicleWheel3D] = _wheels(car)
    if wheels.is_empty():
        return {"suspension": 0.22, "travel": 0.22, "track": 1.9, "wheelbase": 3.0, "radius": 0.40}
    var suspension: float = 0.0
    var travel: float = 0.0
    var radius: float = 0.0
    var min_x: float = INF
    var max_x: float = -INF
    var front_z: float = 0.0
    var rear_z: float = 0.0
    var front_count: int = 0
    var rear_count: int = 0
    for wheel in wheels:
        suspension += wheel.wheel_rest_length
        travel += wheel.suspension_travel
        radius += wheel.wheel_radius
        min_x = minf(min_x, wheel.position.x)
        max_x = maxf(max_x, wheel.position.x)
        if wheel.use_as_steering:
            front_z += wheel.position.z
            front_count += 1
        else:
            rear_z += wheel.position.z
            rear_count += 1
    var count: float = float(wheels.size())
    var track: float = maxf(0.2, max_x - min_x)
    if front_count == 0 or rear_count == 0:
        var min_z: float = INF
        var max_z: float = -INF
        for wheel in wheels:
            min_z = minf(min_z, wheel.position.z)
            max_z = maxf(max_z, wheel.position.z)
        return {"suspension": suspension / count, "travel": travel / count, "track": track, "wheelbase": maxf(0.4, max_z - min_z), "radius": radius / count}
    return {
        "suspension": suspension / count,
        "travel": travel / count,
        "track": track,
        "wheelbase": maxf(0.4, absf(front_z / float(front_count) - rear_z / float(rear_count))),
        "radius": radius / count
    }

func apply_wheel_settings(car: VehicleBody3D, suspension: float, travel: float, track: float, wheelbase: float, radius: float) -> void:
    var wheels: Array[VehicleWheel3D] = _wheels(car)
    if wheels.is_empty():
        return
    suspension = clampf(_finite_number(suspension, 0.22), 0.03, 0.75)
    travel = clampf(_finite_number(travel, 0.22), 0.02, 0.80)
    track = clampf(_finite_number(track, 1.90), 0.75, 4.50)
    wheelbase = clampf(_finite_number(wheelbase, 3.00), 1.20, 6.50)
    radius = clampf(_finite_number(radius, 0.40), 0.20, 0.90)
    var center_x: float = 0.0
    var front_center_z: float = 0.0
    var rear_center_z: float = 0.0
    var front_count: int = 0
    var rear_count: int = 0
    for wheel in wheels:
        center_x += wheel.position.x
        if wheel.use_as_steering:
            front_center_z += wheel.position.z
            front_count += 1
        else:
            rear_center_z += wheel.position.z
            rear_count += 1
    center_x /= float(wheels.size())
    if front_count > 0:
        front_center_z /= float(front_count)
    if rear_count > 0:
        rear_center_z /= float(rear_count)
    var center_z: float = (front_center_z + rear_center_z) * 0.5 if front_count > 0 and rear_count > 0 else 0.0
    var front_sign: float = signf(front_center_z - rear_center_z) if front_count > 0 and rear_count > 0 else -1.0
    if is_zero_approx(front_sign):
        front_sign = -1.0
    for wheel in wheels:
        var old_radius: float = maxf(wheel.wheel_radius, 0.001)
        wheel.wheel_rest_length = suspension
        wheel.suspension_travel = travel
        var side_sign: float = signf(wheel.position.x - center_x)
        if is_zero_approx(side_sign):
            side_sign = -1.0 if str(wheel.name).ends_with("L") else 1.0
        wheel.position.x = center_x + side_sign * track * 0.5
        if front_count > 0 and rear_count > 0:
            wheel.position.z = center_z + (front_sign if wheel.use_as_steering else -front_sign) * wheelbase * 0.5
        if absf(radius - old_radius) > 0.0001:
            var radius_factor: float = radius / old_radius
            if not is_finite(radius_factor) or radius_factor <= 0.0:
                radius_factor = 1.0
            wheel.wheel_radius = radius
            for child in wheel.get_children():
                if child is Node3D:
                    var visual: Node3D = child as Node3D
                    var current_scale: Vector3 = visual.scale
                    if not _vector_is_finite(current_scale):
                        var stored_scale: Variant = visual.get_meta("vehicle_edit_safe_scale", Vector3.ONE)
                        current_scale = stored_scale as Vector3 if stored_scale is Vector3 and _vector_is_finite(stored_scale as Vector3) else Vector3.ONE
                    var next_scale: Vector3 = current_scale * radius_factor
                    if not _vector_is_finite(next_scale):
                        next_scale = current_scale
                    next_scale.x = clampf(next_scale.x, -500.0, 500.0)
                    next_scale.y = clampf(next_scale.y, -500.0, 500.0)
                    next_scale.z = clampf(next_scale.z, -500.0, 500.0)
                    visual.scale = next_scale
                    visual.set_meta("vehicle_edit_safe_scale", next_scale)

func capture(car: VehicleBody3D) -> Dictionary:
    var metrics: Dictionary = wheel_metrics(car)
    return {
        "pos": [snappedf(car.global_position.x, 0.001), snappedf(car.global_position.y, 0.001), snappedf(car.global_position.z, 0.001)],
        "rot": [snappedf(car.rotation_degrees.x, 0.001), snappedf(car.rotation_degrees.y, 0.001), snappedf(car.rotation_degrees.z, 0.001)],
        "scale": float(car.get("overall_scale")),
        "power": float(car.get("engine_power")),
        "suspension": snappedf(float(metrics["suspension"]), 0.001),
        "travel": snappedf(float(metrics["travel"]), 0.001),
        "track": snappedf(float(metrics["track"]), 0.001),
        "wheelbase": snappedf(float(metrics["wheelbase"]), 0.001),
        "radius": snappedf(float(metrics["radius"]), 0.001)
    }

func _as_vec(value: Variant, fallback: Vector3) -> Vector3:
    if not _vector_is_finite(fallback):
        fallback = Vector3.ZERO
    if value is Array and value.size() == 3:
        return Vector3(
            _finite_number(value[0], fallback.x),
            _finite_number(value[1], fallback.y),
            _finite_number(value[2], fallback.z)
        )
    return fallback

func apply_data(car: VehicleBody3D, info: Dictionary) -> void:
    if car == null or car.get("driver") != null or car.is_queued_for_deletion():
        return
    ensure_vehicle_finite(car)
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO
    var old_size: float = _finite_number(car.get("overall_scale"), 1.06)
    if old_size <= 0.01:
        old_size = 1.06
    var new_size: float = clampf(_finite_number(info.get("scale", old_size), old_size), 0.85, 1.60)
    if absf(new_size - old_size) > 0.0001 and car.has_method("_apply_vehicle_size"):
        var size_factor: float = new_size / old_size
        if is_finite(size_factor) and size_factor > 0.0:
            car.call("_apply_vehicle_size", size_factor)
            car.set("overall_scale", new_size)
    car.set("engine_power", clampf(_finite_number(info.get("power", car.get("engine_power")), _finite_number(car.get("engine_power"), 3650.0)), 500.0, 9000.0))
    var current_metrics: Dictionary = wheel_metrics(car)
    apply_wheel_settings(car,
        _finite_number(info.get("suspension", current_metrics["suspension"]), float(current_metrics["suspension"])),
        _finite_number(info.get("travel", current_metrics["travel"]), float(current_metrics["travel"])),
        _finite_number(info.get("track", current_metrics["track"]), float(current_metrics["track"])),
        _finite_number(info.get("wheelbase", current_metrics["wheelbase"]), float(current_metrics["wheelbase"])),
        _finite_number(info.get("radius", current_metrics["radius"]), float(current_metrics["radius"])))
    var safe_position: Vector3 = _as_vec(info.get("pos", []), car.global_position)
    var safe_rotation: Vector3 = _as_vec(info.get("rot", []), car.rotation_degrees)
    # Reject stale/corrupted editor values instead of sending physics objects
    # thousands of kilometres away or feeding RenderingServer huge transforms.
    if _vector_is_finite(safe_position) and absf(safe_position.x) <= 20000.0 and absf(safe_position.y) <= 5000.0 and absf(safe_position.z) <= 20000.0:
        car.global_position = safe_position
    if _vector_is_finite(safe_rotation) and absf(safe_rotation.x) <= 3600.0 and absf(safe_rotation.y) <= 3600.0 and absf(safe_rotation.z) <= 3600.0:
        car.rotation_degrees = safe_rotation
    ensure_vehicle_finite(car)
    car.sleeping = false

func spawn(kind: int, location: Vector3, heading: float = 0.0) -> VehicleBody3D:
    if kind < 0 or kind >= MODELS.size() or spawned_root == null or spawned.size() >= 24:
        return null
    var source: PackedScene = load(MODELS[kind]) as PackedScene
    if source == null:
        return null
    var car: VehicleBody3D = source.instantiate() as VehicleBody3D
    if car == null:
        return null
    var object_id: String = "EditorVeiculo_%06d" % next_id
    next_id += 1
    car.name = object_id
    car.set_meta("vehicle_edit_kind", kind)
    car.set_meta("vehicle_edit_applied", true)
    spawned_root.add_child(car)
    car.global_position = location
    car.rotation.y = heading
    car.linear_velocity = Vector3.ZERO
    car.angular_velocity = Vector3.ZERO
    remember(car)
    return car

func remember(car: VehicleBody3D) -> void:
    if car == null or not is_instance_valid(car):
        return
    if car.get_parent() == spawned_root:
        spawned[str(car.name)] = {"kind": int(car.get_meta("vehicle_edit_kind", 0)), "transform": capture(car)}
    else:
        parked[str(car.name)] = capture(car)

func remove_spawned(car: VehicleBody3D) -> bool:
    if car == null or not is_instance_valid(car) or car.get_parent() != spawned_root or car.get("driver") != null:
        return false
    spawned.erase(str(car.name))
    car.queue_free()
    return true

func _restore_spawned() -> void:
    for object_id in spawned.keys():
        var info: Variant = spawned[object_id]
        if not (info is Dictionary):
            continue
        var kind: int = int(info.get("kind", -1))
        if kind < 0 or kind >= MODELS.size():
            continue
        var source: PackedScene = load(MODELS[kind]) as PackedScene
        if source == null:
            continue
        var car: VehicleBody3D = source.instantiate() as VehicleBody3D
        if car == null:
            continue
        car.name = str(object_id)
        car.set_meta("vehicle_edit_kind", kind)
        car.set_meta("vehicle_edit_applied", true)
        spawned_root.add_child(car)
        apply_data(car, info.get("transform", {}))

func save() -> Dictionary:
    var payload: String = JSON.stringify({"version": 2, "spawned": spawned, "parked": parked, "next_id": next_id}, "  ")
    var local_error: int = _write(USER_FILE, payload)
    var project_error: int = _write(PROJECT_FILE, payload) if OS.has_feature("editor") else ERR_UNAVAILABLE
    return {"local": local_error, "project": project_error}

func _write(path: String, content: String) -> int:
    var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        return FileAccess.get_open_error()
    file.store_string(content)
    var result: int = file.get_error()
    file.close()
    return result
