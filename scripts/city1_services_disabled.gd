extends Node3D
## Main City - migração para City 1.
## Os sistemas antigos de Polícia / Exército / Hospital ficam preservados em
## scripts/city_services.gd, porém não são iniciados enquanto os novos pontos
## das bases não forem definidos neste mapa.

@export var police_enabled: bool = false
@export var army_enabled: bool = false
@export var hospital_enabled: bool = false

func _ready() -> void:
	# Intencionalmente vazio. Mantemos este nó como ponto de reativação futura
	# sem carregar checkpoints, painéis ou spawns nas coordenadas do mapa antigo.
	pass
