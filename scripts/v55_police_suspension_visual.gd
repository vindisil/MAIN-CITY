extends Node3D
## v0.0.55: posiciona APENAS as malhas dos pneus na altura física da suspensão.
## O VehicleWheel3D continua responsável por contato, direção e tração;
## não duplicamos rodas, colisores nem alteramos as rotações de esterçamento.
## Funciona também quando a viatura é puxada novamente pelo checkpoint.

var wheels: Array[VehicleWheel3D] = []

func _ready() -> void:
    # Outros scripts adicionam as rodas visuais após o carregamento da cena.
    set_physics_process(true)
    var body := get_parent() as VehicleBody3D
    if body == null:
        set_physics_process(false)
        return
    for suffix in ["FL", "FR", "RL", "RR"]:
        var wheel := body.get_node_or_null("Wheel" + suffix) as VehicleWheel3D
        if wheel != null:
            wheels.append(wheel)

func _physics_process(delta: float) -> void:
    for wheel in wheels:
        if not is_instance_valid(wheel):
            continue
        var visual := wheel.get_node_or_null("WheelModel") as Node3D
        if visual == null:
            visual = wheel.get_node_or_null("RodaOriginalV30_9") as Node3D
        if visual == null:
            continue
        # Altura nominal em repouso, atualizada pelo contato real com o chão.
        var target_y: float = -wheel.wheel_rest_length
        if wheel.is_in_contact():
            var axis_up: Vector3 = wheel.global_basis.y.normalized()
            var center_world: Vector3 = wheel.get_contact_point() + axis_up * wheel.wheel_radius
            target_y = wheel.to_local(center_world).y
        target_y = clampf(target_y, -wheel.wheel_rest_length - wheel.suspension_travel, 0.0)
        # Amortecimento visual independente da física: evita tremor nas rodas.
        visual.position.y = lerpf(visual.position.y, target_y, 1.0 - exp(-delta * 24.0))
