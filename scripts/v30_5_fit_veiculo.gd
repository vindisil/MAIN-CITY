@tool
extends Node3D
## Ajusta a malha importada preservando o collider externo da vaga.
## O pai precisa possuir um filho Node3D chamado "Modelo".
@export_range(2.0, 9.0, 0.05) var comprimento_m: float = 5.7
@export var alinhar_eixo_longo: bool = true
@export var ocultar_rodas_modelo: bool = false

func _ready() -> void:
    call_deferred("_ajustar")

func _ajustar() -> void:
    var modelo := get_node_or_null("Modelo") as Node3D
    if modelo == null:
        return
    var partes: Array[Node] = modelo.find_children("*", "MeshInstance3D", true, false)
    if modelo is MeshInstance3D:
        partes.push_front(modelo)
    if partes.is_empty():
        push_warning("V30.5: modelo importado sem malha: " + str(get_path()))
        return
    modelo.position = Vector3.ZERO
    modelo.rotation = Vector3.ZERO
    modelo.scale = Vector3.ONE
    var caixa := _limites(partes)
    if alinhar_eixo_longo and caixa.size.x > caixa.size.z * 1.2:
        modelo.rotation.y = -PI / 2.0
        caixa = _limites(partes)
    if caixa.size.z < 0.05:
        push_warning("V30.5: dimensao invalida: " + str(get_path()))
        return
    var fator: float = comprimento_m / caixa.size.z
    modelo.scale = Vector3.ONE * fator
    caixa = _limites(partes)
    modelo.position = Vector3(-caixa.get_center().x, 0.035 - caixa.position.y, -caixa.get_center().z)
    if ocultar_rodas_modelo:
        # Imported wheels are static parts of the GLB/FBX. Avoid duplicate
        # wheels: the lightweight visuals below the VehicleWheel3D nodes
        # are the only ones displayed and follow steering/suspension.
        for part in modelo.find_children("*", "Node3D", true, false):
            var label: String = String(part.name).to_lower()
            var imported_wheel: bool = (
                label.begins_with("[wheel") or label.begins_with("wheel_")
                or label.begins_with("hub_") or label.begins_with("rim_")
                or label.begins_with("tire_") or label.begins_with("pneu_")
                or label.begins_with("roda_")
            )
            # Keep wheel wells, steering wheel, lamps and fenders.
            if imported_wheel and not label.begins_with("wheel_well"):
                part.visible = false

func _limites(partes: Array[Node]) -> AABB:
    var menor := Vector3(INF, INF, INF)
    var maior := Vector3(-INF, -INF, -INF)
    var inversa: Transform3D = global_transform.affine_inverse()
    for item in partes:
        var malha := item as MeshInstance3D
        if malha == null or malha.mesh == null:
            continue
        var caixa := malha.get_aabb()
        var matriz: Transform3D = inversa * malha.global_transform
        for i in range(8):
            var p: Vector3 = matriz * caixa.get_endpoint(i)
            menor = menor.min(p)
            maior = maior.max(p)
    if not is_finite(menor.x) or not is_finite(maior.x):
        return AABB(Vector3.ZERO, Vector3.ZERO)
    return AABB(menor, maior - menor)
