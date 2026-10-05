extends Node3D
## Aplica camuflagem azul apenas ao material exterior do FBX original.
## Nao substitui o material de vidro, luzes, rodas ou cabine.
const CAMUFLAGEM: Texture2D = preload("res://assets/models/v30_5_veiculos/blindado_policial/textures/pintura_camo_azul_v30_9.png")

func _ready() -> void:
    call_deferred("_pintar_exterior")

func _pintar_exterior() -> void:
    var modelo: Node = get_parent().get_node_or_null("Modelo")
    if modelo == null:
        push_warning("Blindado V30.9: modelo importado ainda indisponivel.")
        return
    var pintura := StandardMaterial3D.new()
    pintura.resource_name = "exterior_azul_camuflado_policial"
    pintura.albedo_color = Color.WHITE
    pintura.albedo_texture = CAMUFLAGEM
    pintura.metallic = 0.12
    pintura.roughness = 0.78
    var normais: Texture2D = load("res://assets/models/v30_5_veiculos/blindado_policial/textures/exterior_normal.png") as Texture2D
    if normais != null:
        pintura.normal_enabled = true
        pintura.normal_texture = normais
        pintura.normal_scale = 0.7
    var aplicadas: int = 0
    var partes: Array[Node] = modelo.find_children("*", "MeshInstance3D", true, false)
    if modelo is MeshInstance3D:
        partes.push_front(modelo)
    for parte in partes:
        var malha: MeshInstance3D = parte as MeshInstance3D
        if malha == null or malha.mesh == null:
            continue
        var nome_peca: String = String(malha.name).to_lower()
        for idx in range(malha.mesh.get_surface_count()):
            var original: Material = malha.get_active_material(idx)
            var nome_material: String = ""
            if original != null:
                nome_material = String(original.resource_name).to_lower()
            # O FBX fornecido separa exterior, windows, lights, interior e wheel.
            # Apenas o exterior pode receber o material camuflado.
            var eh_exterior: bool = nome_material.contains("exterior")
            if nome_material == "" and nome_peca.begins_with("body_"):
                eh_exterior = true
            if nome_material.contains("window") or nome_material.contains("glass") or nome_material.contains("light") or nome_material.contains("interior") or nome_material.contains("wheel"):
                eh_exterior = false
            if nome_peca.begins_with("wheel_"):
                eh_exterior = false
            if eh_exterior:
                malha.set_surface_override_material(idx, pintura)
                aplicadas += 1
    if aplicadas == 0:
        push_warning("Blindado V30.9: nao encontrei superficies 'exterior' para camuflagem; modelo original preservado.")
