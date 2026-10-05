extends Node3D
## v0.0.1 - Centraliza e encaixa modelos externos dentro da area do lote.
## Nao utiliza _process: a geometria e medida somente ao carregar o setor.
@export var plot_width: float = 115.0
@export var plot_depth: float = 115.0
@export var max_building_height: float = 48.0
@export var ground_level: float = 0.16
@export var collision_coverage: float = 0.72

func _ready() -> void:
    # A cena importada (GLB/FBX) ja esta inserida sob Model.
    var content: Node3D = get_node_or_null("Model") as Node3D
    if content == null:
        push_warning("Lote sem modelo: " + name)
        return
    var bounds: AABB = AABB()
    var found: bool = false
    var pending: Array[Node] = [content]
    var content_inverse: Transform3D = content.global_transform.affine_inverse()
    while not pending.is_empty():
        var current: Node = pending.pop_back()
        if current is MeshInstance3D:
            var mesh_instance: MeshInstance3D = current as MeshInstance3D
            if mesh_instance.mesh != null:
                var local_box: AABB = mesh_instance.get_aabb()
                var relative: Transform3D = content_inverse * mesh_instance.global_transform
                for vx in range(2):
                    for vy in range(2):
                        for vz in range(2):
                            var corner := local_box.position + Vector3(local_box.size.x * float(vx), local_box.size.y * float(vy), local_box.size.z * float(vz))
                            var point: Vector3 = relative * corner
                            if not found:
                                bounds = AABB(point, Vector3.ZERO)
                                found = true
                            else:
                                bounds = bounds.expand(point)
        for child in current.get_children():
            pending.append(child)
    if not found or bounds.size.x < 0.001 or bounds.size.z < 0.001:
        push_warning("Modelo sem malha/limites validos: " + name)
        return
    var ratio: float = minf(plot_width / bounds.size.x, plot_depth / bounds.size.z)
    if bounds.size.y > 0.001:
        ratio = minf(ratio, max_building_height / bounds.size.y)
    content.scale = Vector3.ONE * ratio
    content.position = Vector3(-bounds.get_center().x * ratio, ground_level - bounds.position.y * ratio, -bounds.get_center().z * ratio)
    # Colisao simplificada: sem gerar trimesh estatico e pesado para cada casa.
    # A malha visual original permanece inalterada e pode receber colisores
    # refinados por porta/escada em uma etapa posterior.
    var body := StaticBody3D.new()
    body.name = "Colisao_Simplificada"
    add_child(body)
    var collision := CollisionShape3D.new()
    collision.name = "Volume"
    var box := BoxShape3D.new()
    var height: float = maxf(1.0, bounds.size.y * ratio)
    box.size = Vector3(minf(plot_width, bounds.size.x * ratio) * collision_coverage, height, minf(plot_depth, bounds.size.z * ratio) * collision_coverage)
    collision.shape = box
    collision.position.y = ground_level + height * 0.5
    body.add_child(collision)
