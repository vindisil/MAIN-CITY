@tool
extends Node3D
## Editor-only visual preview. Never executes while playing (including F5).
## Edit res://scenes/MAPA_EDITOR_3D.tscn for the complete city.

const PREVIEW_RADIUS: int = 1  # 3x3 central sectors in main.tscn editor
var _built: bool = false

func _ready() -> void:
    if not Engine.is_editor_hint():
        return
    call_deferred("_build_preview")

func _build_preview() -> void:
    if not Engine.is_editor_hint() or _built or not is_inside_tree():
        return
    _built = true
    if get_node_or_null("PreviaEditor_3D") != null:
        return
    var preview_root := Node3D.new()
    preview_root.name = "PreviaEditor_3D"
    add_child(preview_root)
    # Unowned child: preview is not saved into main.tscn and does not
    # create permanent duplicate geometry in the game.
    for x in range(-PREVIEW_RADIUS, PREVIEW_RADIUS + 1):
        for z in range(-PREVIEW_RADIUS, PREVIEW_RADIUS + 1):
            var path: String = "res://scenes/city_chunks/cell_%d_%d.tscn" % [x, z]
            var sector: PackedScene = load(path) as PackedScene
            if sector == null:
                continue
            var instance := sector.instantiate() as Node3D
            if instance == null:
                continue
            instance.name = "Setor_%d_%d" % [x, z]
            preview_root.add_child(instance)

func _exit_tree() -> void:
    _built = false
