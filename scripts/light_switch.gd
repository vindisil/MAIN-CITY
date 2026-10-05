extends Node3D

@export var target_path: NodePath

func interact(_player: Node = null) -> void:
    var light := get_node_or_null(target_path) as Light3D
    if light != null:
        light.visible = not light.visible
