extends Node3D
## Main City - migração para City 1.
## Polícia / Exército / Hospital ficam preservados, porém inativos até os
## novos pontos das bases serem definidos neste mapa.
## Também centraliza o atalho ESC do mapa da nova cidade.

@export var police_enabled: bool = false
@export var army_enabled: bool = false
@export var hospital_enabled: bool = false

func _ready() -> void:
	# Precisa continuar recebendo ESC mesmo quando o menu pausa a árvore.
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return

	var player := get_node_or_null("Player")
	if player == null:
		return
	var menu = player.get("map_settings_menu")
	if menu == null or not is_instance_valid(menu):
		return

	if bool(menu.get("menu_open")):
		menu.call("set_menu", false)
	else:
		# Aba 1 = mapa. ESC abre direto no mapa geográfico da City 1.
		menu.call("open_page", 1)
	get_viewport().set_input_as_handled()
