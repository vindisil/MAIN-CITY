extends Node3D
## Mantem a ambulancia visivel e remove somente o piso de apresentacao do GLB.
## Na versao dirigivel, oculta tambem as quatro rodas importadas porque
## os VehicleWheel3D usam os mesmos modelos de roda da Duster do Main City.

@export var hide_imported_wheels: bool = false

const IMPORTED_WHEEL_NODES := {
    "wheel_fl_8": true,
    "wheel_fr_9": true,
    "wheel_rl_10": true,
    "wheel_rr_11": true,
}

func _ready() -> void:
    _clean_visual(self)
    if OS.has_feature("mobile"):
        _optimize_small_parts(self)

func _clean_visual(root: Node) -> void:
    for child in root.get_children():
        if child is Node3D:
            var node3d := child as Node3D
            var node_name := String(node3d.name)
            # NUNCA esconder BASE_0: a ambulancia inteira e filha dele.
            if node_name == "Object_4" and node3d.get_parent() != null and String(node3d.get_parent().name) == "BASE_0":
                node3d.visible = false
            elif hide_imported_wheels and IMPORTED_WHEEL_NODES.has(node_name):
                node3d.visible = false
        _clean_visual(child)

func _optimize_small_parts(root: Node) -> void:
    for child in root.get_children():
        if child is MeshInstance3D:
            (child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _optimize_small_parts(child)
