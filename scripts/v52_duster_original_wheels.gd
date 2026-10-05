extends Node3D
## v0.0.52: remove the non-physical wheel/brake meshes embedded in the imported
## Duster body. The visible wheels are separate children of VehicleWheel3D,
## so they rotate, steer and follow suspension instead of staying frozen.

const HIDE_PREFIXES := ["w_fl", "w_fr", "w_rl", "w_rr", "w_br_l", "w_br_r"]

func _ready() -> void:
    call_deferred("_hide_original_wheels")

func _hide_original_wheels() -> void:
    var vehicle := get_parent() as VehicleBody3D
    if vehicle == null:
        return
    var body := vehicle.get_node_or_null("BodyModel") as Node3D
    if body == null:
        return
    _hide_matching_branches(body)

func _hide_matching_branches(node: Node) -> void:
    for child in node.get_children():
        var lower := String(child.name).to_lower()
        var should_hide := false
        for prefix in HIDE_PREFIXES:
            if lower.begins_with(prefix):
                should_hide = true
                break
        if should_hide and child is Node3D:
            (child as Node3D).visible = false
            continue
        _hide_matching_branches(child)
