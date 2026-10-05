extends Node3D
## Rodas visuais V30.9. Reaproveita exatamente os modelos e texturas
## existentes da BMW e Mercedes. A fisica e o comando permanecem nos
## quatro VehicleWheel3D do carro. Nao duplica colisores ou malhas simples.

const BMW: PackedScene = preload("res://assets/models/v23_2/pneu_usuario_bmw.glb")
const BMW_MOBILE: PackedScene = preload("res://assets/models/v23_2/pneu_usuario_bmw_mobile.glb")
const GLS_FL: PackedScene = preload("res://assets/models/v26/mercedes_wheel_FL.glb")
const GLS_FR: PackedScene = preload("res://assets/models/v26/mercedes_wheel_FR.glb")
const GLS_RL: PackedScene = preload("res://assets/models/v26/mercedes_wheel_RL.glb")
const GLS_RR: PackedScene = preload("res://assets/models/v26/mercedes_wheel_RR.glb")

@export var blindado: bool = false

func _ready() -> void:
    call_deferred("_instalar_rodas")

func _instalar_rodas() -> void:
    var carro: VehicleBody3D = get_parent() as VehicleBody3D
    if carro == null:
        push_warning("Rodas V30.9: esperado VehicleBody3D pai.")
        return
    for sigla in ["FL", "FR", "RL", "RR"]:
        var roda: VehicleWheel3D = carro.get_node_or_null("Wheel" + sigla) as VehicleWheel3D
        if roda == null:
            push_warning("Rodas V30.9: faltando Wheel" + sigla)
            continue
        # Evita duplicar quaisquer rodas criadas em versoes anteriores.
        var visual_antigo: Node = roda.get_node_or_null("RodaVisualV30_7")
        if visual_antigo != null:
            visual_antigo.queue_free()
        if roda.has_node("RodaOriginalV30_9"):
            continue
        var modelo: Node3D
        if blindado:
            # BMW: o eixo local da malha esta no Y. A escala do eixo Y
            # mantem a largura proporcional ao para-lama, sem alterar o raio fisico.
            var source: PackedScene = BMW_MOBILE if OS.has_feature("mobile") else BMW
            modelo = source.instantiate() as Node3D
            modelo.rotation.z = PI * 0.5 if sigla == "FL" or sigla == "RL" else -PI * 0.5
            var raio_escala: float = 0.93058 * roda.wheel_radius / 0.38910
            modelo.scale = Vector3(raio_escala, raio_escala, raio_escala)
        else:
            # Mercedes: cada lado vem com sua orientacao correta de origem.
            var arquivo: PackedScene = GLS_FL
            match sigla:
                "FR": arquivo = GLS_FR
                "RL": arquivo = GLS_RL
                "RR": arquivo = GLS_RR
            modelo = arquivo.instantiate() as Node3D
            var raio_escala: float = roda.wheel_radius / 0.41963
            modelo.scale = Vector3.ONE * raio_escala
        if modelo == null:
            push_warning("Rodas V30.9: falha ao carregar roda " + sigla)
            continue
        modelo.name = "RodaOriginalV30_9"
        roda.add_child(modelo)
        # Deferred wheel creation happens after the parent material pass.
        carro.call("_finish_imported_materials", modelo)
        if OS.has_feature("mobile"):
            for piece in modelo.find_children("*", "MeshInstance3D", true, false):
                (piece as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
