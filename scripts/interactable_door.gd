extends Node3D

var opened := false
var closed_y := 0.0

func _ready() -> void:
    closed_y = rotation.y

func interact(_player: Node = null) -> void:
    opened = not opened
    var target := closed_y + (deg_to_rad(-92.0) if opened else 0.0)
    var tween := create_tween()
    tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
    tween.tween_property(self, "rotation:y", target, 0.35)
