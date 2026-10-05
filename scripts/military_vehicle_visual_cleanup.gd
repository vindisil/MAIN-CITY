extends Node3D
## Oculta apenas rodas originalmente embutidas no modelo importado.
@export var hide_tokens: PackedStringArray = ["wheel", "bone_wheel", "tire", "pneu", "roda"]

func _ready() -> void:
    call_deferred("_hide_authored_wheels")

func _hide_authored_wheels() -> void:
    var owner_root := get_parent() as Node3D
    if owner_root == null:
        return
    var target: Node3D = owner_root.get_node_or_null("BodyModel") as Node3D
    if target == null:
        target = owner_root
    for item in target.find_children("*", "Node3D", true, false):
        var lower := String(item.name).to_lower()
        for token in hide_tokens:
            if lower.begins_with(String(token).to_lower()) or lower.contains(String(token).to_lower()):
                (item as Node3D).visible = false
                break
