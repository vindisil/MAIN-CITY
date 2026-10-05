extends Node3D

var phase: int = 0
var elapsed: float = 0.0

func _ready() -> void:
    _apply_phase()

func _process(delta: float) -> void:
    elapsed += delta
    var phase_duration: float = 1.35 if phase == 1 or phase == 3 else 6.0
    if elapsed >= phase_duration:
        elapsed = 0.0
        phase = (phase + 1) % 4
        _apply_phase()

func _apply_phase() -> void:
    for child_value in get_children():
        if not (child_value is Node3D):
            continue
        var light_root := child_value as Node3D
        if not str(light_root.name).begins_with("TrafficLight_"):
            continue
        var parts: PackedStringArray = str(light_root.name).split("_")
        var index: int = 0
        if parts.size() > 1:
            index = int(parts[1])
        var even_group: bool = index % 2 == 0
        var red := light_root.get_node_or_null("Red") as MeshInstance3D
        var yellow := light_root.get_node_or_null("Yellow") as MeshInstance3D
        var green := light_root.get_node_or_null("Green") as MeshInstance3D
        if red == null or yellow == null or green == null:
            continue
        var show_red: bool = false
        var show_yellow: bool = false
        var show_green: bool = false
        match phase:
            0:
                show_green = even_group
                show_red = not even_group
            1:
                show_yellow = even_group
                show_red = not even_group
            2:
                show_red = even_group
                show_green = not even_group
            3:
                show_red = even_group
                show_yellow = not even_group
        red.visible = show_red
        yellow.visible = show_yellow
        green.visible = show_green
