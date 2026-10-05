extends VehicleBody3D

const CAR_PAINT_TEXTURE := preload("res://assets/textures/car_paint.png")
const BRUSHED_METAL_TEXTURE := preload("res://assets/textures/brushed_metal.png")
const CARBON_TEXTURE := preload("res://assets/textures/carbon.png")
const DETAILED_VEHICLE_PAINT_TEXTURE := preload("res://assets/textures/vehicle_paint_detailed.png")

@export var engine_power: float = 3650.0
@export var reverse_power: float = 1450.0
@export var max_steer: float = 0.37
@export var steer_speed: float = 3.2
@export var brake_power: float = 92.0

@export var overall_scale: float = 1.22

var driver: Node = null
var touch_ui_enabled := false
var mobile_accel := false
var mobile_brake := false
var mobile_left := false
var mobile_right := false
var mobile_reverse := false
var steering_mode: int = 0 # 0 = botoes, 1 = analogico
var steering_pad: Control = null
var steering_left_button: Button = null
var steering_right_button: Button = null
var ui_layer: CanvasLayer
var car_camera: Camera3D
var camera_rig: Node3D = null
var camera_base_position: Vector3 = Vector3.ZERO
var camera_turn_blend: float = 0.0
# Render-frame visual smoothing only; physics and steering keep their timing.
var smoothed_chase_focus: Vector3 = Vector3.ZERO
var chase_focus_valid: bool = false
# Move the chase camera together with the vehicle each rendered frame.
# This avoids growing follow-distance lag as vehicle speed rises.
var chase_last_vehicle_position: Vector3 = Vector3.ZERO
var chase_last_vehicle_valid: bool = false
# BMW-specific chase / cockpit camera. Other vehicles keep the V21 cameras.
var bmw_camera_enabled: bool = false
# Only camera behavior is common to every vehicle. Driving and imported mesh
# handling continue using bmw_camera_enabled to avoid regressions.
var camera_system_enabled: bool = true
# Shared closer camera for all vehicles, with a small inward movement at speed.
@export_range(5.5, 11.0, 0.1) var chase_distance: float = 7.55
@export_range(-1.0, 2.0, 0.05) var speed_zoom_out: float = 0.35
var user_camera_fov: float = 72.0
var camera_wall_distance: float = 1000.0
var camera_wall_hit: bool = false
var cockpit_pivot: Node3D = null
var cockpit_camera: Camera3D = null
var cockpit_mode: bool = false
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var mobile_look_finger: int = -1
var desktop_look_dragging: bool = false
# v0.0.115: olhar livre 360° no veículo e retorno automático para a frente.
@export_range(0.5, 8.0, 0.1) var camera_return_delay: float = 2.8
@export_range(1.0, 12.0, 0.1) var camera_return_speed: float = 4.8
var camera_return_timer: float = 0.0
var player_exit_cooldown := 0.0
var rewarded := false
# Detects a reversed wheel installation/drivetrain automatically, one time.
# local -Z is the forward direction of this car and of VehicleBody3D.
@export var drive_sign: float = -1.0
# Some imported cars (the Urus) have their visible nose on local +Z.
# The physical car still drives along its authored model orientation.
@export var front_is_positive_z: bool = false
var calibration_time: float = 0.0
var drive_calibrated: bool = true
var speed_label: Label = null
@export var roll_spring: float = 12500.0
@export var roll_damping: float = 4700.0
@export var top_speed_mps: float = 58.0
@export var vehicle_name: String = "CARRO"

var geometry_initialized: bool = false
var required_mobile_buttons: Array[Button] = []

func _enter_tree() -> void:
    # VehicleWheel3D caches its suspension connection when entering the tree.
    # Configure geometry before children enter, never afterwards in _ready.
    if geometry_initialized:
        return
    geometry_initialized = true
    camera_rig = get_node_or_null("CameraRig") as Node3D
    cockpit_pivot = get_node_or_null("CockpitPivot") as Node3D
    if not is_equal_approx(overall_scale, 1.0):
        _apply_vehicle_size(overall_scale)
    _fit_wheels_to_fenders()
    _configure_axle_steering()

func _ready() -> void:
    touch_ui_enabled = OS.has_feature("mobile")
    contact_monitor = true
    max_contacts_reported = 12
    body_entered.connect(_notify_player_impact)
    car_camera = get_node_or_null("CameraRig/SpringArm3D/Camera3D") as Camera3D
    camera_rig = get_node_or_null("CameraRig") as Node3D
    if camera_rig != null:
        camera_base_position = camera_rig.position
    # Godot 4 VehicleBody3D uses positive engine_force for forward motion.
    # The BMW in V21 had -1, so W commanded reverse. Do not change other cars.
    bmw_camera_enabled = vehicle_name == "BMW IMPORTADA" or vehicle_name == "MERCEDES GLS" or vehicle_name.begins_with("FORD RAPTOR") or vehicle_name.begins_with("BLINDADO")
    if bmw_camera_enabled:
        # A camera/handling group must not force every imported vehicle to use
        # the BMW drivetrain orientation. The GLS uses the normal Godot 4
        # positive-forward engine force; keeping -1 here could leave it unable
        # to launch correctly.
        if vehicle_name == "BMW IMPORTADA" or vehicle_name == "MERCEDES GLS":
            drive_sign = -1.0
        drive_calibrated = true
        # Higher-speed handling only on the imported BMW.
        angular_damp = 3.8
        linear_damp = 0.045
        center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
        center_of_mass = Vector3(0.0, -0.29, 0.0)
        _setup_bmw_cameras()
    else:
        # Native sedans/pickups get the same smooth chase and cabin views.
        _setup_bmw_cameras()
    if vehicle_name == "HAMMER MILITAR" or vehicle_name == "CAMINHAO MILITAR":
        # Ambos os modelos foram alinhados visual e fisicamente para frente em -Z.
        # Usa sentido determinístico para W = frente e S = ré; não recalibra em movimento.
        drive_sign = -1.0
        drive_calibrated = true
        calibration_time = 0.0
    if car_camera != null:
        car_camera.current = false
    # Lowered centre of gravity is a physical change, not a visual reset.
    if not bmw_camera_enabled:
        center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
        center_of_mass = Vector3(0.0, -0.18, 0.0)
        angular_damp = 3.1
        linear_damp = 0.045
    # Aumenta carroceria, chassi e rodas fisicas juntos, sem escalar o
    # VehicleBody3D (escala no corpo rigido desajusta a simulacao das rodas).
    _apply_visual_materials()
    _apply_imported_pickup_materials()
    # High-detail imported bodies are decorative. Reuse the lighter V18 shell on mobile.
    var high_detail: Node3D = get_node_or_null("V18CarroceriaImportada") as Node3D
    var mobile_body: Node3D = get_node_or_null("V19_MobileProxy") as Node3D
    if mobile_body != null and high_detail != null:
        high_detail.visible = not OS.has_feature("mobile")
        mobile_body.visible = OS.has_feature("mobile")
        # Avoid duplicate physical wheel meshes when imported OBJ already contains tires.
        # The VehicleWheel3D nodes continue handling steering, traction and suspension.
        for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
            var wheel: VehicleWheel3D = get_node_or_null(wheel_name) as VehicleWheel3D
            if wheel != null:
                for wheel_part in wheel.get_children():
                    # The physical wheel remains active; only the imported tire
                    # GLB is visible on the BMW (no duplicated primitive rim).
                    if bmw_camera_enabled and String(wheel_part.name).begins_with("Pneu3D_"):
                        wheel_part.visible = true
                    elif wheel_part is MeshInstance3D:
                        wheel_part.visible = not bmw_camera_enabled and OS.has_feature("mobile")
    var engine_audio: AudioStreamPlayer3D = get_node_or_null("EngineAudio") as AudioStreamPlayer3D
    if engine_audio != null and engine_audio.stream != null:
        if engine_audio.stream is AudioStreamWAV:
            (engine_audio.stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
        engine_audio.play()
        engine_audio.volume_db = -75.0
    _finish_imported_materials()
    _ensure_automatic_night_lights()
    # One-off GPU optimization for mobile; independent of the physics tick.
    if OS.has_feature("mobile"):
        call_deferred("_optimize_vehicle_mobile")
    _create_vehicle_ui()
    call_deferred("_settle_vehicle_height_once")
    # V0.5.24: somente câmera externa; não criar botão/interior.
    _load_mobile_hud_settings()
    get_viewport().size_changed.connect(_clamp_vehicle_hud_to_screen)

func _optimize_vehicle_mobile() -> void:
    # Drop per-tire shadow passes on inexpensive GPUs, without touching the
    # VehicleWheel3D suspension/traction, body collisions or the full-size PC meshes.
    var low_poly_wheel: PackedScene = null
    if vehicle_name == "BMW IMPORTADA":
        low_poly_wheel = preload("res://assets/models/v23_2/pneu_usuario_bmw_mobile.glb")
    for suffix in ["FL", "FR", "RL", "RR"]:
        var wheel: VehicleWheel3D = get_node_or_null("Wheel" + suffix) as VehicleWheel3D
        if wheel == null:
            continue
        if low_poly_wheel != null:
            var original_visual: Node3D = wheel.get_node_or_null("WheelModel") as Node3D
            if original_visual != null:
                var replacement: Node3D = low_poly_wheel.instantiate() as Node3D
                if replacement != null:
                    replacement.transform = original_visual.transform
                    wheel.remove_child(original_visual)
                    original_visual.queue_free()
                    replacement.name = "WheelModel"
                    wheel.add_child(replacement)
        for part in wheel.find_children("*", "MeshInstance3D", true, false):
            (part as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    # Keep the main body casting a shadow while dropping small ornamental
    # geometry from its extra shadow passes (the geometry stays visible).
    var body_visual: Node3D = get_node_or_null("BodyModel") as Node3D
    if body_visual == null:
        body_visual = get_node_or_null("Visual/Modelo") as Node3D
    if body_visual != null:
        var body_meshes: Array[Node] = body_visual.find_children("*", "MeshInstance3D", true, false)
        if body_visual is MeshInstance3D:
            body_meshes.push_back(body_visual)
        var largest_mesh: float = 0.0
        for item in body_meshes:
            var mesh_part: MeshInstance3D = item as MeshInstance3D
            if mesh_part != null and mesh_part.mesh != null:
                largest_mesh = maxf(largest_mesh, mesh_part.get_aabb().size.length())
        if largest_mesh > 0.0:
            for item in body_meshes:
                var mesh_part: MeshInstance3D = item as MeshInstance3D
                if mesh_part != null and mesh_part.mesh != null:
                    if mesh_part.get_aabb().size.length() < largest_mesh * 0.70:
                        mesh_part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _fit_wheels_to_fenders() -> void:
    # Coordenadas por modelo + bitola individual para manter pneus dentro dos paralamas.
    var profile := _wheel_profile_for_vehicle()
    if profile.is_empty():
        return

    var factor: float = clampf(overall_scale, 0.50, 2.00)
    var base_radius: float = float(profile["radius"])
    var base_rest: float = float(profile["rest"])
    var wheel_positions: Dictionary = profile["positions"]

    for wheel_name in ["WheelFL", "WheelFR", "WheelRL", "WheelRR"]:
        var wheel := get_node_or_null(wheel_name) as VehicleWheel3D
        if wheel == null or not wheel_positions.has(wheel_name):
            continue

        var base_position: Vector3 = wheel_positions[wheel_name]
        var final_position: Vector3 = base_position * factor

        # V0.5.17: bitola individual por carro.
        # Move o centro da roda para dentro sem diminuir pneu, raio ou veículo.
        var track_scale: float = float(profile.get("track_scale", 1.0))
        final_position.x *= track_scale

        wheel.position = final_position
        wheel.wheel_radius = base_radius * factor
        wheel.wheel_rest_length = base_rest * factor
        if profile.has("travel"):
            wheel.suspension_travel = float(profile["travel"]) * factor

func _wheel_profile_for_vehicle() -> Dictionary:
    # Axles are specified in unscaled body coordinates.
    if vehicle_name == "BMW IMPORTADA":
        return {
            "track_scale": 0.91,
            "radius": 0.38910,
            "rest": 0.24,
            "inset_ratio": 0.30,
            "positions": {
                "WheelFL": Vector3(-1.00000, 0.18910, -1.76363),
                "WheelFR": Vector3( 1.00000, 0.18910, -1.76363),
                "WheelRL": Vector3(-1.00000, 0.18910,  1.46365),
                "WheelRR": Vector3( 1.00000, 0.18910,  1.46365)
            }
        }

    if vehicle_name == "MERCEDES GLS":
        return {
            "track_scale": 0.90,
            "radius": 0.41963,
            "rest": 0.24,
            "inset_ratio": 0.30,
            "positions": {
                "WheelFL": Vector3(-1.02150, 0.31963, -1.82269),
                "WheelFR": Vector3( 1.02150, 0.31963, -1.82269),
                "WheelRL": Vector3(-1.02150, 0.31963,  1.58834),
                "WheelRR": Vector3( 1.02150, 0.31963,  1.58834)
            }
        }

    if vehicle_name.begins_with("FORD RAPTOR"):
        return {
            "track_scale": 0.90,
            "radius": 0.475,
            "rest": 0.56,
            "travel": 0.32,
            "inset_ratio": 0.32,
            "positions": {
                "WheelFL": Vector3(-1.01500, -0.19000, -1.94700),
                "WheelFR": Vector3( 1.01500, -0.19000, -1.94700),
                "WheelRL": Vector3(-1.01500, -0.19000,  1.60000),
                "WheelRR": Vector3( 1.01500, -0.19000,  1.60000)
            }
        }

    if vehicle_name == "LAMBORGHINI URUS":
        return {
            "track_scale": 0.89,
            "radius": 0.393,
            "rest": 0.22,
            "travel": 0.20,
            "inset_ratio": 0.32,
            "positions": {
                "WheelFL": Vector3(-0.92500, 0.62000,  1.45500),
                "WheelFR": Vector3( 0.92500, 0.62000,  1.45500),
                "WheelRL": Vector3(-0.92500, 0.62000, -1.51200),
                "WheelRR": Vector3( 0.92500, 0.62000, -1.51200)
            }
        }

    if vehicle_name == "DUSTER POLICIAL":
        return {
            "track_scale": 0.89,
            "radius": 0.395,
            "rest": 0.22,
            "travel": 0.20,
            "inset_ratio": 0.30,
            "positions": {
                "WheelFL": Vector3( 0.93500, 0.58000,  1.38000),
                "WheelFR": Vector3(-0.93500, 0.58000,  1.38000),
                "WheelRL": Vector3( 0.93500, 0.58000, -1.41000),
                "WheelRR": Vector3(-0.93500, 0.58000, -1.41000)
            }
        }

    # AMBULANCIA_HOSPITAL_PROFILE: rodas Duster calibradas para o GLB da ambulancia.
    if vehicle_name.begins_with("AMBUL"):
        return {
            "track_scale": 1.0,
            "radius": 0.355,
            "rest": 0.22,
            "travel": 0.18,
            "inset_ratio": 0.30,
            "positions": {
                "WheelFL": Vector3(-0.95, 0.36, -2.59),
                "WheelFR": Vector3( 0.95, 0.36, -2.59),
                "WheelRL": Vector3(-0.91, 0.36,  1.64),
                "WheelRR": Vector3( 0.91, 0.36,  1.64)
            }
        }

    if vehicle_name == "HAMMER MILITAR":
        return {
            "track_scale": 1.0, "radius": 0.452, "rest": 0.25, "travel": 0.24, "inset_ratio": 0.28,
            "positions": {
                "WheelFL": Vector3(-0.916, 0.10, -1.7216),
                "WheelFR": Vector3( 0.916, 0.10, -1.7216),
                "WheelRL": Vector3(-0.916, 0.10,  1.5455),
                "WheelRR": Vector3( 0.916, 0.10,  1.5455)
            }
        }

    if vehicle_name == "CAMINHAO MILITAR":
        return {
            "track_scale": 1.0, "radius": 0.62, "rest": 0.30, "travel": 0.28, "inset_ratio": 0.24,
            "positions": {
                "WheelFL": Vector3(-1.1500, 0.18, -2.3898),
                "WheelFR": Vector3( 1.1500, 0.18, -2.3898),
                "WheelRL": Vector3(-1.1500, 0.18,  2.3891),
                "WheelRR": Vector3( 1.1500, 0.18,  2.3891)
            }
        }

    if vehicle_name.begins_with("BLINDADO"):
        return {
            "track_scale": 0.92,
            "radius": 0.55,
            "rest": 0.28,
            "travel": 0.26,
            "inset_ratio": 0.28,
            "positions": {
                "WheelFL": Vector3(-0.98500, 0.10000, -2.02100),
                "WheelFR": Vector3( 0.98500, 0.10000, -2.02100),
                "WheelRL": Vector3(-0.98500, 0.10000,  1.62800),
                "WheelRR": Vector3( 0.98500, 0.10000,  1.62800)
            }
        }

    return {}

func _configure_axle_steering() -> void:
    # Identifica o eixo da frente pela posicao fisica das rodas e pela frente
    # da carroceria. Os nomes importados nao podem inverter o eixo direcional.
    var forward_z: float = 1.0 if front_is_positive_z else -1.0
    var front_wheel_count: int = 0
    for suffix in ["FL", "FR", "RL", "RR"]:
        var wheel: VehicleWheel3D = get_node_or_null("Wheel" + suffix) as VehicleWheel3D
        if wheel == null:
            push_warning("Roda fisica ausente: Wheel" + suffix + " em " + vehicle_name)
            continue
        var front_axle: bool = wheel.position.z * forward_z > 0.05
        wheel.use_as_steering = front_axle
        if front_axle:
            front_wheel_count += 1
        else:
            # Uma roda traseira nunca deve herdar estercoes individuais.
            wheel.steering = 0.0
    if front_wheel_count != 2:
        push_warning("Eixo dianteiro inconsistente: " + vehicle_name)

func _settle_vehicle_height_once() -> void:
    # Aguarda a física e alinha a conexão média das quatro rodas à altura real
    # do chão. Corrige veículos flutuando/afundados sem mexer no handling.
    await get_tree().physics_frame
    await get_tree().physics_frame
    if not is_inside_tree():
        return
    var space := get_world_3d().direct_space_state
    var corrections: Array[float] = []
    for wheel_name in ["WheelFL","WheelFR","WheelRL","WheelRR"]:
        var wheel := get_node_or_null(wheel_name) as VehicleWheel3D
        if wheel == null:
            continue
        var from := wheel.global_position + Vector3.UP * 2.5
        var to := wheel.global_position + Vector3.DOWN * 4.5
        var query := PhysicsRayQueryParameters3D.create(from,to)
        query.exclude = [get_rid()]
        query.collide_with_areas = false
        var hit := space.intersect_ray(query)
        if hit.is_empty():
            continue
        var hit_position: Vector3 = hit.get("position",Vector3.ZERO)
        var ground_y: float = hit_position.y
        var suspension_support: float = 0.0
        if vehicle_name.begins_with("FORD RAPTOR") or vehicle_name.begins_with("BLINDADO") or vehicle_name == "HAMMER MILITAR" or vehicle_name == "CAMINHAO MILITAR":
            suspension_support = wheel.wheel_rest_length
        var desired_connection_y := ground_y + wheel.wheel_radius + suspension_support
        corrections.append(desired_connection_y - wheel.global_position.y)
    if corrections.is_empty():
        return
    corrections.sort()
    var correction := corrections[int(corrections.size()/2)]
    global_position.y += clampf(correction,-0.75,0.75)

func _apply_vehicle_size(factor: float) -> void:
    if not is_finite(factor) or factor <= 0.0:
        push_warning("Escala de veículo inválida ignorada: %s" % factor)
        return
    factor = clampf(factor, 0.50, 2.00)
    # Uniformidade visual/fisica: manter VehicleBody3D em escala 1 evita
    # divergencia entre as rodas raycast e a colisao do chassi.
    for node in get_children():
        if not (node is Node3D):
            continue
        var part: Node3D = node as Node3D
        if part.top_level:
            continue  # A camera externa se posiciona em coordenadas globais.
        part.position *= factor
        if part is VehicleWheel3D:
            var wheel: VehicleWheel3D = part as VehicleWheel3D
            wheel.wheel_radius *= factor
            wheel.wheel_rest_length *= factor
            wheel.suspension_travel *= factor
            for child in wheel.get_children():
                if child is Node3D:
                    var wheel_visual: Node3D = child as Node3D
                    wheel_visual.position *= factor
                    wheel_visual.scale *= factor
        elif part is CollisionShape3D:
            var collider: CollisionShape3D = part as CollisionShape3D
            if collider.shape != null:
                collider.shape = collider.shape.duplicate(true)
                if collider.shape is BoxShape3D:
                    (collider.shape as BoxShape3D).size *= factor
                elif collider.shape is CapsuleShape3D:
                    (collider.shape as CapsuleShape3D).radius *= factor
                    (collider.shape as CapsuleShape3D).height *= factor
        elif part == camera_rig or part == cockpit_pivot:
            # Mantem distancia e FOV da camera, deslocando apenas o ponto de vista.
            pass
        elif part.name == "VehicleNightLights":
            for property_name in ["front_left_position", "front_right_position", "rear_left_position", "rear_right_position"]:
                var local_pos: Variant = part.get(property_name)
                if local_pos is Vector3:
                    part.set(property_name, local_pos * factor)
        else:
            part.scale *= factor

func _ensure_automatic_night_lights() -> void:
    # Herda as coordenadas personalizadas dos modelos BMW/GLS/Raptor/blindado.
    # Novos carros baseados em car.gd recebem farois mesmo sem no na cena.
    if get_node_or_null("VehicleNightLights") != null:
        return
    var light_node: Node3D = Node3D.new()
    light_node.name = "VehicleNightLights"
    light_node.set_script(preload("res://scripts/vehicle_night_lights.gd"))
    var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
    var bounds: Vector3 = Vector3(1.9, 1.2, 4.5)
    if shape_node != null and shape_node.shape is BoxShape3D:
        bounds = (shape_node.shape as BoxShape3D).size
    var half_width: float = bounds.x * 0.39
    var front_z: float = -bounds.z * 0.49
    var rear_z: float = bounds.z * 0.49
    var light_y: float = maxf(0.45, bounds.y * 0.49)
    light_node.set("front_left_position", Vector3(-half_width, light_y, front_z))
    light_node.set("front_right_position", Vector3(half_width, light_y, front_z))
    light_node.set("rear_left_position", Vector3(-half_width, light_y, rear_z))
    light_node.set("rear_right_position", Vector3(half_width, light_y, rear_z))
    add_child(light_node)

func _notify_player_impact(body: Node) -> void:
    if body == driver or not (body is CharacterBody3D):
        return
    if body.has_method("receive_vehicle_impact"):
        body.call("receive_vehicle_impact", self, linear_velocity)

func interact(player: Node) -> void:
    if driver == null and player != null and player.has_method("enter_vehicle_mode") and player.get("vehicle") == null:
        var streamer := get_tree().current_scene.get_node_or_null("WorldStreamer")
        if streamer != null and streamer.has_method("keep_vehicle"):
            streamer.call("keep_vehicle", self)
        if player is PhysicsBody3D:
            add_collision_exception_with(player)
            (player as PhysicsBody3D).add_collision_exception_with(self)
        driver = player
        engine_force = 0.0
        brake = 0.0
        steering = 0.0
        mobile_accel = false
        mobile_reverse = false
        mobile_brake = false
        mobile_left = false
        mobile_right = false
        if player.get("touch_ui_enabled") != null:
            set_mobile_ui_enabled(bool(player.get("touch_ui_enabled")))
        # Keep this exact vehicle instance (including its parked position) in
        # the world after the driver leaves, even when its origin is far away.
        set_meta("has_been_driven", true)
        player_exit_cooldown = 0.70
        driver.call("enter_vehicle_mode", self)
        if camera_system_enabled:
            cockpit_mode = false
            look_yaw = 0.0
            look_pitch = 0.0
            camera_return_timer = 0.0
            _apply_bmw_camera_rotation()
        if not touch_ui_enabled:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        if camera_system_enabled:
            _sample_camera_obstacle()
            _update_bmw_chase_camera(1.0, true)
        _activate_vehicle_camera()
        if ui_layer != null:
            ui_layer.visible = true
        set_mobile_ui_enabled(touch_ui_enabled)
        call_deferred("_clamp_vehicle_hud_to_screen")
        if not rewarded:
            rewarded = true
            var state: Node = get_node_or_null("/root/GameState")
            if state != null:
                state.call("add_xp", 25)

func _physics_process(delta: float) -> void:
    if driver != null and not is_instance_valid(driver):
        driver = null
    # V0.4.5 parked fast path: veículos parados não precisam recalcular
    # áudio/câmera/estabilização 60 vezes por segundo.
    if driver == null and linear_velocity.length_squared() < 0.0025 and angular_velocity.length_squared() < 0.0025:
        engine_force = 0.0
        brake = 2.0
        steering = move_toward(steering,0.0,steer_speed*delta)
        return
    player_exit_cooldown = max(0.0, player_exit_cooldown - delta)
    var engine_audio: AudioStreamPlayer3D = get_node_or_null("EngineAudio") as AudioStreamPlayer3D
    if engine_audio != null:
        var moving: float = clampf(linear_velocity.length() / maxf(top_speed_mps, 1.0), 0.0, 1.0)
        engine_audio.pitch_scale = lerpf(engine_audio.pitch_scale, 0.80 + moving * 1.10, clampf(delta * 3.0, 0.0, 1.0))
        var target_volume: float = (-15.0 + moving * 8.0) if driver != null else -65.0
        engine_audio.volume_db = lerpf(engine_audio.volume_db, target_volume, clampf(delta * 5.0, 0.0, 1.0))
    _stabilize_roll(delta)
    if driver != null and camera_system_enabled and not cockpit_mode:
        _sample_camera_obstacle()
    if driver == null:
        engine_force = 0.0
        brake = 2.0
        steering = move_toward(steering, 0.0, steer_speed * delta)
        _update_corner_camera(delta, 0.0)
        return

    var chat_typing := bool(get_tree().get_meta("br1_chat_typing", false))
    var throttle := 0.0 if chat_typing else Input.get_action_strength("move_forward")
    var reverse := 0.0 if chat_typing else Input.get_action_strength("move_back")
    var steer_input := 0.0 if chat_typing else Input.get_action_strength("move_left") - Input.get_action_strength("move_right")
    var braking := true if chat_typing else Input.is_action_pressed("brake")

    if mobile_accel and not chat_typing: throttle = 1.0
    if mobile_reverse and not chat_typing: reverse = 1.0
    if not chat_typing and touch_ui_enabled and steering_mode == 1 and steering_pad != null:
        var pad_value: Vector2 = steering_pad.call("get_value")
        var pad_x: float = pad_value.x
        if absf(pad_x) > 0.08:
            steer_input = -pad_x
    elif not chat_typing:
        if mobile_left: steer_input = 1.0
        if mobile_right: steer_input = -1.0
    if mobile_brake and not chat_typing: braking = true

    # Both directions are relative to the car's physical forward axis (-Z).
    # Never accelerate and reverse simultaneously; braking wins over throttle.
    var command: float = clamp(throttle - reverse, -1.0, 1.0)
    var forward_speed: float = global_transform.basis.z.dot(linear_velocity) if front_is_positive_z else -global_transform.basis.z.dot(linear_velocity)
    var wheel_contact: bool = ($WheelRL as VehicleWheel3D).is_in_contact() or ($WheelRR as VehicleWheel3D).is_in_contact()
    # Limitador usa somente velocidade longitudinal.
    var longitudinal_speed: float = absf(forward_speed)
    var limiter: float = clampf((top_speed_mps - longitudinal_speed) / 10.0, 0.0, 1.0)
    # Troca frente/ré: freia apenas enquanto ainda há velocidade na direção oposta.
    var opposite_gear: bool = (
        (command < -0.02 and forward_speed > 1.25)
        or (command > 0.02 and forward_speed < -1.25)
    )
    if braking or opposite_gear:
        engine_force = 0.0
        brake = brake_power
    else:
        brake = 0.0
        if command > 0.02:
            engine_force = command * engine_power * drive_sign * limiter
        elif command < -0.02:
            # Ré libera força total em baixa velocidade e limita só em alta.
            var reverse_limiter: float = clampf((16.0 - absf(forward_speed)) / 6.0, 0.0, 1.0)
            engine_force = command * reverse_power * drive_sign * reverse_limiter
        else:
            engine_force = 0.0
            brake = 2.0 if abs(forward_speed) < 0.35 else 0.3

    # If the model's wheel axes were exported reversed, calibrate once on
    # a straight launch rather than making W permanently act as reverse.
    if not drive_calibrated and wheel_contact and command > 0.7 and not braking and abs(steer_input) < 0.15:
        calibration_time += delta
        if calibration_time >= 0.75 and abs(forward_speed) > 0.55:
            if forward_speed < -0.55:
                drive_sign *= -1.0
            drive_calibrated = true
            calibration_time = 0.0
    elif not drive_calibrated and command < 0.05:
        calibration_time = 0.0

    # Stronger steering at urban speed, reducing wheel lock only when the
    # BMW is going very fast; do not modify any other vehicle's handling.
    var steering_fade: float = clampf((linear_velocity.length() - 23.0) / 90.0, 0.0, 1.0) if bmw_camera_enabled else clampf(linear_velocity.length() / 55.0, 0.0, 1.0)
    var steering_min_ratio: float = 0.34 if bmw_camera_enabled else 0.20
    var speed_steering: float = lerpf(max_steer, max_steer * steering_min_ratio, steering_fade)
    # Convencao unica nos comandos do teclado, joystick e botoes: positivo
    # esterça para a esquerda e negativo para a direita. drive_sign ja cuida
    # da orientacao de rodagem; inverter aqui espelhava Duster e Urus.
    steering = move_toward(steering, steer_input * speed_steering, steer_speed * delta)
    _update_corner_camera(delta, steer_input)
    if speed_label != null:
        speed_label.text = "%d km/h   |   %s" % [roundi(linear_velocity.length() * 3.6), "FRENTE" if command > 0.02 else ("RÉ" if command < -0.02 else "NEUTRO")]

    if not chat_typing and Input.is_action_just_pressed("exit_vehicle") and player_exit_cooldown <= 0.0:
        exit_driver()

func _stabilize_roll(_delta: float) -> void:
    # Righting spring around the car's own forward axis. Do not auto-flip an
    # overturned car: this only damps the suspension's normal cornering roll.
    var grounded: int = 0
    for wheel in [$WheelFL, $WheelFR, $WheelRL, $WheelRR]:
        if (wheel as VehicleWheel3D).is_in_contact():
            grounded += 1
    if grounded < 2:
        return
    var bank: float = asin(clamp(global_transform.basis.x.normalized().y, -1.0, 1.0))
    if abs(bank) > 0.70:
        return
    var axis: Vector3 = global_transform.basis.z.normalized()
    var spin: float = angular_velocity.dot(axis)
    apply_torque(axis * clamp(-bank * roll_spring - spin * roll_damping, -21000.0, 21000.0))

func exit_driver() -> void:
    if driver == null: return
    var p: Node = driver
    driver = null
    chase_focus_valid = false
    chase_last_vehicle_valid = false
    mobile_accel = false; mobile_brake = false; mobile_left = false
    mobile_right = false; mobile_reverse = false
    if steering_pad != null:
        steering_pad.set("value", Vector2.ZERO)
        steering_pad.set("active_touch", -1)
        steering_pad.queue_redraw()
    engine_force = 0.0
    brake = 4.0
    if car_camera != null:
        car_camera.current = false
    if cockpit_camera != null:
        cockpit_camera.current = false
    mobile_look_finger = -1
    desktop_look_dragging = false
    cockpit_mode = false
    look_yaw = 0.0
    look_pitch = 0.0
    camera_return_timer = 0.0
    _apply_bmw_camera_rotation()
    _update_corner_camera(1.0, 0.0)
    if ui_layer != null:
        ui_layer.visible = false
    var exit_side: Vector3 = global_transform.basis.x.normalized()
    var door_point: Vector3 = global_transform.origin + exit_side * (2.15 * overall_scale) + Vector3.UP * 0.10
    var safe_point: Vector3 = global_transform.origin + exit_side * (3.45 * overall_scale) + Vector3.UP * 0.05
    p.call("exit_vehicle_mode", door_point, safe_point)
    player_exit_cooldown = 0.5
    await get_tree().physics_frame
    await get_tree().physics_frame
    if is_instance_valid(p) and p is PhysicsBody3D and driver != p:
        remove_collision_exception_with(p)
        (p as PhysicsBody3D).remove_collision_exception_with(self)

func _setup_bmw_cameras() -> void:
    # World-space follow: never sit on top of the roof, never inherit car roll.
    if car_camera != null:
        car_camera.current = false
    var follow := Camera3D.new()
    follow.name = "BMWChaseCameraV222"
    add_child(follow)
    follow.top_level = true
    follow.current = false
    follow.fov = user_camera_fov
    follow.far = 650.0 if OS.has_feature("mobile") else 1200.0
    follow.near = 0.12
    car_camera = follow
    _update_bmw_chase_camera(1.0, true)

    # V0.5.24: não criamos câmera interna/cockpit.
    cockpit_pivot = null
    cockpit_camera = null
    cockpit_mode = false


func _process(delta: float) -> void:
    if ui_layer != null:
        var occupied := is_instance_valid(driver)
        if ui_layer.visible != occupied:
            ui_layer.visible = occupied
            if occupied:
                set_mobile_ui_enabled(touch_ui_enabled)
        if occupied:
            ui_layer.get_child(0).visible = true
            if touch_ui_enabled or OS.has_feature("mobile"):
                for button in required_mobile_buttons:
                    if not button.visible:
                        set_mobile_ui_enabled(true)
                        break
    if camera_system_enabled and driver != null:
        _update_camera_return(delta)
    # Update the visible chase camera exactly once per render frame.
    if camera_system_enabled and driver != null and not cockpit_mode:
        _update_bmw_chase_camera(delta, false)

func _update_camera_return(delta: float) -> void:
    # Enquanto o dedo está segurando a área de visão, nunca recentralize.
    if mobile_look_finger != -1 or desktop_look_dragging:
        return
    if camera_return_timer > 0.0:
        camera_return_timer = maxf(0.0, camera_return_timer - delta)
        return
    if absf(look_yaw) < 0.001 and absf(look_pitch) < 0.001:
        look_yaw = 0.0
        look_pitch = 0.0
        return
    var alpha: float = 1.0 - exp(-delta * camera_return_speed)
    look_yaw = lerp_angle(look_yaw, 0.0, alpha)
    look_pitch = lerpf(look_pitch, 0.0, alpha)
    if absf(look_yaw) < 0.002:
        look_yaw = 0.0
    if absf(look_pitch) < 0.002:
        look_pitch = 0.0
    _apply_bmw_camera_rotation()

func _camera_geometry() -> Dictionary:
    var forward: Vector3 = global_transform.basis.z if front_is_positive_z else -global_transform.basis.z
    forward.y = 0.0
    if forward.length_squared() < 0.01:
        forward = Vector3.FORWARD
    else:
        forward = forward.normalized()
    var rear: Vector3 = -forward
    var orbit: Vector3 = rear.rotated(Vector3.UP, look_yaw)
    var speed_fraction: float = clampf(linear_velocity.length() / 40.0, 0.0, 1.0)
    var focus_height: float = 1.28
    if vehicle_name.begins_with("BLINDADO"):
        focus_height = 1.65
    elif vehicle_name.begins_with("FORD RAPTOR"):
        focus_height = 1.24
    var focus: Vector3 = global_position + Vector3.UP * focus_height + forward * speed_fraction * 0.27
    var base_height: float = 2.12 if vehicle_name.begins_with("FORD RAPTOR") else 2.35
    var height: float = clampf(base_height + look_pitch * 2.65, 1.05, 4.85)
    var extra_distance: float = 0.90 if vehicle_name.begins_with("FORD RAPTOR") else 0.0
    var distance: float = chase_distance + extra_distance + speed_fraction * speed_zoom_out
    var offset: Vector3 = orbit * distance + Vector3.UP * height
    # No inherited chassis roll; small camera drift during turns only.
    var horizontal_right: Vector3 = global_transform.basis.x
    horizontal_right.y = 0.0
    offset += horizontal_right.normalized() * (-camera_turn_blend * 0.25)
    return {"focus": focus, "offset": offset, "speed_fraction": speed_fraction}

func _sample_camera_obstacle() -> void:
    # One ray per physics tick only while driving externally; no physics reads
    # in _process (important for multi-threaded physics and low-end phones).
    camera_wall_hit = false
    camera_wall_distance = 1000.0
    var geometry: Dictionary = _camera_geometry()
    var focus: Vector3 = geometry["focus"]
    var desired: Vector3 = focus + geometry["offset"]
    var query := PhysicsRayQueryParameters3D.create(focus, desired)
    query.collision_mask = 1
    var exclude_rids: Array[RID] = [get_rid()]
    if driver is CollisionObject3D:
        exclude_rids.append((driver as CollisionObject3D).get_rid())
    query.exclude = exclude_rids
    var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
    if not hit.is_empty():
        camera_wall_hit = true
        camera_wall_distance = maxf(0.75, focus.distance_to(hit["position"]) - 0.32)

func _update_bmw_chase_camera(delta: float, snap: bool) -> void:
    if not camera_system_enabled or car_camera == null:
        return
    var geometry: Dictionary = _camera_geometry()
    var focus: Vector3 = geometry["focus"]
    var offset: Vector3 = geometry["offset"]
    if camera_wall_hit and offset.length() > camera_wall_distance:
        offset = offset.normalized() * camera_wall_distance
    var desired: Vector3 = focus + offset
    # Follow world-space translation immediately, smoothing only the orbit.
    # Without this, lerp lags metres behind at driving speeds.
    var translation: Vector3 = Vector3.ZERO
    if chase_last_vehicle_valid:
        translation = global_position - chase_last_vehicle_position
    chase_last_vehicle_position = global_position
    var snap_follow: bool = snap or not chase_last_vehicle_valid or translation.length_squared() > 144.0
    chase_last_vehicle_valid = true
    if not snap_follow:
        car_camera.global_position += translation
        if chase_focus_valid:
            smoothed_chase_focus += translation
    if snap_follow or not chase_focus_valid:
        smoothed_chase_focus = focus
        chase_focus_valid = true
    elif camera_wall_hit:
        # Obstacles have priority over cinematic easing.
        smoothed_chase_focus = focus
    else:
        smoothed_chase_focus = smoothed_chase_focus.lerp(focus, 1.0 - exp(-delta * 13.0))
    if snap_follow or camera_wall_hit:
        # Snap inward before a wall can cover the lens; glide back out.
        car_camera.global_position = desired
    else:
        var alpha: float = 1.0 - exp(-delta * 9.5)
        car_camera.global_position = car_camera.global_position.lerp(desired, alpha)
    if car_camera.global_position.distance_squared_to(smoothed_chase_focus) > 0.01:
        car_camera.look_at(smoothed_chase_focus, Vector3.UP)
    # Prevent speed-dependent wide-angle zoom from making the car look small.
    var desired_fov: float = user_camera_fov + float(geometry["speed_fraction"]) * 1.5
    car_camera.fov = lerpf(car_camera.fov, desired_fov, 1.0 - exp(-delta * 4.0))

func set_user_camera_fov(value: float) -> void:
    user_camera_fov = clampf(value,68.0,78.0)
    if car_camera != null and is_instance_valid(car_camera):
        car_camera.fov = user_camera_fov
    if cockpit_camera != null and is_instance_valid(cockpit_camera):
        cockpit_camera.fov = clampf(user_camera_fov+9.0,74.0,86.0)

func _activate_vehicle_camera() -> void:
    if driver == null:
        return
    cockpit_mode = false
    if cockpit_camera != null and is_instance_valid(cockpit_camera):
        cockpit_camera.current = false
    if car_camera != null:
        car_camera.current = true

func _apply_bmw_camera_rotation() -> void:
    if not camera_system_enabled:
        return
    # External BMW camera orbits using world-space coordinates in _process.
    if cockpit_camera != null:
        # +Z is the BMW's front; yaw PI faces that direction from the seat.
        cockpit_camera.rotation = Vector3(look_pitch, look_yaw + (PI if front_is_positive_z else 0.0), 0.0)

func _rotate_bmw_view(dx: float, dy: float, sensitivity: float) -> void:
    # Órbita 360° dentro e fora do carro. Após alguns segundos sem toque/mouse, volta para a frente.
    look_yaw = wrapf(look_yaw - dx * sensitivity, -PI, PI)
    look_pitch = clampf(look_pitch - dy * sensitivity, deg_to_rad(-48.0), deg_to_rad(42.0))
    camera_return_timer = camera_return_delay
    _apply_bmw_camera_rotation()

func _input(event: InputEvent) -> void:
    if driver == null or not camera_system_enabled:
        desktop_look_dragging = false
        return
    var chat_typing := bool(get_tree().get_meta("br1_chat_typing", false))
    if event is InputEventMouseButton and not touch_ui_enabled:
        var click := event as InputEventMouseButton
        if click.button_index == MOUSE_BUTTON_LEFT or click.button_index == MOUSE_BUTTON_RIGHT:
            if click.pressed:
                var over_ui: bool = bool(driver.call("mouse_over_interactive_ui")) if driver != null and driver.has_method("mouse_over_interactive_ui") else false
                if not over_ui:
                    if driver != null and driver.has_method("collapse_text_chat"):
                        driver.call("collapse_text_chat")
                    desktop_look_dragging = true
                    camera_return_timer = camera_return_delay
            else:
                desktop_look_dragging = false
                camera_return_timer = camera_return_delay
    if chat_typing:
        return
    if bool(get_tree().get_meta("br1_virtual_cursor_active", false)) and (event is InputEventScreenTouch or event is InputEventScreenDrag):
        return
    if event is InputEventMouseMotion and not touch_ui_enabled:
        if desktop_look_dragging or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
            var motion := event as InputEventMouseMotion
            _rotate_bmw_view(motion.relative.x, motion.relative.y, 0.0035)
    elif event is InputEventKey and not touch_ui_enabled:
        var key: InputEventKey = event as InputEventKey
        if key.pressed and not key.echo:
            if key.keycode == KEY_ESCAPE:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    elif event is InputEventScreenTouch and touch_ui_enabled:
        var touch: InputEventScreenTouch = event as InputEventScreenTouch
        var screen_size: Vector2 = get_viewport().get_visible_rect().size
        if touch.pressed and mobile_look_finger == -1:
            if not _touch_on_vehicle_controls(touch.position) and touch.position.x > screen_size.x * 0.27 and touch.position.y < screen_size.y * 0.82:
                mobile_look_finger = touch.index
                camera_return_timer = camera_return_delay
        elif not touch.pressed and touch.index == mobile_look_finger:
            mobile_look_finger = -1
            camera_return_timer = camera_return_delay
    elif event is InputEventScreenDrag and touch_ui_enabled:
        var drag: InputEventScreenDrag = event as InputEventScreenDrag
        if drag.index == mobile_look_finger:
            _rotate_bmw_view(drag.relative.x, drag.relative.y, 0.0035)

func _touch_on_vehicle_controls(point: Vector2) -> bool:
    if ui_layer == null or not ui_layer.visible:
        return false
    var root: Control = ui_layer.get_child(0) as Control
    if root == null:
        return false
    for item in root.get_children():
        if item is Control and item.is_visible_in_tree() and item.get_global_rect().has_point(point):
            return true
    return false

func _update_corner_camera(delta: float, _steering_input: float) -> void:
    if camera_rig == null:
        return
    # V0.5.9: removida a "jogadinha" lateral da camera nas curvas.
    # A camera permanece centralizada no carro; sem deslocamento X e sem roll.
    camera_turn_blend = move_toward(camera_turn_blend, 0.0, delta * 8.0)
    camera_rig.position.x = lerpf(camera_rig.position.x, camera_base_position.x, clampf(delta * 10.0, 0.0, 1.0))
    camera_rig.rotation.z = lerpf(camera_rig.rotation.z, 0.0, clampf(delta * 10.0, 0.0, 1.0))

func _apply_imported_pickup_materials() -> void:
    # Paint only the imported pickup shell; don't wash out glass, lights and tires.
    if vehicle_name != "CAMINHONETE":
        return
    var shell: Node3D = get_node_or_null("V18CarroceriaImportada") as Node3D
    if shell == null:
        return
    var paint := StandardMaterial3D.new()
    paint.albedo_texture = DETAILED_VEHICLE_PAINT_TEXTURE
    paint.albedo_color = Color(0.78, 0.68, 0.52, 1.0)
    paint.metallic = 0.42
    paint.roughness = 0.34
    for item in shell.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := item as MeshInstance3D
        if String(mesh_instance.name).to_lower().contains("silverpaint"):
            if mesh_instance.mesh != null:
                for surface in range(mesh_instance.mesh.get_surface_count()):
                    mesh_instance.set_surface_override_material(surface, paint)

func _apply_visual_materials() -> void:
    var paint_tex: Texture2D = CAR_PAINT_TEXTURE
    var metal_tex: Texture2D = BRUSHED_METAL_TEXTURE
    var carbon_tex: Texture2D = CARBON_TEXTURE
    var paint := StandardMaterial3D.new()
    paint.albedo_color = Color(0.12, 0.24, 0.36, 1.0) if vehicle_name == "SEDÃ" else Color(0.68, 0.49, 0.29, 1.0)
    paint.albedo_texture = paint_tex
    paint.metallic = 0.44
    paint.roughness = 0.24
    var dark := StandardMaterial3D.new()
    dark.albedo_color = Color(0.10, 0.11, 0.13, 1.0)
    dark.albedo_texture = carbon_tex
    dark.metallic = 0.18
    dark.roughness = 0.65
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.64, 0.67, 0.72, 1.0)
    metal.albedo_texture = metal_tex
    metal.metallic = 0.85
    metal.roughness = 0.28
    var glass := StandardMaterial3D.new()
    glass.albedo_color = Color(0.14, 0.22, 0.28, 0.92)
    glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    glass.metallic = 0.25
    glass.roughness = 0.12
    var light := StandardMaterial3D.new()
    light.albedo_color = Color(0.95, 0.95, 0.88, 1.0)
    light.emission_enabled = true
    light.emission = Color(0.95, 0.9, 0.75, 1.0)
    light.emission_energy_multiplier = 1.7
    var red_light := StandardMaterial3D.new()
    red_light.albedo_color = Color(0.90, 0.18, 0.10, 1.0)
    red_light.emission_enabled = true
    red_light.emission = Color(0.92, 0.16, 0.10, 1.0)
    red_light.emission_energy_multiplier = 1.2
    var body_names := ["Body", "Hood", "Spoiler", "BumperF", "BumperR", "BedRailL", "BedRailR", "BedFloor"]
    var glass_names := ["Cabin"]
    var head_names := ["HeadlightL", "HeadlightR", "HeadLightL", "HeadLightR"]
    var tail_names := ["TailL", "TailR"]
    for child in get_children():
        if child is MeshInstance3D:
            var mesh_child := child as MeshInstance3D
            if mesh_child.name in body_names:
                mesh_child.set_surface_override_material(0, paint)
            elif mesh_child.name in glass_names:
                mesh_child.set_surface_override_material(0, glass)
            elif mesh_child.name in head_names:
                mesh_child.set_surface_override_material(0, light)
            elif mesh_child.name in tail_names:
                mesh_child.set_surface_override_material(0, red_light)
        elif child is VehicleWheel3D:
            for sub in child.get_children():
                if sub is MeshInstance3D:
                    var wheel_mesh := sub as MeshInstance3D
                    if wheel_mesh.name == "Rim":
                        wheel_mesh.set_surface_override_material(0, metal)
                    else:
                        wheel_mesh.set_surface_override_material(0, dark)

func _create_vehicle_ui() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.name = "VehicleUI"
    ui_layer.layer = 20
    ui_layer.visible = false
    add_child(ui_layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui_layer.add_child(root)

    var title := Label.new()
    title.text = vehicle_name if touch_ui_enabled else "%s   •   F para sair" % vehicle_name
    title.anchor_left = 0.5; title.anchor_right = 0.5
    title.offset_left = -170; title.offset_right = 170
    title.anchor_top = 1.0; title.anchor_bottom = 1.0
    title.offset_top = -96; title.offset_bottom = -64
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 18)
    root.add_child(title)
    speed_label = Label.new()
    speed_label.anchor_left = 0.5
    speed_label.anchor_right = 0.5
    speed_label.offset_left = -160
    speed_label.offset_right = 160
    speed_label.anchor_top = 1.0
    speed_label.anchor_bottom = 1.0
    speed_label.offset_top = -64
    speed_label.offset_bottom = -28
    speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    speed_label.text = "0 km/h"
    speed_label.add_theme_font_size_override("font_size", 19)
    root.add_child(speed_label)

    var exit_button := _button("SAIR", Vector2(-150,216), Vector2(-24,270))
    exit_button.anchor_left = 1.0
    exit_button.anchor_right = 1.0
    exit_button.pressed.connect(exit_driver)
    exit_button.name = "HUD_Exit"
    root.add_child(exit_button)

    var left := _button("◀", Vector2(24,-150), Vector2(136,-38))
    left.anchor_top = 1; left.anchor_bottom = 1
    left.button_down.connect(func(): mobile_left = true)
    left.button_up.connect(func(): mobile_left = false)
    left.name = "HUD_SteerLeft"
    steering_left_button = left
    root.add_child(left)
    var right := _button("▶", Vector2(148,-150), Vector2(260,-38))
    right.anchor_top = 1; right.anchor_bottom = 1
    right.button_down.connect(func(): mobile_right = true)
    right.button_up.connect(func(): mobile_right = false)
    right.name = "HUD_SteerRight"
    steering_right_button = right
    root.add_child(right)
    steering_pad = Control.new()
    steering_pad.name = "HUD_SteeringPad"
    steering_pad.set_script(preload("res://scripts/virtual_joystick.gd"))
    steering_pad.set("driving_mode", true)
    steering_pad.anchor_top = 1.0
    steering_pad.anchor_bottom = 1.0
    steering_pad.offset_left = 20.0
    steering_pad.offset_right = 320.0
    steering_pad.offset_top = -322.0
    steering_pad.offset_bottom = -22.0
    root.add_child(steering_pad)

    var accel := _button("ACELERADOR", Vector2(-162,-314), Vector2(-26,-178))
    accel.anchor_left = 1; accel.anchor_right = 1; accel.anchor_top = 1; accel.anchor_bottom = 1
    accel.button_down.connect(func(): mobile_accel = true)
    accel.button_up.connect(func(): mobile_accel = false)
    accel.name = "HUD_Accelerate"
    root.add_child(accel)
    var stop := _button("FREIO DE MÃO", Vector2(-310,-158), Vector2(-174,-22))
    stop.anchor_left = 1; stop.anchor_right = 1; stop.anchor_top = 1; stop.anchor_bottom = 1
    stop.button_down.connect(func(): mobile_brake = true)
    stop.button_up.connect(func(): mobile_brake = false)
    stop.name = "HUD_Brake"
    root.add_child(stop)
    var rev := _button("RÉ", Vector2(-162,-158), Vector2(-26,-22))
    rev.anchor_left = 1; rev.anchor_right = 1; rev.anchor_top = 1; rev.anchor_bottom = 1
    rev.button_down.connect(func(): mobile_reverse = true)
    rev.button_up.connect(func(): mobile_reverse = false)
    rev.name = "HUD_Reverse"
    root.add_child(rev)
    required_mobile_buttons.assign([exit_button, accel, stop, rev])
    # V0.5.24: edição da HUD fica somente em Configurações > HUD.

func set_mobile_ui_enabled(enabled: bool) -> void:
    enabled = enabled or OS.has_feature("mobile")
    touch_ui_enabled = enabled
    if ui_layer != null:
        ui_layer.visible = is_instance_valid(driver)
    if ui_layer != null:
        for child in ui_layer.find_children("*","Button",true,false):
            var button := child as Button
            if button == null or not String(button.name).begins_with("HUD_"):
                continue
            if String(button.name) in ["HUD_Edit", "HUD_Camera"]:
                button.visible = false
                continue
            button.visible = enabled
    if steering_pad != null:
        steering_pad.visible = enabled and steering_mode == 1
    if steering_left_button != null:
        steering_left_button.visible = enabled and steering_mode == 0
    if steering_right_button != null:
        steering_right_button.visible = enabled and steering_mode == 0
    if enabled:
        call_deferred("_clamp_vehicle_hud_to_screen")

func _clamp_vehicle_hud_to_screen() -> void:
    var screen := get_viewport().get_visible_rect().size
    for target in get_hud_items().values():
        var control := target as Control
        if control == null:
            continue
        var rect := control.get_global_rect()
        var lower := Vector2(8, 8)
        var upper := (screen - rect.size - Vector2(8, 8)).max(lower)
        control.position += rect.position.clamp(lower, upper) - rect.position

func set_mobile_steering_mode(mode: int) -> void:
    steering_mode = clampi(mode, 0, 1)
    mobile_left = false
    mobile_right = false
    if steering_pad != null:
        steering_pad.visible = touch_ui_enabled and steering_mode == 1
        steering_pad.set("value", Vector2.ZERO)
        steering_pad.set("active_touch", -1)
        steering_pad.queue_redraw()
    if steering_left_button != null:
        steering_left_button.visible = touch_ui_enabled and steering_mode == 0
    if steering_right_button != null:
        steering_right_button.visible = touch_ui_enabled and steering_mode == 0

func get_hud_items() -> Dictionary:
    var result: Dictionary = {}
    if ui_layer == null:
        return result
    for child in ui_layer.get_child(0).get_children():
        if child is Control and String(child.name).begins_with("HUD_"):
            result[String(child.name)] = child
    result.erase("HUD_Edit")
    result.erase("HUD_Camera")
    if steering_mode == 1:
        result.erase("HUD_SteerLeft")
        result.erase("HUD_SteerRight")
    else:
        result.erase("HUD_SteeringPad")
    return result

func apply_saved_hud_positions(positions: Dictionary) -> void:
    var screen: Vector2 = get_viewport().get_visible_rect().size
    for key in get_hud_items():
        if not positions.has(key):
            continue
        var target: Control = get_hud_items()[key] as Control
        var saved: Variant = positions[key]
        if not saved is Vector2:
            continue
        var normalized: Vector2 = saved
        if not normalized.is_finite():
            continue
        normalized.x = clampf(normalized.x, 0.0, 1.0)
        normalized.y = clampf(normalized.y, 0.0, 1.0)
        target.position += normalized * screen - target.get_global_rect().get_center()

func _apply_saved_hud_scale(scale_value: float) -> void:
    if not is_finite(scale_value):
        scale_value = 1.20
    var hud_scale := clampf(scale_value, 0.95, 1.55)
    if ui_layer == null:
        return
    for item in ui_layer.find_children("*", "Button", true, false):
        var button := item as Button
        if button == null or not String(button.name).begins_with("HUD_"):
            continue
        if String(button.name) in ["HUD_Edit", "HUD_Camera"]:
            button.visible = false
            continue
        if not button.has_meta("base_rect"):
            button.set_meta("base_rect", Rect2(button.position, button.size))
        var base: Rect2 = button.get_meta("base_rect")
        var center_before := button.get_global_rect().get_center()
        var new_size := base.size * hud_scale
        button.size = new_size
        button.pivot_offset = new_size * 0.5
        button.position += center_before - button.get_global_rect().get_center()
        var base_font := int(button.get_meta("base_font_size", 22))
        button.add_theme_font_size_override("font_size", int(round(base_font * hud_scale)))

func _load_mobile_hud_settings() -> void:
    var config := ConfigFile.new()
    if config.load("user://personal_v013.cfg") != OK:
        set_mobile_steering_mode(0)
        return
    set_mobile_steering_mode(int(config.get_value("settings", "steering_mode", 0)))
    set_user_camera_fov(float(config.get_value("settings", "vehicle_fov", 72.0)))
    _apply_saved_hud_scale(float(config.get_value("settings", "hud_button_scale", 1.20)))
    apply_saved_hud_positions(config.get_value("settings", "hud_positions", {}))

func _button(t: String, a: Vector2, b: Vector2) -> Button:
    var x := preload("res://scripts/mobile_action_button.gd").new()
    x.configure(t, "Virar à esquerda" if t == "◀" else ("Virar à direita" if t == "▶" else t))
    # Keep the original layout IDs, including the steering arrows.
    x.set_meta("hud_label", t)
    x.visible = touch_ui_enabled
    x.focus_mode = Control.FOCUS_NONE
    var width: float = absf(b.x - a.x)
    var height: float = absf(b.y - a.y)
    var size: float = maxf(72.0, maxf(width, height) * 0.64)
    var center := Vector2((a.x + b.x) * 0.5, (a.y + b.y) * 0.5)
    x.offset_left = center.x - size * 0.5
    x.offset_top = center.y - size * 0.5
    x.offset_right = center.x + size * 0.5
    x.offset_bottom = center.y + size * 0.5
    x.pivot_offset = Vector2(size * 0.5, size * 0.5)
    x.set_meta("base_font_size", 22)
    x.add_theme_font_size_override("font_size", 22)
    return x

func _finish_imported_materials(model_root: Node = null) -> void:
    var material_cache: Dictionary = {}
    var source_root: Node = model_root if model_root != null else self
    for item in source_root.find_children("*","MeshInstance3D",true,false):
        var part := item as MeshInstance3D
        if part == null or part.mesh == null:
            continue
        if OS.has_feature("mobile") and not part.is_visible_in_tree():
            continue
        for index in range(part.mesh.get_surface_count()):
            var source := part.get_active_material(index)
            if not source is StandardMaterial3D:
                continue
            var title: String = source.resource_name.to_lower()
            var category: String = ""
            if "borracha" in title:
                category = "rubber"
            elif ("glass" in title or "window" in title) and not "lights" in title:
                category = "glass"
            if category.is_empty():
                continue

            var key: String = "%d:%s" % [source.get_instance_id(),category]
            var mat: StandardMaterial3D = material_cache.get(key) as StandardMaterial3D
            if mat == null:
                mat = source.duplicate() as StandardMaterial3D
                if category == "rubber":
                    mat.albedo_color = Color(.055,.058,.062)
                    mat.roughness = .92
                    mat.metallic = 0.0
                else:
                    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                    mat.albedo_color = Color(.15,.23,.29,.36)
                    mat.roughness = .18
                material_cache[key] = mat
            part.set_surface_override_material(index,mat)
