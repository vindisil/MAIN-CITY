extends Node3D
## Material fosco compartilhado; somente paineis de carroceria recebem camuflagem.
const CAMOUFLAGE := preload("res://assets/materials/army_camouflage.tres")

func _ready() -> void:
    call_deferred("apply_paint")

func apply_paint() -> void:
    var vehicle := get_parent() as Node3D
    if vehicle == null:
        return
    var body := vehicle.get_node_or_null("BodyModel") as Node3D
    if body == null:
        return
    var materials: Dictionary = {}
    var painted := 0
    for node in body.find_children("*", "MeshInstance3D", true, false):
        var part := node as MeshInstance3D
        var title := String(part.name).to_lower()
        var is_truck_panel := title.contains("carpaint")
        var is_hammer_panel := title in ["body_tan", "body_flgrey", "body_grey"]
        if not is_truck_panel and not is_hammer_panel:
            continue
        if part.mesh == null:
            continue
        var local_scale := part.global_basis.get_scale().abs() / vehicle.global_basis.get_scale().abs()
        var key := str(local_scale)
        var paint := materials.get(key) as StandardMaterial3D
        if paint == null:
            paint = CAMOUFLAGE.duplicate() as StandardMaterial3D
            paint.uv1_scale = local_scale * 0.4
            materials[key] = paint
        for surface in range(part.mesh.get_surface_count()):
            part.set_surface_override_material(surface, paint)
            painted += 1
    set_meta("painted_surfaces", painted)
