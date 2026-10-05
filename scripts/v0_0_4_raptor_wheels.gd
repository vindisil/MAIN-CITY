extends Node3D
## As rodas visuais da Raptor agora sao instancias das quatro rodas originais
## da Mercedes GLS, declaradas na propria cena v30_6_raptor_dirigivel.tscn.
## Este script apenas oculta rodas antigas embutidas no GLB da carroceria;
## ele nao cria cilindros ou uma segunda roda junto ao VehicleWheel3D.

func _ready() -> void:
    call_deferred("_hide_imported")

func _hide_imported() -> void:
    var vehicle: VehicleBody3D = get_parent() as VehicleBody3D
    if vehicle != null:
        _hide_imported_duplicate_wheels(vehicle)

func _hide_imported_duplicate_wheels(vehicle: VehicleBody3D) -> void:
    var model: Node3D = vehicle.get_node_or_null("Visual/Modelo") as Node3D
    if model == null:
        return
    for item: Node in model.find_children("*", "Node3D", true, false):
        var label: String = String(item.name).to_lower()
        # GLB original: [wheel_59_2, [wheel_l_58_4,
        # [wheel_lf]_49_6, hub_lf_50_118, hub_lr_51_120, hub_rr_52_123.
        # Nao ocultar wheel_well, steeringwheel ou headlight.
        var is_wheel_group: bool = (
            label.begins_with("[wheel") or label.begins_with("wheel_")
            or label.begins_with("hub_") or label.begins_with("tire_")
            or label.begins_with("rim_") or label.begins_with("pneu_")
            or label.begins_with("roda_")
            or label.begins_with("object_221_223")
            or label.begins_with("object_242")
            or label.begins_with("object_245_224")
        )
        if is_wheel_group and not label.begins_with("wheel_well"):
            (item as Node3D).visible = false
