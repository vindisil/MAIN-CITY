extends SkeletonModifier3D
## Mira pelos bracos; a coluna recebe apenas uma inclinacao vertical limitada.
var target_direction := Vector3.FORWARD
var aim_weight: float = 0.0
@export_range(0.0, 0.15, 0.005) var aim_right_offset_m: float = 0.04
var shoulder_aim_weight: float = 0.0
var recoil: float = 0.0
var grip_transform := Transform3D.IDENTITY
var has_support_grip: bool = false
var support_grip := Vector3.ZERO
var support_weight: float = 0.0
var left_palm_offset := Vector3(0.0, 0.06, 0.0)
var spine_indices := PackedInt32Array()
var right_arm_index: int = -1
var right_elbow_index: int = -1
var left_arm_index: int = -1
var left_elbow_index: int = -1
var left_hand_index: int = -1
var hand_index: int = -1
var chest_pitch: float = 0.0
var support_hand_error: float = 0.0
var stabilize_jump: bool = false
var allow_jump_release: bool = true
var jump_release_weight: float = 0.0
var jump_arm_indices := PackedInt32Array()
var grounded_arm_rotations: Array[Quaternion] = []

func _validate_bone_names() -> void:
    var sk := get_skeleton()
    if sk == null:
        return
    spine_indices.clear()
    for bone_name in ["spine_02", "spine_03"]:
        var index := sk.find_bone(bone_name)
        if index >= 0:
            spine_indices.append(index)
    right_arm_index = sk.find_bone("upperarm_r")
    right_elbow_index = sk.find_bone("lowerarm_r")
    left_arm_index = sk.find_bone("upperarm_l")
    left_elbow_index = sk.find_bone("lowerarm_l")
    left_hand_index = sk.find_bone("hand_l")
    hand_index = sk.find_bone("hand_r")
    jump_arm_indices.clear()
    for name in ["clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]:
        var index := sk.find_bone(name)
        if index >= 0:
            jump_arm_indices.append(index)
    var middle_index := sk.find_bone("middle_01_l")
    if middle_index >= 0 and left_hand_index >= 0:
        left_palm_offset = (sk.get_bone_global_rest(left_hand_index).affine_inverse() * sk.get_bone_global_rest(middle_index).origin) * 0.65

func _process_modification_with_delta(delta: float) -> void:
    var sk := get_skeleton()
    if sk == null:
        return
    if hand_index < 0:
        _validate_bone_names()
    _stabilize_unarmed_jump(sk, delta)
    if aim_weight <= 0.001 and (not has_support_grip or support_weight <= 0.001):
        return
    if right_arm_index < 0 or right_elbow_index < 0 or hand_index < 0 or target_direction.length_squared() < 0.001:
        return
    var hand_pose := sk.get_bone_global_pose(hand_index)
    var support_pose := sk.get_bone_global_pose(left_hand_index) if left_hand_index >= 0 else Transform3D.IDENTITY
    var support_from_grip := hand_pose.affine_inverse() * support_pose
    if aim_weight > 0.001:
        _aim_right_arm(sk)
    if left_hand_index < 0:
        return
    var right_hand := sk.get_bone_global_pose(hand_index)
    var target := right_hand * support_from_grip
    if has_support_grip:
        target.origin = right_hand * support_grip - target.basis * left_palm_offset
        var current := sk.get_bone_global_pose(left_hand_index)
        target.origin = current.origin.lerp(target.origin, support_weight)
        target.basis = Basis(current.basis.get_rotation_quaternion().slerp(target.basis.get_rotation_quaternion(), support_weight))
    support_hand_error = _solve_arm(sk, left_arm_index, left_elbow_index, left_hand_index, target)

func _stabilize_unarmed_jump(sk: Skeleton3D, delta: float) -> void:
    # Guarda a ultima pose natural no chao. O blend do salto original cruzava
    # uma volta completa no braco direito; a slerp usa sempre o arco mais curto.
    if grounded_arm_rotations.size() != jump_arm_indices.size():
        grounded_arm_rotations.clear()
        for index in jump_arm_indices:
            grounded_arm_rotations.append(sk.get_bone_global_pose(index).basis.get_rotation_quaternion())
    if stabilize_jump:
        jump_release_weight = 1.0
    elif allow_jump_release:
        jump_release_weight = move_toward(jump_release_weight, 0.0, delta * 6.0)
    else:
        jump_release_weight = 0.0
    for i in range(jump_arm_indices.size()):
        var index := jump_arm_indices[i]
        var pose := sk.get_bone_global_pose(index)
        var animated := pose.basis.get_rotation_quaternion()
        if jump_release_weight > 0.001:
            pose.basis = Basis(animated.slerp(grounded_arm_rotations[i], jump_release_weight)).scaled(pose.basis.get_scale())
            sk.set_bone_global_pose(index, pose)
        else:
            grounded_arm_rotations[i] = animated

func _aim_right_arm(sk: Skeleton3D) -> void:
    var local_direction := (sk.global_basis.inverse() * target_direction).normalized()
    var flat_direction := Vector3(local_direction.x, 0.0, local_direction.z).normalized()
    var right := Vector3.UP.cross(flat_direction).normalized()
    if right.length_squared() < 0.01:
        return
    chest_pitch = clampf(asin(local_direction.y) * 0.25, deg_to_rad(-14.0), deg_to_rad(12.0)) * aim_weight
    for index in spine_indices:
        var pose := sk.get_bone_global_pose(index)
        pose.basis = Basis(Quaternion(right, -chest_pitch / float(spine_indices.size()))) * pose.basis
        sk.set_bone_global_pose(index, pose)

    var hand_pose := sk.get_bone_global_pose(hand_index)
    var shot_direction := Quaternion(right, -recoil) * local_direction
    var arm_pose := sk.get_bone_global_pose(right_arm_index)
    var elbow_pose := sk.get_bone_global_pose(right_elbow_index)
    var arm_length := arm_pose.origin.distance_to(elbow_pose.origin) + elbow_pose.origin.distance_to(hand_pose.origin)
    var side := signf(arm_pose.origin.x)
    var extension := 0.30 if has_support_grip else 0.65
    var grip_position := arm_pose.origin + shot_direction * arm_length * extension - Vector3.UP * 0.045 - right * side * 0.025
    # Desloca a mao e a arma para a direita da camera em metros de mundo.
    # A mao de apoio acompanha pelo grip, sem girar o tronco para o lado.
    var camera_right := target_direction.cross(Vector3.UP).normalized()
    grip_position += sk.global_basis.inverse() * (camera_right * aim_right_offset_m * shoulder_aim_weight)
    var gun_right := Vector3.UP.cross(shot_direction).normalized()
    var gun_basis := Basis(gun_right, shot_direction.cross(gun_right).normalized(), shot_direction)
    var hand_basis := gun_basis * grip_transform.basis.orthonormalized().inverse()
    var hand_target := Transform3D(
        Basis(hand_pose.basis.get_rotation_quaternion().slerp(hand_basis.get_rotation_quaternion(), aim_weight)),
        hand_pose.origin.lerp(grip_position, aim_weight))
    _solve_arm(sk, right_arm_index, right_elbow_index, hand_index, hand_target)

func _solve_arm(sk: Skeleton3D, upper_index: int, elbow_index: int, wrist_index: int, target: Transform3D) -> float:
    if upper_index < 0 or elbow_index < 0 or wrist_index < 0:
        return 0.0
    var upper := sk.get_bone_global_pose(upper_index)
    var elbow := sk.get_bone_global_pose(elbow_index)
    var hand := sk.get_bone_global_pose(wrist_index)
    var upper_length := upper.origin.distance_to(elbow.origin)
    var lower_length := elbow.origin.distance_to(hand.origin)
    var offset := target.origin - upper.origin
    if offset.length_squared() < 0.00001 or upper_length < 0.001 or lower_length < 0.001:
        return hand.origin.distance_to(target.origin)
    var direction := offset.normalized()
    var reach := clampf(offset.length(), absf(upper_length - lower_length) + 0.001, upper_length + lower_length - 0.001)
    var pole := Vector3.DOWN + Vector3.RIGHT * signf(upper.origin.x) * 0.35
    pole -= direction * pole.dot(direction)
    if pole.length_squared() < 0.00001:
        pole = Vector3.DOWN - direction * Vector3.DOWN.dot(direction)
    if pole.length_squared() < 0.00001:
        pole = Vector3.RIGHT - direction * Vector3.RIGHT.dot(direction)
    pole = pole.normalized()
    var along := (upper_length * upper_length + reach * reach - lower_length * lower_length) / (2.0 * reach)
    var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
    var elbow_target := upper.origin + direction * along + pole * height
    upper.basis = Basis(Quaternion((elbow.origin - upper.origin).normalized(), (elbow_target - upper.origin).normalized())) * upper.basis
    sk.set_bone_global_pose(upper_index, upper)
    elbow = sk.get_bone_global_pose(elbow_index)
    hand = sk.get_bone_global_pose(wrist_index)
    var hand_target := upper.origin + direction * reach
    elbow.basis = Basis(Quaternion((hand.origin - elbow.origin).normalized(), (hand_target - elbow.origin).normalized())) * elbow.basis
    sk.set_bone_global_pose(elbow_index, elbow)
    hand = sk.get_bone_global_pose(wrist_index)
    hand.basis = target.basis
    sk.set_bone_global_pose(wrist_index, hand)
    return hand.origin.distance_to(target.origin)
