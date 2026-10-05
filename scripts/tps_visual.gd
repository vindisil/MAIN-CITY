extends Node3D
## Personagem, esqueleto, armas e AnimationTree nativos do Third Person Shooter.
const CHARACTER = preload("res://assets/third_person_shooter/character.glb")
const WEAPONS = preload("res://scripts/tps_weapons.gd")
const BLEND_TREE = preload("res://assets/third_person_shooter/locomotion.tres")
const AIM_MODIFIER = preload("res://scripts/tps_aim_modifier.gd")
var motion_ready: bool = false
var skeleton: Skeleton3D
var animation_tree: AnimationTree
var animation_player: AnimationPlayer
var weapon_rig: BoneAttachment3D
var weapon_nodes: Array[Node3D] = []
var weapon_muzzles: Array[Marker3D] = []
var weapon_flashes: Array[MeshInstance3D] = []
var aim_modifier: SkeletonModifier3D
var aim_weight: float = 0.0
var recoil: float = 0.0
var current_motion_speed: float = 0.0
var current_running: bool = false
var crouching: bool = false
var rolling: bool = false
var last_weapon: int = -1
var reload_was_active: bool = false
var equip_weight: float = 0.0
var _transitions: Dictionary = {}

func _ready() -> void:
    var model := CHARACTER.instantiate() as Node3D
    model.name = "Model"
    add_child(model)
    skeleton = model.get_node("Godot_Chan_Stealth/Skeleton3D") as Skeleton3D
    animation_player = model.get_node("AnimationPlayer") as AnimationPlayer
    weapon_rig = BoneAttachment3D.new()
    weapon_rig.name = "WeaponRig"
    weapon_rig.bone_name = "hand_r"
    skeleton.add_child(weapon_rig)
    for index in range(WEAPONS.SCENES.size()):
        _add_weapon(WEAPONS.NAMES[index], WEAPONS.SCENES[index], WEAPONS.attachment(index))
    animation_tree = AnimationTree.new()
    animation_tree.name = "AnimationTree"
    animation_tree.tree_root = BLEND_TREE.duplicate(true)
    add_child(animation_tree)
    animation_tree.anim_player = animation_tree.get_path_to(animation_player)
    animation_tree.root_node = animation_tree.get_path_to(model)
    animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
    _transition("ag_transition", "on_ground")
    _transition("ag_weapon_transition", "on_ground")
    _transition("aim_transition", "not_aiming")
    _transition("cs_transition", "standing")
    _set_parameter("iwr_blend/blend_amount", -1.0)
    _set_parameter("weapon_blend/blend_amount", 0.0)
    _set_parameter("walk/blend_position", Vector2(0,1))
    _set_parameter("walk_scale/scale", 2.2)
    _set_parameter("run_scale/scale", 1.0)
    _set_parameter("reload_scale/scale", 0.8)
    _set_parameter("weapon_switch_scale/scale", 1.2)
    _set_parameter("neck_front/blend_amount", 0.0)
    animation_tree.active = true
    aim_modifier = AIM_MODIFIER.new()
    aim_modifier.name = "AimPitch"
    skeleton.add_child(aim_modifier)
    motion_ready = true
    animation_tree.advance(0.0)
    var min_y: float = INF
    var max_y: float = -INF
    for item in model.find_children("*", "MeshInstance3D", true, false):
        if weapon_rig.is_ancestor_of(item):
            continue
        var body_mesh := item as MeshInstance3D
        var box := body_mesh.get_aabb()
        var relative := global_transform.affine_inverse() * body_mesh.global_transform
        for corner in range(8):
            var point := relative * box.get_endpoint(corner)
            min_y = minf(min_y,point.y)
            max_y = maxf(max_y,point.y)
    if max_y > min_y:
        var size_factor := 2.4 / (max_y-min_y)
        scale = Vector3.ONE * size_factor
        position.y = -min_y*size_factor

func _add_weapon(node_name: String, scene: PackedScene, source_transform: Transform3D) -> void:
    var container := Node3D.new()
    container.name = node_name
    weapon_rig.add_child(container)
    var model := scene.instantiate() as Node3D
    container.add_child(model)
    model.transform = source_transform
    var points := PackedVector3Array()
    var front_z: float = -INF
    for item in model.find_children("*", "MeshInstance3D", true, false):
        var gun_mesh := item as MeshInstance3D
        var local := model.global_transform.affine_inverse() * gun_mesh.global_transform
        for surface_index in range(gun_mesh.mesh.get_surface_count()):
            var vertices: PackedVector3Array = gun_mesh.mesh.surface_get_arrays(surface_index)[Mesh.ARRAY_VERTEX]
            for vertex in vertices:
                var point := local * vertex
                points.append(point)
                front_z = maxf(front_z, point.z)
    var barrel_tip := Vector3.ZERO
    var tip_count: int = 0
    for point in points:
        if point.z >= front_z - 0.015:
            barrel_tip += point
            tip_count += 1
    barrel_tip /= maxf(float(tip_count), 1.0)
    var muzzle := Marker3D.new()
    muzzle.name = "Muzzle"
    container.add_child(muzzle)
    muzzle.position = source_transform * barrel_tip
    var authored_muzzle := model.find_child("Muzzle", true, false) as Node3D
    if authored_muzzle != null:
        muzzle.position = container.global_transform.affine_inverse() * authored_muzzle.global_position
    container.set_meta("grip_transform",source_transform)
    var support := model.find_child("SupportGrip", true, false) as Node3D
    if support != null:
        container.set_meta("support_grip", container.global_transform.affine_inverse() * support.global_position)
    var flash := MeshInstance3D.new()
    flash.name = "MuzzleFlash"
    var mesh := SphereMesh.new()
    mesh.radius = 0.038 if WEAPONS.ANIMATION_KIND[weapon_nodes.size()] == 0 else 0.027
    mesh.height = 0.10 if WEAPONS.ANIMATION_KIND[weapon_nodes.size()] == 0 else 0.075
    mesh.radial_segments = 8
    mesh.rings = 3
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(1.0,0.90,0.45)
    mat.emission_enabled = true
    mat.emission = Color(1.0,0.55,0.16)
    mat.emission_energy_multiplier = 2.5
    mesh.material = mat
    flash.mesh = mesh
    flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle.add_child(flash)
    flash.visible = false
    container.visible = false
    weapon_nodes.append(container)
    weapon_muzzles.append(muzzle)
    weapon_flashes.append(flash)

func _set_parameter(parameter: String, value: Variant) -> void:
    animation_tree.set("parameters/" + parameter, value)

func _transition(node_name: String, state: String) -> void:
    if _transitions.get(node_name) == state:
        return
    _transitions[node_name] = state
    _set_parameter(node_name + "/transition_request", state)

func set_motion(speed: float, _armed: bool, running: bool = false, _delta: float = 0.016) -> void:
    current_motion_speed = speed
    current_running = running

func update_pose(delta: float, aimed: bool, direction: Vector3, weapon: int, airborne: bool, vertical_speed: float, _landing: float, reload_progress: float = -1.0, _switch_progress: float = -1.0, firing: bool = false) -> void:
    if not motion_ready:
        return
    var armed := weapon >= 0
    var player := get_parent()
    crouching = bool(player.get("crouching"))
    rolling = float(player.get("roll_remaining")) > 0.0
    var raised := aimed or firing
    var can_hold := armed and not rolling and reload_progress < 0.0 and _switch_progress < 0.0
    var can_aim := raised and can_hold
    aim_weight = move_toward(aim_weight, 1.0 if can_aim else 0.0, delta*10.0)
    recoil = move_toward(recoil, 0.0, delta*0.5)
    equip_weight = move_toward(equip_weight, 1.0 if armed else 0.0, delta*10.0)
    if weapon != last_weapon:
        _set_parameter("reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
        if armed:
            var animation_kind: int = WEAPONS.ANIMATION_KIND[weapon]
            for kind in ["aim","idle","on_air","run","switch"]:
                _set_parameter("weapon_change_"+kind+"/blend_position", float(animation_kind))
            _set_parameter("weapon_switch_scale/scale", 1.2 if animation_kind == 0 else 1.5)
            _set_parameter("weapon_switch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
        else:
            _set_parameter("weapon_switch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
        last_weapon = weapon
    for i in range(weapon_nodes.size()):
        weapon_nodes[i].visible = i == weapon
    if reload_progress >= 0.0 and not reload_was_active:
        _set_parameter("reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
    elif reload_progress < 0.0 and reload_was_active:
        _set_parameter("reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    reload_was_active = reload_progress >= 0.0
    _transition("ag_transition", "on_air" if airborne else "on_ground")
    _transition("ag_weapon_transition", "on_air" if airborne else "on_ground")
    _transition("aim_transition", "aiming" if raised and armed else "not_aiming")
    _transition("cs_transition", "crouching" if crouching else "standing")
    var move_axis: Vector2 = player.get("input_dir")
    var blend_axis := Vector2(move_axis.x, -move_axis.y) if aimed else Vector2(0,1)
    if current_motion_speed < 0.05:
        blend_axis = Vector2.ZERO
    _set_parameter("walk/blend_position", blend_axis)
    _set_parameter("crouch_walk/blend_position", blend_axis)
    var walk_speed := 2.2
    var run_speed := 5.0
    var blend := clampf((current_motion_speed - walk_speed) / walk_speed, -1, 0) if current_motion_speed <= walk_speed else clampf((current_motion_speed-walk_speed)/(run_speed-walk_speed),0,1)
    _set_parameter("iwr_blend/blend_amount", 0.0 if aimed else blend)
    _set_parameter("ir_rifle_blend/blend_amount", maxf(0.0,blend))
    _set_parameter("crouch_iw_blend/blend_amount", clampf(current_motion_speed,0,1))
    _set_parameter("weapon_blend/blend_amount", equip_weight)
    _set_parameter("roll_blend/blend_position", equip_weight)
    _set_parameter("jump_blend/blend_position", clampf(vertical_speed/15.0,-1,1))
    aim_modifier.set("stabilize_jump", airborne and not armed and not rolling)
    aim_modifier.set("allow_jump_release", not armed and not rolling)
    aim_modifier.set("aim_weight", aim_weight)
    aim_modifier.set("shoulder_aim_weight", move_toward(float(aim_modifier.get("shoulder_aim_weight")), 1.0 if can_hold and aimed else 0.0, delta * 10.0))
    aim_modifier.set("target_direction", direction)
    aim_modifier.set("recoil", recoil)
    aim_modifier.set("support_weight", move_toward(float(aim_modifier.get("support_weight")), 1.0 if can_hold else 0.0, delta * 10.0))
    aim_modifier.set("has_support_grip", armed and weapon_nodes[weapon].has_meta("support_grip"))
    if armed:
        aim_modifier.set("grip_transform",weapon_nodes[weapon].get_meta("grip_transform"))
        aim_modifier.set("support_grip", weapon_nodes[weapon].get_meta("support_grip", Vector3.ZERO))
    animation_tree.advance(delta)

func start_roll() -> void:
    _set_parameter("reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    _set_parameter("weapon_switch/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
    _set_parameter("roll/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func get_pose_skeleton() -> Skeleton3D:
    return skeleton

# O personagem original do pacote e unico; cargos continuam no GameState.
func set_police_mode(_enabled: bool) -> void: pass
func set_medical_mode(_enabled: bool) -> void: pass
func set_military_mode(_enabled: bool) -> void: pass
