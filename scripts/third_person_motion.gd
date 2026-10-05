extends SkeletonModifier3D
## Main City - movimentos completos adaptados do Godot Third Person Shooter.
## Este e o UNICO modificador de animacao do personagem ativo.
## A locomocao antiga do Real Controller foi removida da cena.

const DATA_PATH := "res://assets/animations/third_person_motion.json"
const PISTOL_INDEX := 2
const IDENTITY_Q := Quaternion(0.0, 0.0, 0.0, 1.0)

var visual: Node3D = null
var skeleton: Skeleton3D = null
var weapon_rig: Node3D = null
var clips: Dictionary = {}
var mapping: Dictionary = {}
var source_rest: Dictionary = {}
var bone_indices: Dictionary = {}
var corrections: Dictionary = {}

var animation_ready: bool = false
var aim_weight: float = 0.0
var recoil: float = 0.0
var clip_clock: float = 0.0
var previous_clock: float = 0.0
var current_clip: String = ""
var previous_clip: String = ""
var clip_blend: float = 1.0

var state_speed: float = 0.0
var state_input: Vector2 = Vector2.ZERO
var state_sprinting: bool = false
var state_crouched: bool = false
var state_rolling: bool = false
var state_roll_progress: float = -1.0
var state_armed: bool = false
var state_aimed: bool = false
var state_weapon: int = -1
var state_airborne: bool = false
var state_vertical_speed: float = 0.0
var state_reload_progress: float = -1.0
var state_switch_progress: float = -1.0

func setup(owner_visual: Node3D) -> void:
    visual = owner_visual
    skeleton = get_parent() as Skeleton3D
    if visual != null:
        weapon_rig = visual.get_node_or_null("WeaponRig") as Node3D
    if skeleton == null or weapon_rig == null:
        push_error("Main City Third Person: GeneralSkeleton/WeaponRig nao encontrado.")
        return

    var raw := FileAccess.get_file_as_string(DATA_PATH)
    if raw.is_empty():
        push_error("Main City Third Person: dados de movimento ausentes: %s" % DATA_PATH)
        return
    var parsed: Variant = JSON.parse_string(raw)
    if not (parsed is Dictionary):
        push_error("Main City Third Person: JSON de movimento invalido.")
        return
    var data: Dictionary = parsed
    clips = data.get("clips", {})
    mapping = data.get("mapping", {})
    source_rest = data.get("source_rest", {})

    bone_indices.clear()
    corrections.clear()
    for source_name_value in mapping.keys():
        var source_name := String(source_name_value)
        var target_name := String(mapping[source_name])
        var bone_index := skeleton.find_bone(target_name)
        if bone_index < 0 or not source_rest.has(source_name):
            continue
        var source_q := _quat_from_array(source_rest[source_name])
        var target_q := skeleton.get_bone_rest(bone_index).basis.get_rotation_quaternion().normalized()
        bone_indices[source_name] = bone_index
        corrections[source_name] = (target_q.inverse() * source_q).normalized()

    animation_ready = bone_indices.size() >= 45 and clips.size() >= 30
    active = true
    influence = 1.0
    if not animation_ready:
        push_error("Main City Third Person: retarget incompleto (%d ossos, %d clips)." % [bone_indices.size(), clips.size()])

func set_state(
    speed: float,
    input_vector: Vector2,
    sprinting: bool,
    crouched: bool,
    rolling: bool,
    roll_progress: float,
    armed: bool,
    aimed: bool,
    weapon: int,
    airborne: bool,
    vertical_speed: float,
    reload_progress: float = -1.0,
    switch_progress: float = -1.0
) -> void:
    state_speed = maxf(0.0, speed)
    state_input = input_vector
    state_sprinting = sprinting
    state_crouched = crouched
    state_rolling = rolling
    state_roll_progress = roll_progress
    state_armed = armed
    state_aimed = aimed
    state_weapon = weapon
    state_airborne = airborne
    state_vertical_speed = vertical_speed
    state_reload_progress = reload_progress
    state_switch_progress = switch_progress

func _process_modification_with_delta(delta: float) -> void:
    if not animation_ready or skeleton == null:
        return
    _apply_animation(maxf(delta, 0.0001))

func _apply_animation(delta: float) -> void:
    aim_weight = move_toward(aim_weight, 1.0 if state_aimed and state_armed else 0.0, delta * 10.0)
    recoil = move_toward(recoil, 0.0, delta * 0.24)

    var desired_clip := _select_base_clip()
    if desired_clip != current_clip:
        previous_clip = current_clip
        previous_clock = clip_clock
        current_clip = desired_clip
        clip_clock = 0.0
        clip_blend = 0.0
    else:
        clip_clock += delta * _playback_speed(current_clip)
    clip_blend = move_toward(clip_blend, 1.0, delta * 8.0)

    var current_time := _wrapped_time(current_clip, clip_clock)
    var previous_time := _wrapped_time(previous_clip, previous_clock)
    if not previous_clip.is_empty() and clip_blend < 0.999:
        previous_clock += delta * _playback_speed(previous_clip)
        previous_time = _wrapped_time(previous_clip, previous_clock)

    var action_clip := ""
    var action_time := 0.0
    if state_rolling:
        action_clip = "roll-rifle" if state_armed and state_weapon != PISTOL_INDEX else "roll"
        action_time = clampf(state_roll_progress, 0.0, 1.0) * _clip_length(action_clip)
    elif state_reload_progress >= 0.0 and state_armed:
        action_clip = "reload"
        action_time = clampf(state_reload_progress, 0.0, 1.0) * _clip_length(action_clip)
    elif state_switch_progress >= 0.0 and state_armed:
        action_clip = "weapon_switch_pistol" if state_weapon == PISTOL_INDEX else "weapon_switch_rifle"
        action_time = clampf(state_switch_progress, 0.0, 1.0) * _clip_length(action_clip)

    var aim_clip := "aim_pistol-loop" if state_weapon == PISTOL_INDEX else "aim_rifle-loop"

    for source_name_value in bone_indices.keys():
        var source_name := String(source_name_value)
        var bone_index: int = int(bone_indices[source_name])
        var desired := _mapped_rotation(current_clip, source_name, current_time)

        if not previous_clip.is_empty() and clip_blend < 0.999:
            var old_pose := _mapped_rotation(previous_clip, source_name, previous_time)
            desired = old_pose.slerp(desired, clip_blend).normalized()

        if not action_clip.is_empty():
            if state_rolling or _is_upper_body(source_name):
                var action_pose := _mapped_rotation(action_clip, source_name, action_time)
                desired = desired.slerp(action_pose, 1.0 if state_rolling else 0.96).normalized()
        elif aim_weight > 0.001 and state_armed and _is_upper_body(source_name):
            var aim_pose := _mapped_rotation(aim_clip, source_name, 0.0)
            desired = desired.slerp(aim_pose, aim_weight).normalized()

        skeleton.set_bone_pose_rotation(bone_index, desired)

    if state_armed and state_weapon >= 0:
        _attach_weapon_to_hand(state_weapon, delta)

func _select_base_clip() -> String:
    if state_airborne:
        if state_armed:
            return "on_air_pistol-loop" if state_weapon == PISTOL_INDEX else "on_air_rifle-loop"
        return "jump_up-loop" if state_vertical_speed >= 0.0 else "fall_down-loop"

    if state_crouched:
        if state_speed < 0.08 or state_input.length() < 0.08:
            return "crouch-loop"
        return _directional_clip(true)

    if state_speed < 0.08 or state_input.length() < 0.08:
        if state_armed:
            return "idle_pistol-loop" if state_weapon == PISTOL_INDEX else "idle_rifle-loop"
        return "idle-loop"

    if state_sprinting and state_input.y < 0.35:
        if state_armed and state_weapon != PISTOL_INDEX:
            return "run_forward_rifle-loop"
        return "run_forward-loop"
    return _directional_clip(false)

func _directional_clip(crouched: bool) -> String:
    var x := state_input.x
    var y := state_input.y
    var horizontal := absf(x) > 0.28
    var vertical := absf(y) > 0.28
    if crouched:
        if y < -0.28 and x < -0.28: return "crouch_walk_forward_left-loop"
        if y < -0.28 and x > 0.28: return "crouch_walk_forward_right-loop"
        if y > 0.28 and x < -0.28: return "crouch_walk_back_left-loop"
        if y > 0.28 and x > 0.28: return "crouch_walk_back_right-loop"
        if y < -0.28: return "crouch_walk_forward-loop"
        if y > 0.28: return "crouch_walk_back-loop"
        if x < -0.28: return "crouch_walk_left-loop"
        if x > 0.28: return "crouch_walk_right-loop"
        return "crouch-loop"
    if y < -0.28 and x < -0.28: return "walk_forward_left-loop"
    if y < -0.28 and x > 0.28: return "walk_forward_right-loop"
    if y > 0.28 and x < -0.28: return "walk_back_left-loop"
    if y > 0.28 and x > 0.28: return "walk_back_right-loop"
    if y < -0.28: return "walk_forward-loop"
    if y > 0.28: return "walk_backward-loop"
    if x < -0.28: return "walk_left-loop"
    if x > 0.28: return "walk_right-loop"
    if horizontal or vertical: return "walk_forward-loop"
    return "idle-loop"

func _playback_speed(clip_name: String) -> float:
    if clip_name.begins_with("walk_") or clip_name.begins_with("crouch_walk_"):
        return clampf(state_speed / 2.82, 0.72, 1.35)
    if clip_name.begins_with("run_forward"):
        return clampf(state_speed / 6.25, 0.78, 1.35)
    return 1.0

func _wrapped_time(clip_name: String, time_value: float) -> float:
    var length := _clip_length(clip_name)
    if length <= 0.0001:
        return 0.0
    return fmod(maxf(0.0, time_value), length)

func _clip_length(clip_name: String) -> float:
    if clip_name.is_empty():
        return 0.0
    var clip: Dictionary = clips.get(clip_name, {})
    return float(clip.get("length", 0.0))

func _mapped_rotation(clip_name: String, source_name: String, time_value: float) -> Quaternion:
    if clip_name.is_empty() or not source_rest.has(source_name) or not corrections.has(source_name):
        return IDENTITY_Q
    var clip: Dictionary = clips.get(clip_name, {})
    var tracks: Dictionary = clip.get("tracks", {})
    var track: Dictionary = tracks.get(source_name, {})
    if track.is_empty():
        return IDENTITY_Q
    var absolute_q := _sample_track(track, time_value)
    var rest_q := _quat_from_array(source_rest[source_name])
    var source_delta := (rest_q.inverse() * absolute_q).normalized()
    var correction: Quaternion = corrections[source_name]
    return (correction * source_delta * correction.inverse()).normalized()

func _sample_track(track: Dictionary, time_value: float) -> Quaternion:
    var times: Array = track.get("t", [])
    var values: Array = track.get("q", [])
    if times.is_empty() or values.is_empty():
        return IDENTITY_Q
    if times.size() == 1 or time_value <= float(times[0]):
        return _quat_from_array(values[0])
    var last := mini(times.size(), values.size()) - 1
    if time_value >= float(times[last]):
        return _quat_from_array(values[last])
    var low := 0
    var high := last
    while high - low > 1:
        var mid := int((low + high) / 2)
        if float(times[mid]) <= time_value:
            low = mid
        else:
            high = mid
    var t0 := float(times[low])
    var t1 := float(times[high])
    var alpha := 0.0 if is_equal_approx(t0, t1) else clampf((time_value - t0) / (t1 - t0), 0.0, 1.0)
    return _quat_from_array(values[low]).slerp(_quat_from_array(values[high]), alpha).normalized()

func _quat_from_array(value: Variant) -> Quaternion:
    if not (value is Array):
        return IDENTITY_Q
    var a: Array = value
    if a.size() < 4:
        return IDENTITY_Q
    return Quaternion(float(a[0]), float(a[1]), float(a[2]), float(a[3])).normalized()

func _is_upper_body(source_name: String) -> bool:
    return not (source_name == "Root" or source_name == "pelvis" or source_name.begins_with("thigh_") or source_name.begins_with("calf_") or source_name.begins_with("foot_") or source_name.begins_with("ball_"))

func _attach_weapon_to_hand(weapon: int, delta: float) -> void:
    if weapon_rig == null or skeleton == null or visual == null:
        return
    var hand_index := skeleton.find_bone("RightHand")
    if hand_index < 0:
        return
    var hand_pose: Transform3D = visual.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(hand_index)
    var pistol := weapon == PISTOL_INDEX
    var grip_basis := _hand_basis(Vector3(0.0, 0.08, 1.0), Vector3(1.0, 0.05, 0.0)) if pistol else _hand_basis(Vector3(0.0, 0.12, 1.0), Vector3(1.0, 0.10, 0.0))
    var right_grip := Vector3(-0.025, -0.045, -0.115) if pistol else Vector3(-0.09, -0.11, -0.40)
    var rig_basis := (hand_pose.basis.orthonormalized() * grip_basis.inverse()).orthonormalized()
    var rig_origin := hand_pose.origin - rig_basis * right_grip
    rig_origin += rig_basis * Vector3(0.0, 0.0, -recoil)
    var desired := Transform3D(rig_basis, rig_origin)
    weapon_rig.transform = weapon_rig.transform.interpolate_with(desired, 1.0 - exp(-22.0 * delta))

func _hand_basis(fingers: Vector3, palm: Vector3) -> Basis:
    var y := fingers.normalized()
    var z := (palm - y * palm.dot(y)).normalized()
    return Basis(y.cross(z).normalized(), y, z)
